// main for NetFPGA SUME switch with the XilinxStreamSwitch architecture

#include <core.p4>        // P4 core
#include <xilinx_core.p4> // packet_mod
#include <xilinx.p4>      // XilinxStreamSwitch
#include <sume_switch.p4> // sume_metadata

#include "settings.p4" // must be included *before* SCION

#include <scion/headers.p4>
#include <scion/parsers.p4>
#include <scion/deparsers.p4>

#include "datatypes.p4"

struct local_t {
    digest_data_t       digest;
    user_metadata_t     meta;
    scion_all_headers_t hdr;
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser TopParser(packet_in packet, out local_t d) {
    
    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, d.hdr, d.meta.scion);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopPipe(inout local_t d,
                inout sume_metadata_t sume) {

    apply {
        d.hdr.ethernet.ethertype = 0x47;
        sume.dst_port = 8w1; // nf0
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser TopDeparser(in local_t d,
                   packet_mod pkt) {

    // ScionModDeparser() scion_deparser;
    state start{
        // scion_deparser.apply(pkt, d.hdr);
        pkt.update(d.hdr.ethernet);
        transition accept;
    }
}

XilinxStreamSwitch(TopParser(), TopPipe(), TopDeparser()) main;