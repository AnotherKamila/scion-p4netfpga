/*

Incompatibilities with p4c-sdnet:
=================================

v2018.2:
 - cannot use verify() or work with the error type
 - cannot use header unions
 - cannot use header stacks
 - cannot use 2-param packet.extract (with variable length)
 - CAN use packet.advance => things can work with packet_mod

*/ 
#include <core.p4>
#include <sume_switch.p4>


#include <compat/macros.p4>

#define MAX_PACKET_REGION  16384

header x_h {
    bit<16> val;
}
header y_h {
    bit<8> val;
}
HEADER_UNION xy_h {
    x_h x;
    y_h y;
}

struct headers_t {
    xy_h xy;
    // t_h[10] ts;
}

struct user_metadata_t {
    bit<8> unused;
}

struct digest_data_t {
    bit<256> unused;
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser TopParser(packet_in packet, 
                 out headers_t hdr,
                 out user_metadata_t meta,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {

    state start {
        packet.advance(32);
        packet.extract(hdr.xy.x);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopPipe(inout headers_t hdr,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    apply {
        hdr.xy.y.val = 8w47;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopDeparser(packet_out packet,
                    in headers_t hdr,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 

    apply {
        packet.emit(hdr.xy);
    }
}

SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
