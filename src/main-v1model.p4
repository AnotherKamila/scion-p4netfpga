// main for v1model emulator
#include <core.p4>
#include <v1model.p4>

#include "settings.p4"   // table sizes, register widths, and such
#include "headers.p4"    // packet headers, plus the metadata struct
#include "parsers.p4"
#include "deparsers.p4"


parser TopParser(packet_in packet, 
                 out headers_t hdr, 
                 inout user_metadata_t meta,
                 inout standard_metadata_t standard_meta) {

    ScionParser() scion_parser;
    state start{
        scion_parser.apply(packet, hdr, meta.scion);
        transition accept;
    }
}

control TopPipe(inout headers_t hdr,
                inout user_metadata_t user_metadata, 
                inout standard_metadata_t standard_metadata) {

    apply {
        hdr.ethernet.ethertype = 0x47;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopDeparser(packet_out packet,
                    in headers_t hdr) {

    ScionDeparser() scion_deparser;
    apply {
        scion_deparser.apply(packet, hdr);
    }
}


control EmptyVerifyChecksum(inout headers_t  hdr, inout user_metadata_t meta) {
    apply {}
}
control EmptyComputeChecksum(inout headers_t  hdr, inout user_metadata_t meta) {
    apply {}
}
control EmptyEgress(inout headers_t hdr,
                 inout user_metadata_t meta,
                 inout standard_metadata_t standard_metadata) {
    apply {}
}

V1Switch(
    TopParser(),
    EmptyVerifyChecksum(),
    TopPipe(),
    EmptyEgress(),
    EmptyComputeChecksum(),
    TopDeparser()
) main;