// main for NetFPGA SUME switch
#include <core.p4>
#include <sume_switch.p4>

#define PARSER_HAS_REJECT 1


#include "settings.p4"   // table sizes, register widths, and such
#include "headers.p4"    // packet headers, plus the metadata struct
#include "parsers.p4"    // parser and deparser

// TODO(optimisation): try removing unnecessary parameters everywhere

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser TopParser(packet_in packet, 
                 out headers_t hdr, 
                 out user_metadata_t user_metadata,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {
    state start {
        MaybeScionTopParser.apply(packet, hdr);
    }
}

control TopPipe(inout headers_t hdr,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    apply {
        hdr.ethernet.ethertype = 0x47;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopDeparser(packet_out packet,
                    in headers_t hdr,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 
    apply {
        ScionTopDeparser.apply(packet, hdr);
    }
}

SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
