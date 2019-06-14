// main for NetFPGA SUME switch with the XilinxStreamSwitch architecture

#include <core.p4>        // P4 core
#include <xilinx_core.p4> // packet_mod
#include <xilinx.p4>      // XilinxStreamSwitch
#include <sume_switch.p4> // sume_metadata

#include "settings.p4" // must be included *before* SCION

#include <netfpga/stats.p4>
#include <netfpga/wallclock.p4>
#include <netfpga/passthrough_to_cpu.p4>
#include <common/checksums.p4>
#include <scion/datatypes.p4>
#include <scion/headers.p4>
#include <scion/parsers.p4>
#include <scion/verification.p4>
#include <scion/mod_deparsers.p4>

#include "datatypes.p4"

const bit<128> HF_MAC_KEY = 128w0x47; // TODO set by control plane instead of compiling in

// TODO maybe I should move this to its own header?
@brief("Metadata passed from/to the NetFPGA, such as ingress/egress ports.")
@description("DO NOT change this: the XilinxStreamSwitch wrapper expects \
exactly this format. \
The contents of digest_data_t (declared in datatypes.p4) is specified by \
the user and may be changed (but must stay exactly 256 bits long). \
The sume_metadata_t type is fixed by the NetFPGA platform and is declared \
in <sume_switch.p4>.")
struct switch_meta_t {
    digest_data_t   digest;
    sume_metadata_t sume;
}

@brief("Data passed locally between the parser and control blocks.")
@description("Application-specific; may be changed by the programmer as \
needed.")
struct local_t {
    error_data_t err;
    scion_all_headers_t hdr;
}

@brief("The top-level parser block.")
@description("The local_t parameter output from here is passed into TopPipe.")
// The signature is fixed by the XilinxStreamSwitch architecture; the local_t
// type can be changed above.
@Xilinx_MaxPacketRegion(MTU)
parser TopParser(packet_in packet, out local_t d) {

    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, d.hdr, d.err);
        transition accept;
    }
}

