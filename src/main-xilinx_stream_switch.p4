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

// TODO move to its own file

@brief("AES-128-ECB encryption for a single block of data")
@description("Deterministic single-block AES encryption. Should not be used \
as is: this is intended as a building block for various modes.")
@Xilinx_MaxLatency(5)
@Xilinx_ControlWidth(0)
extern void mac_aes128(in bit<128> K, in bit<128> data, out bit<128> result);

@Xilinx_MaxPacketRegion(MTU)
parser TopParser(packet_in packet, out local_t d) {
    
    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, d.meta.scion, d.hdr);
        transition accept;
    }
}

// // TODO currently only handles the base case -- update!
// @brief("Validates the SCION packet: crypto + timestamps.")
// @description("TODO")
// @Xilinx_MaxPacketRegion(MTU)
// control Validate(in scion_header_t hdr) {

//     action generate_subkey(in bit<128> K, out bit<128> K1, bit<128> K2) {
//         bit<128> L;
//         aes128(K, 128w0, L);
//         if (L[127] == 0) {
//         } else {
//         }
//     }

//     @brief("Checks the current HF's MAC.")
//     @description("Computes the AES-CMAC of current (plus prev without flags) \
//                   and checks that the result matches the MAC in the packet. \
//                   See SCION book, p. 122 / eq. 7.8.")
//     action verify_hf_mac(bit<128> k, bit<32> timestamp, scion_hf_h current, scion_hf_h prev) {
//         bit<56> prev_data = (
//             prev.expiry ++           //  8b
//             prev.ingress_if ++       // 12b
//             prev.egress_if ++        // 12b
//             prev.mac                 // 24b
//         );
//         bit<128> data = (
//             timestamp ++                                   // 32b
//             (current.flags & SCION_HF_IMMUTABLE_FLAGS) ++  //  8b
//             current.expiry ++                              //  8b
//             current.ingres_if ++                           // 12b
//             current.egress_if ++                           // 12b
//             prev_data                                      // 56b
//         );

//         // This is an incomplete implementation of AES-CMAC, simplified because
//         // we have exactly one exactly 128-bit block of data.
//         // What could possibly go wrong :D
//         // Dear reader, please ignore this until I get my security MSc.
//         n = 1; // TODO remove
//         flag = True;
//         M_last = XOR_128(data, K1)
//     }
// }

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
        egress_ifid_to_port.apply();
        increment_hf();
        update_checksums();
        copy_error_to_digest();
        // copy_debug_to_digest();

        // TODO remove
        bit<128> res;
        mac_aes128(128w0x48, 128w0x1, res);
        s.digest.debug1 = res[63:0];
        s.digest.debug2 = res[127:64];
        // d.hdr.encaps.udp.checksum = res[15:0] - 0x47; // test :D
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