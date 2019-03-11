// main for the v1model simple_switch architecture of the P4 software switch emulator
#include <core.p4>
#include <v1model.p4>

#include "settings.p4" // must be included *before* SCION

#include <scion/headers.p4>
#include <scion/parsers.p4>
#include <scion/deparsers.p4>

#include "datatypes.p4"


parser TopParser(packet_in packet, 
                 out   scion_all_headers_t hdr, 
                 inout user_metadata_t meta,
                 inout standard_metadata_t standard_meta) {

    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, hdr, meta.scion);
        transition accept;
    }
}

control TopPipe(inout scion_all_headers_t hdr,
                inout user_metadata_t user_metadata, 
                inout standard_metadata_t standard_metadata) {

    apply {
        hdr.ethernet.ethertype = 0x47;
    }
}

control TopDeparser(packet_out packet,
                    in scion_all_headers_t hdr) {

    ScionDeparser() scion_deparser;
    apply {
        scion_deparser.apply(packet, hdr);
    }
}


control EmptyVerifyChecksum(inout scion_all_headers_t  hdr, inout user_metadata_t meta) {
    apply {}
}
control EmptyComputeChecksum(inout scion_all_headers_t  hdr, inout user_metadata_t meta) {
    apply {}
}
control EmptyEgress(inout scion_all_headers_t hdr,
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