@brief("The 'main' of the switch.")
@description("Processes the parsed data and modifies and forwards the packet.")
// DO NOT RENAME the 's' parameter: the generated Verilog derives wire names
// from it, so if you change it, you'll have to also change
// platforms/netfpga/xilinx-stream-switch/hw/nf_sume_sdnet.v.
@Xilinx_MaxPacketRegion(MTU)
control TopPipe(inout local_t d,
                inout switch_meta_t s) {

    // TODO modularise this once the architecture is clear

    // TODO the parts related to forwarding should be moved into something like
    // a ScionForwarder control or so
    error_data_t ingress_if_check_err;
    error_data_t hf_expiry_err;
    error_data_t hf_mac_err;
    error_data_t hf_err;
    error_data_t egress_if_match_err;
    bit<12>      egress_if;
    bit<32>      now;
    ReadWallClock()      read_wall_clock;
    CheckHFExpiry()      check_hf_expiry;
    VerifyHF()           verify_current_hf;
    UpdateIPv4Checksum() update_ipv4_checksum;
    UpdateUDPChecksum()  update_udp_checksum;
    ExposeStats()        expose_stats;

    action set_dst_port(port_t port) {
        s.sume.dst_port = port;
    }

    action set_ptp_link() {
        // TODO this would be better with some well-known SCION_PTP_MCAST_MAC
        // compile-time constant instead of just broadcast
        d.hdr.ethernet.dst_addr = 0xffffffffffff;
    }


    action set_overlay_udp_v4(ipv4_addr_t my_addr, udp_port_t my_port, ipv4_addr_t remote_addr, udp_port_t remote_port, eth_addr_t remote_mac) {
        d.hdr.encaps.ip.v6.setInvalid();
        d.hdr.encaps.ip.v4.src_addr = my_addr;
        d.hdr.encaps.ip.v4.dst_addr = remote_addr;
        d.hdr.encaps.udp.src_port = my_port;
        d.hdr.encaps.udp.dst_port = remote_port;
        d.hdr.ethernet.dst_addr = remote_mac;
    }

    // No v6 checksum function => not implementable ATM, TODO fix if possible
    // action set_overlay_udp_v6(ipv6_addr_t my_addr, udp_port_t my_port, ipv6_addr_t remote_addr, udp_port_t remote_port, eth_addr_t remote_mac) {
    //     d.hdr.encaps.ip.v4.setInvalid();
    //     d.hdr.encaps.ip.v6.src_addr = my_addr;
    //     d.hdr.encaps.ip.v6.dst_addr = remote_addr;
    //     d.hdr.encaps.udp.src_port = my_port;
    //     d.hdr.encaps.udp.dst_port = remote_port;
    //     d.hdr.ethernet.dst_addr = remote_mac;
    // }

    action egress_if_match_err_unconfigured_ifid() {
        egress_if_match_err.debug = 20w0 ++ 16w0xfeee ++ d.hdr.scion.path.current_hf.egress_if ++ 16w0xfeee;
        egress_if_match_err.error_flag = ERROR.InternalError_UnconfiguredIFID;
    }

    /// TABLES ///////////////////////////////////////////////////////////////

    // TODO currently, control plane needs to fill this out by correlating the
    // IP addresses from the topology.json with the ones set on nf* interfaces
    @brief("Maps SCION egress interface ID to physical port.")
    table egress_ifid_to_port {
        key = {
            d.hdr.scion.path.current_hf.egress_if: exact;
        }
        actions = {
            set_dst_port;
            egress_if_match_err_unconfigured_ifid;
        }
        default_action = egress_if_match_err_unconfigured_ifid();
        size = 64; // smallest possible exact match size
    }

    // This "should" be two layers/tables: L3 overlay and L2 ARP/NDP. However,
    // because the mapping is 1:1, we can save ourselves the second lookup by
    // declaring that to be The Control Plane's Problem.
    @brief("Link overlay table: maps IFID to overlay.")
    table link_overlay {
        key = {
            d.hdr.scion.path.current_hf.egress_if: exact;
        }
        actions = {
            set_overlay_udp_v4;
            // TODO enable if it turns out that NetFPGA python scripts are only
            // annoyingly broken, not deal-breakingly broken
            // ... and once we can compute IPv6 checksums
            // set_overlay_udp_v6;
            // set_ptp_link;
            egress_if_match_err_unconfigured_ifid;
        }
        // TODO instead of error, this should be set_ptp_link once we support
        // overlay-free communication
        default_action = egress_if_match_err_unconfigured_ifid();
        size = 64; // smallest possible exact match size
    }

    action set_src_mac(eth_addr_t mac) {
        d.hdr.ethernet.src_addr = mac;
    }
    table my_mac {
        key = {
            s.sume.dst_port: exact;
        }
        actions = {
            set_src_mac;
        }
        // TODO error with default_action
        size = 64;
    }

    action set_result(bit<32> data) {
        s.digest.debug1 = 16w0xfeee ++ data ++ 16w0xfeee;
    }
    // P4-SDNet is weird non-deterministic shit.
    // This table does not do anything. But if I remove it, the above tables,
    // which actually do something, will magically stop working. Magically. It
    // makes no sense at all. Took 2 days to figure out, too. Just don't touch
    // this table.
    table noop_table {
        key = {
            d.hdr.scion.path.current_hf.egress_if: exact;
        }
        actions = {
            set_result;
        }
        size = 64;
    }


    // from here on this should stay in main :D

    action send_digest() {
        s.sume.send_dig_to_cpu = 1;
    }

    action copy_error_to_digest(in error_data_t err_) {
        s.digest.error_flag = err_.error_flag;
    }

    action copy_debug_to_digest(in error_data_t err_) {
        s.digest.debug1  = err_.debug;  // local
        s.digest.debug2  = d.err.debug; // parser
    }

    // TODO count errors by type and expose as metrics
    action err_and_pass_to_cpu(in error_data_t err) {
        copy_error_to_digest(err);
        IFDBG(copy_debug_to_digest(err));
        IFDBG(send_digest());
        PASS_TO_CPU(s.sume);
    }

    // The following is kind of terrible because if I exited early, I would be
    // unable to update stats, because SDNet does not allow to have the same
    // extern in the control flow more than once, even if it always gets
    // executed at most once at runtime. Therefore, I have to have branching
    // instead of calling exit, so that I can update stats at the end, exactly
    // once.
    apply {
        // if this came from the CPU, don't judge and just pass it through
        if (IS_CPU_PORT(s.sume.src_port)) {
            PASS_FROM_CPU(s.sume);
        } else { // not from the CPU => our turn to process it
            if (IS_ERROR(d.err)) { // parser error => give up
                err_and_pass_to_cpu(d.err);
            } else { // actual SCION packet processing


                // P4-SDNet is a non-deterministic piece of shit.
                // TODO figure this shit out, maybe one day.
                noop_table.apply();


                // TODO check incoming port

                read_wall_clock.apply(now);
                check_hf_expiry.apply(now,
                                      d.hdr.scion.path.current_inf.timestamp,
                                      d.hdr.scion.path.current_hf.expiry,
                                      hf_expiry_err);

                // TODO(realtraffic) read AS key from a reg
                verify_current_hf.apply(HF_MAC_KEY,
                                        d.hdr.scion.path.current_inf.timestamp,
                                        d.hdr.scion.path.current_hf,
                                        d.hdr.scion.path.prev_hf,
                                        hf_mac_err);
                hf_err = IS_ERROR(hf_expiry_err) ? hf_expiry_err : hf_mac_err;

                if (IS_ERROR(hf_err)) {
                    err_and_pass_to_cpu(hf_err);
                } else {
                    egress_if = d.hdr.scion.path.current_hf.egress_if;
                    egress_ifid_to_port.apply();
                    link_overlay.apply();
                    if (IS_ERROR(egress_if_match_err)) {
                        err_and_pass_to_cpu(egress_if_match_err);
                    } else {
                        // done error checking -- we can modify the packet now

                        // update HF and maybe INF pointers
                        // TODO this could be a control, maybe
                        // TODO just like everything else, this assumes
                        // fixed-size HFs. That's fine here, as we reject
                        // continuation flag in the parser, but one day we
                        // should maybe fix that.
                        if ((d.hdr.scion.path.current_hf.flags & HF_FLAG_XOVER) != 0) {
                            d.hdr.scion.common.curr_INF = d.hdr.scion.common.curr_HF + 1;
                            d.hdr.scion.common.curr_HF  = d.hdr.scion.common.curr_INF + 1;
                        } else {
                            d.hdr.scion.common.curr_HF = d.hdr.scion.common.curr_HF + 1;
                        }

                        my_mac.apply();

                        // TODO check whether we want to update v4 or v6, once we support v6
                        update_ipv4_checksum.apply(d.hdr.encaps.ip.v4);
                        update_udp_checksum.apply(d.hdr.encaps.udp);
                    }
                }
            }
        }
        expose_stats.apply(s.sume, s.digest.error_flag);
    }
}

