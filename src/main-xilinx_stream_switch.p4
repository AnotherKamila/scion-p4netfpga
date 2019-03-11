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
        scion_parser.apply(packet, d.hdr, d.meta.scion);
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

    // Mapping of SCION interface number to physical port
    // TODO maybe it's not worth it having it in a table -- check with people if
    // they want this configurable
    // 1:1 mapping for now
    // table if_to_port {
    //     key = {
    // }
    //     actions = {
    //         set_dst_port;
    //         NoAction;
    //     }
    //     size=64;
    // }

    table dmac_to_port {
        key = {d.hdr.ethernet.dst_addr: exact;}
        actions = {
            set_dst_port;
            NoAction;
        }
        size=64;
    }

    apply {
        // bit<32> mac;
        // aes_mac((bit<128>){64w0, 32w0, 32w47}, mac);
        // d.hdr.encaps.udp.dst_port = (udp_port_t)mac[15:0];
        // d.hdr.encaps.udp.src_port = (udp_port_t)mac[31:16];
        
        // For now we just pretend to be a very expensive piece of wire, to be
        // able to run initial speed measurements.
        dmac_to_port.apply();
    }
}

@Xilinx_MaxPacketRegion(MTU)
parser TopDeparser(in local_t d,
                   packet_mod pkt) {

    ScionModDeparser() scion_deparser;
    state start{
        scion_deparser.apply(pkt, d.hdr);
        transition accept;
    }
}

XilinxStreamSwitch(TopParser(), TopPipe(), TopDeparser()) main;