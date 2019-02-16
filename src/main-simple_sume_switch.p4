// main for NetFPGA SUME switch with the XilinxStreamSwitch arch9tecture
#include <core.p4>
#include <sume_switch.p4>

#include "settings.p4" // must be included *before* SCION

#include <scion/headers.p4>
#include <scion/parsers.p4>
#include <scion/deparsers.p4>

#include "datatypes.p4"

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser TopParser(packet_in packet, 
                 out   scion_all_headers_t hdr, 
                 out user_metadata_t meta,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume) {

    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, hdr, meta.scion);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopPipe(inout scion_all_headers_t hdr,
                inout user_metadata_t meta,
                inout digest_data_t digest,
                inout sume_metadata_t sume) {

    apply {
        eth_addr_t tmp_src    = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp_src;
        hdr.ethernet.ethertype = 0x47;
        sume.dst_port = 8w1; // nf0
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopDeparser(packet_out packet,
                    in scion_all_headers_t hdr,
                    in user_metadata_t meta,
                    inout digest_data_t digest,
                    inout sume_metadata_t sume) {

    ScionDeparser() scion_deparser;
    apply {
        scion_deparser.apply(packet, hdr);
    }
}

SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