@brief("The top-level deparser: uses d to put headers back into the packet.")
@Xilinx_MaxPacketRegion(MTU)
parser TopDeparser(in local_t d, packet_mod pkt) {
    // It does not make much sense to modularise the deparser, because we only want
    // to update the parts we want to update, which depends on what we changed.
    // However: TODO this could be split into a "fwd-only deparser" living in lib/
    // with the contract of changing L2, encaps and INF+HF offsets and nothing else.
    ScionEncapsulationModDeparser() encaps_deparser;

    // Below, notice that I am unconditionally calling pkt.update(...), even
    // though the header may not be valid. Though this is not specified anywhere,
    // in my experiments this seems to be a no-op with invalid headers, so it's
    // okay.
    state start {
        // we changed L2
        pkt.update(d.hdr.ethernet);

        // encapsulate; beware that this does not consume the encapsulation
        // if we want to remove it!
        // TODO This needs to be thought about once we support both encapsulated
        // and non-encapsulated SCION.
        encaps_deparser.apply(pkt, d.hdr.ethernet.ethertype, d.hdr.encaps);

        // update only INF and HF in SCION common header
        pkt.update(d.hdr.scion.common, SCION_COMMON_HDR_MASK_INF_HF);

        // done: we didn't change anything else
        transition accept;
    }
}

XilinxStreamSwitch(TopParser(), TopPipe(), TopDeparser()) main;
