// main for NetFPGA SUME switch with the XilinxStreamSwitch architecture

#include <core.p4>        // P4 core
#include <xilinx_core.p4> // packet_mod
#include <xilinx.p4>      // XilinxStreamSwitch
#include <sume_switch.p4> // sume_metadata

#include "settings.p4" // must be included *before* SCION

#include <netfpga/regs.p4>
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
    // Used in the deparser to skip modifying the packet if it needs to be sent
    // out unmodified.
    bool can_modify;
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

const bit<128> HF_MAC_KEY = 128w0x47;

// Writes from the control plane only work with 32-bit registers (and supposedly
// it is not easy to fix), so I have 4 32-bit registers here instead of 1
// 128-bit one.
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(1)
extern void as_key_0_reg_rw(in bit<1> index,
                            in bit<32> newVal,
                            in bit<8> opCode,
                            out bit<32> result);
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(1)
extern void as_key_1_reg_rw(in bit<1> index,
                            in bit<32> newVal,
                            in bit<8> opCode,
                            out bit<32> result);
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(1)
extern void as_key_2_reg_rw(in bit<1> index,
                            in bit<32> newVal,
                            in bit<8> opCode,
                            out bit<32> result);
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(1)
extern void as_key_3_reg_rw(in bit<1> index,
                            in bit<32> newVal,
                            in bit<8> opCode,
                            out bit<32> result);

control GetASKey(out bit<128> key) {
    bit<32> key0;
    bit<32> key1;
    bit<32> key2;
    bit<32> key3;
    apply {
        as_key_0_reg_rw(0, 0, REG_READ, key0);
        as_key_1_reg_rw(0, 0, REG_READ, key1);
        as_key_2_reg_rw(0, 0, REG_READ, key2);
        as_key_3_reg_rw(0, 0, REG_READ, key3);
        key = key3 ++ key2 ++ key1 ++ key0;
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
    error_data_t merged_err;
    bit<32>      now;
    bit<128>     hf_mac_key;
    ReadWallClock()      read_wall_clock;
    CheckHFExpiry()      check_hf_expiry;
    // GetASKey()           get_as_key;
    VerifyHF()           verify_current_hf;
    UpdateIPv4Checksum() update_ipv4_checksum;
    UpdateUDPChecksum()  update_udp_checksum;
    ExposeStats()        expose_stats;

    action set_dst_port(port_t port) {
        s.sume.dst_port = port;
    }

    @description("Meant to be used as a default action if there is no mapping in the IFID => port table.")
    action set_default_dst_port_from_ifid() {
        set_dst_port(8w1 << d.hdr.scion.path.current_hf.egress_if[2:0]);
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

    // Currently, control plane needs to fill this out by correlating the
    // IP addresses from the topology.json with the ones set on nf* interfaces.
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
            set_ptp_link;
        }
        default_action = set_ptp_link();
        size = 64; // smallest possible exact match size
    }

    action set_src_mac(eth_addr_t mac) {
        d.hdr.ethernet.src_addr = mac;
    }
    table my_macs {
        key = {
            s.sume.dst_port: exact;
        }
        actions = {
            set_src_mac;
        }
        // TODO error with default_action
        size = 64;
    }

    // Instead of having the above tables, I squished them together so that I
    // only have one CAM lookup. Every CAM lookup costs more than 0.1ns, so
    // having 1 table instead of 3 shaves off 0.2ns, which is enough for us to
    // pass timing.
    action all_the_things_overlay_v4(port_t dst_port,
                                     eth_addr_t my_mac,
                                     ipv4_addr_t my_addr,
                                     udp_port_t my_port,
                                     ipv4_addr_t remote_addr,
                                     udp_port_t remote_port,
                                     eth_addr_t remote_mac) {
        egress_if_match_err.error_flag = ERROR.NoError;
        set_dst_port(dst_port);
        set_overlay_udp_v4(my_addr, my_port, remote_addr, remote_port, remote_mac);
        set_src_mac(my_mac);
    }
    table squished {
        key = {
            d.hdr.scion.path.current_hf.egress_if: exact;
        }
        actions = {
            all_the_things_overlay_v4;
            egress_if_match_err_unconfigured_ifid;
        }
        default_action = egress_if_match_err_unconfigured_ifid();
        size = 64; // smallest possible exact match size
    }

    action set_result(bit<32> data) {
        s.digest.debug1 = 16w0xfeee ++ data ++ 16w0xfeee;
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
        d.can_modify = false;
        // if this came from the CPU, don't judge and just pass it through
        if (IS_CPU_PORT(s.sume.src_port)) {
            PASS_FROM_CPU(s.sume);
        } else { // not from the CPU => our turn to process it
            if (IS_ERROR(d.err)) { // parser error => give up
                err_and_pass_to_cpu(d.err);
            } else { // actual SCION packet processing
                // TODO check incoming port
                // P4-SDNet is a piece of shit and breaks tables if I call an
                // extern before applying the table.
                // Therefore, I have to apply this here, at the beginning of the
                // control flow, even though I haven't checked MACs yet.
                // Everything is terrible.
                // Commented out squished so that this can pass timing, applying
                // the smaller egress_ifid_to_port instead for the measurements.
                // squished.apply();
                egress_ifid_to_port.apply();

                // read_wall_clock.apply(now);
                // check_hf_expiry.apply(now,
                //                       d.hdr.scion.path.current_inf.timestamp,
                //                       d.hdr.scion.path.current_hf.expiry,
                //                       hf_expiry_err);

                // TODO test whether it is better to have a table or a reg for the AS key

                // get_as_key.apply(hf_mac_key);
                // hf_mac_key = 128w0x47;
                verify_current_hf.apply(HF_MAC_KEY,
                                        d.hdr.scion.path.current_inf.timestamp,
                                        d.hdr.scion.path.current_hf,
                                        d.hdr.scion.path.prev_hf,
                                        hf_mac_err);
                hf_err = IS_ERROR(hf_expiry_err) ? hf_expiry_err : hf_mac_err;

                merged_err = IS_ERROR(hf_err) ? hf_err : egress_if_match_err;
                if (IS_ERROR(merged_err)) {
                    err_and_pass_to_cpu(merged_err);
                } else {
                    // egress_ifid_to_port.apply();
                    // egress_if_match_error check was here
                    // done error checking -- we can modify the packet now
                    d.can_modify = true;
                    // link_overlay.apply();

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

                    // my_macs.apply();

                    // TODO check whether we want to update v4 or v6, once we support v6
                    update_ipv4_checksum.apply(d.hdr.encaps.ip.v4);
                    update_udp_checksum.apply(d.hdr.encaps.udp);
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

    state start {
        transition select (d.can_modify) {
            true:  real_start;
            false: accept;
        }
    }

    // Below, notice that I am unconditionally calling pkt.update(...), even
    // though the header may not be valid. Though this is not specified anywhere,
    // in my experiments this seems to be a no-op with invalid headers, so it's
    // okay.
    state real_start {
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
