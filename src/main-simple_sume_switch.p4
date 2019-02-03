// main for NetFPGA SUME switch
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
                 inout sume_metadata_t sume_metadata) {

    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, hdr, meta.scion);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopPipe(inout scion_all_headers_t hdr,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    apply {
        hdr.ethernet.ethertype = 0x47;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopDeparser(packet_out packet,
                    in scion_all_headers_t hdr,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 

    ScionDeparser() scion_deparser;
    apply {
        scion_deparser.apply(packet, hdr);
    }
}

SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
