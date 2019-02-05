/*

Incompatibilities with p4c-sdnet:
=================================

v2018.2:
 - cannot use verify() or work with the error type
 - cannot use header unions
 - cannot use header stacks
 - cannot use 2-param packet.extract (with variable length)
 - CAN use packet.advance => things can work with packet_mod
 - cannot define custom architecture, as architectures are built into the compiler
 - UNKNOWN: CAN use XilinxStreamSwitch by modifying the nf_sume_sdnet wrapper (Verilog)
 - UNKNOWN: How does it handle variable-sized things? If I change signatures, that will probably need to change too.

*/ 
#include <core.p4>
#include <sume_switch.p4>


#include <compat/macros.p4>

#define MAX_PACKET_REGION  16384



#include <xilinx_core.p4>
#include <xilinx.p4>


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
}

//////////////////////////////////////////////////

struct user_metadata_t {
    bit<8> unused;
}

struct digest_data_t {
    bit<256> unused;
}

struct local_t {
    digest_data_t digest;
    user_metadata_t meta;
    headers_t hdr;
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser TopParser(packet_in pkt, 
                 out local_t local) {

    state start {
        pkt.advance(16); // skip something, but avoid losing it!
        pkt.extract(local.hdr.xy.x);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control TopPipe(inout local_t local,
                inout sume_metadata_t sume) {

    apply {
        local.hdr.xy.x.val = 16w47;
        sume.dst_port = 8w1; // NF0
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser TopDeparser(in local_t local,
                   packet_mod pkt) {

    state start{
        pkt.advance(16);
        pkt.update(local.hdr.xy.x); // -- can't just do xy, because for SDNet it's a struct and pkt.update only takes headers
        pkt.update(local.hdr.xy.y); // _/
        transition accept; // don't forget! :D
    }
}

XilinxStreamSwitch(TopParser(), TopPipe(), TopDeparser()) main;
