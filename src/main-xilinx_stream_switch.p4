// main for NetFPGA SUME switch with the XilinxStreamSwitch architecture

#include <core.p4>        // P4 core
#include <xilinx_core.p4> // packet_mod
#include <xilinx.p4>      // XilinxStreamSwitch
#include <sume_switch.p4> // sume_metadata

#include "settings.p4" // must be included *before* SCION

#include <scion/headers.p4>
#include <scion/parsers.p4>
#include <scion/mod_deparsers.p4>

#include "datatypes.p4"

struct local_t {
    user_metadata_t     meta;
    scion_all_headers_t hdr;
}

// DO NOT change this: the NetFPGA expects exactly this format
// TODO maybe I should move this to its own header?
struct switch_meta_t {
    digest_data_t   digest;
    sume_metadata_t sume;
}

// // TODO move to its own file

// // Data will be zero-padded to 128 bits
// // Result will be truncated to fit the R result type. Call with a 128-bit
// // `result` param to get the complete MAC.
// @Xilinx_MaxLatency(5)
// @Xilinx_ControlWidth(0)
// extern void aes_mac<D, O>(in D data, out R result);

//////// end just for fun

@Xilinx_MaxPacketRegion(MTU)
parser TopParser(packet_in packet, out local_t d) {
    
    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, d.meta.scion, d.hdr);
        transition accept;
    }
}

// DO NOT RENAME the "s" parameter: the generated Verilog derives wire names
// from it, so if you change it, you'll have to also change
// platforms/netfpga/xilinx-stream-switch/hw/nf_sume_sdnet.v.
@Xilinx_MaxPacketRegion(MTU)
control TopPipe(inout local_t d,
                inout switch_meta_t s) {

    // TODO modularise this once the architecture is clear

    action reflect_L2() {
        eth_addr_t tmp_src_addr = d.hdr.ethernet.src_addr;
        d.hdr.ethernet.src_addr = d.hdr.ethernet.dst_addr;
        d.hdr.ethernet.dst_addr = tmp_src_addr;

        s.sume.dst_port = s.sume.src_port;
    }

    action set_dst_port(port_t port) {
        s.sume.dst_port = port;
    }

    // SCION egress interface ID to physical port
    // 1:1 mapping for now
    table egress_ifid_to_port {
        key = {
            d.hdr.scion.path.current_hf.egress_if: exact;
            // ha ha, netfpga scripts don't support direct match type
            // but TODO use direct one of these days, maybe
        }
        actions = {
            set_dst_port;
            NoAction;
        }
        size=64; // smallest possible for exact match
    }

    action update_checksums() {
        d.hdr.encaps.udp.checksum = 0; // checksum not used -- TODO one day :D
    }

    action increment_hf() {
        // TODO move current pointer properly -- with xover and stuff
        d.hdr.scion.common.curr_HF = d.hdr.scion.common.curr_HF + 1;
    }

    action copy_error_to_digest() {
        s.digest.error_flag = d.meta.scion.error_flag;
    }

    action copy_debug_to_digest() {
        s.digest.debug1     = d.meta.scion.debug1;
        s.digest.debug2     = d.meta.scion.debug2;
        s.digest.marker1    = 32w0xfeeefeee;
        s.digest.marker2    = 32w0xfeeefeee;
        s.digest.marker3    = 32w0xfeeefeee;
    }

    apply {
        // bit<32> mac;
        // aes_mac(64w0 ++ 32w0 ++ 32w47, mac);

        d.meta.scion.debug1 = 4w0 ++ d.hdr.scion.path.current_hf.egress_if ++ 4w0 ++ d.hdr.scion.path.current_hf.ingress_if ++ d.hdr.scion.common.curr_HF ++ d.hdr.scion.common.curr_INF ++ 16w0;

        egress_ifid_to_port.apply();
        increment_hf();
        update_checksums();
        copy_error_to_digest();
        // copy_debug_to_digest();
    }
}

// It does not make much sense to modularise the deparser, because we only want
// to update the parts we want to update, which depends on what we changed.
// However: TODO this could be split into a "fwd-only deparser" with the
// contract of changing L2, encaps and INF+HF offsets and nothing else.
@Xilinx_MaxPacketRegion(MTU)
parser TopDeparser(in local_t d, packet_mod pkt) {
    ScionEncapsulationModDeparser() encaps_deparser;

    state start{
        // we changed L2
        pkt.update(d.hdr.ethernet);

        // encapsulate; beware that this does not consume the encapsulation
        // if we want to remove it!
        // This would need to be thought about if we supported both encapsulated
        // and non-encapsulated SCION.
        encaps_deparser.apply(pkt, d.hdr.ethernet.ethertype, d.hdr.encaps);

        // update only INF and HF in SCION common header
        pkt.update(d.hdr.scion.common, SCION_COMMON_HDR_MASK_INF_HF);

        // done: we didn't change anything else
        transition accept;
    }
}

XilinxStreamSwitch(TopParser(), TopPipe(), TopDeparser()) main;