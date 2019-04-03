// main for NetFPGA SUME switch with the XilinxStreamSwitch architecture

#include <core.p4>        // P4 core
#include <xilinx_core.p4> // packet_mod
#include <xilinx.p4>      // XilinxStreamSwitch
#include <sume_switch.p4> // sume_metadata

#include "settings.p4" // must be included *before* SCION

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

    // from here on this should stay in main :D

    action copy_error_to_digest(in error_data_t err) {
        s.digest.error_flag = err.error_flag;
    }

    action copy_debug_to_digest(in error_data_t err) {
        s.digest.debug1  = err.debug;   // local
        s.digest.debug2  = d.err.debug; // parser
    }

    // this cannot be an action because SDNet does not support
    // calling exit() from an action
    #define CHECK(err)                                              \
        if (err.error_flag != ERROR.NoError) {                      \
            copy_error_to_digest(err);                              \
            copy_debug_to_digest(DEBUG ? err : {ERROR.NoError,0});  \
            exit;                                                   \
        }                                                           \

    error_data_t err;
    VerifyHF() verify_current_hf;
    apply {
        egress_ifid_to_port.apply();
        increment_hf();
        update_checksums();

        verify_current_hf.apply(HF_MAC_KEY,
                                d.hdr.scion.path.current_inf.timestamp,
                                d.hdr.scion.path.current_hf,
                                d.hdr.scion.path.prev_hf,
                                err);
        CHECK(err);
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

    state start{
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
