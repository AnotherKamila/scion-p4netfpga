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

// TODO move this somewhere appropriate

const bit<8> REG_READ  = 8w0;
const bit<8> REG_WRITE = 8w1;
const bit<8> REG_ADD   = 8w2;

// const bit<8> EQ_RELOP  = 8w0
// const bit<8> NEQ_RELOP = 8w1
// const bit<8> GT_RELOP  = 8w2
// const bit<8> LT_RELOP  = 8w3

// const int SIGNAL_REG_INDEX_WIDTH = 2;
// typedef bit<SIGNAL_REG_INDEX_WIDTH> signal_idx;
// const signal_idx STATS_REQUESTED = 1;

// @brief("Signal bits used to get 'kicked' by the control plane.")
// @Xilinx_MaxLatency(1)
// @Xilinx_ControlWidth(width(T))
// extern void signal_reg_praw<T, D>(in T index,
//                                   in D newVal,
//                                   in D incVal,
//                                   in bit<8> opCode,
//                                   in D compVal,
//                                   in bit<8> relOp,
//                                   out D result,
//                                   out bit<1> boolean);

// Actually, the above seems very complicated. I'll just use a counter every couple of packets.
// But TODO once I have a solid control plane, use the above.

@brief("Counter used to send out stats every 2^PACKET_COUNTER_WIDTH packets.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(1)
extern void packet_counter_reg_raw(in bit<1> index,
                                   in bit<PACKET_COUNTER_WIDTH> newVal,
                                   in bit<PACKET_COUNTER_WIDTH> incVal,
                                   in bit<8> opCode,
                                   out bit<PACKET_COUNTER_WIDTH> result);

// end of the part that should be moved somewhere appropriate

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

    @brief("Sets port to 1 << current_hf.egress_if.")
    @description("Meant to be used as a default action if there is no mapping in the IFID => port table.")
    action set_default_dst_port_from_ifid() {
        set_dst_port(8w1 << d.hdr.scion.path.current_hf.egress_if[2:0]);
    }

    @brief("Maps SCION egress interface ID to physical port.")
    table egress_ifid_to_port {
        key = {
            d.hdr.scion.path.current_hf.egress_if[2:0]: direct;
            // ha ha, netfpga scripts don't support direct match type
            // TODO fix them
        }
        actions = {
            set_dst_port;
            set_default_dst_port_from_ifid;
        }
        default_action = set_default_dst_port_from_ifid();
        // note that size is 2^key width
    }

    action update_checksums() {
        d.hdr.encaps.udp.checksum = 0; // checksum not used -- TODO one day :D
    }

    action increment_hf() {
        // TODO move current pointer properly -- with xover and stuff
        d.hdr.scion.common.curr_HF = d.hdr.scion.common.curr_HF + 1;
    }

    // from here on this should stay in main :D

    action send_digest() {
        s.sume.send_dig_to_cpu = 1;
    }

    action copy_error_to_digest(in error_data_t err) {
        s.digest.error_flag = err.error_flag;
    }

    action copy_debug_to_digest(in error_data_t err) {
        s.digest.debug1  = err.debug;   // local
        s.digest.debug2  = d.err.debug; // parser
    }

    action send_stats_digest() {
        s.digest.dma_q_size = s.sume.dma_q_size;
        s.digest.nf3_q_size = s.sume.nf3_q_size;
        s.digest.nf2_q_size = s.sume.nf2_q_size;
        s.digest.nf1_q_size = s.sume.nf1_q_size;
        s.digest.nf0_q_size = s.sume.nf0_q_size;
        // TODO remove:
        s.digest.unused = 0x47;

        send_digest();
    }

    // // TODO this could be a generic function, but then it gets confusing how to
    // // tell it which register I mean :D
    // action read_and_clear_signal(in signal_idx idx, out bit<1> res) {
    //     signal_reg_praw(idx, 0, 0, REG_WRITE, true, EQ_RELOP, _, res);
    // }

    // this cannot be an action because SDNet does not support
    // calling exit() from an action
    #define CHECK(err)                                              \
        if (err.error_flag != ERROR.NoError) {                      \
            copy_error_to_digest(err);                              \
            IFDBG(copy_debug_to_digest(err));  \
            exit;                                                   \
        }                                                           \

    // TODO the parts related to forwarding should be moved into something like
    // a ScionForwarder control or so
    error_data_t err;
    VerifyHF() verify_current_hf;

    bit<PACKET_COUNTER_WIDTH> curcnt;
    apply {
        egress_ifid_to_port.apply();

        increment_hf();
        update_checksums();

        verify_current_hf.apply(HF_MAC_KEY,
                                d.hdr.scion.path.current_inf.timestamp,
                                d.hdr.scion.path.current_hf,
                                d.hdr.scion.path.prev_hf,
                                err);

        // TODO remove: this is me figuring out how the timestamp thing works
        // bit<24> stats_time;
        // stats_timestamp(1, stats_time);
        // s.digest.debug1 = 40w0 ++ stats_time;

        // Increment the packet counter
        // this has to be directly in here because SDNet does not support
        // calling externs from actions
        packet_counter_reg_raw(1w0, 0, 1, REG_ADD, curcnt);
        if (curcnt == 1) send_stats_digest(); // 1 so that it's visible in tests

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
