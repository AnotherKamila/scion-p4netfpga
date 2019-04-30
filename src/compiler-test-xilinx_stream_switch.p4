/*

Incompatibilities with p4c-sdnet:
=================================

v2018.2:
 - cannot use verify() or work with the error type
 - cannot use header unions
 - cannot use header stacks
 - cannot use 2-param packet.extract (with variable length)
 - CAN use packet.advance, but only with a fixed size
 - cannot define custom architecture, as architectures are built into the compiler
 - CAN use XilinxStreamSwitch by modifying the nf_sume_sdnet Verilog wrapper
 - UNKNOWN: Cycles in parser FSM may or may not be supported.

*/ 
#include <core.p4>
#include <sume_switch.p4>

#define MTU  16384

#include <compat/macros.p4>
// #include <compat/parser_utils.p4>

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

header tag_h {
    bit<8> val;
}

header skip_h {
    bit<8> val;
}

struct headers_t {
    tag_h tag;
    xy_h xy;
    skip_h skip_size;
}

//////////////////////////////////////////////////

struct user_metadata_t {
    bit<8> unused;
}

struct digest_data_t {
    bit<256> unused;
}

struct local_t {
    user_metadata_t meta;
    headers_t       hdr;
}

struct switch_meta_t {
    digest_data_t   digest;
    sume_metadata_t sume;
}

@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipperLinear(packet_in packet, in bit<8> skips) (bit<32> skip_size) {

    bit<8> skip_count = 0;

    state start {
        transition select(skip_count) {
            0: accept;
            default: skip_loop;
        }
    }

    state skip_loop {
        transition select(skip_count == skips) {
            true:  accept;
            false: do_skip;
        }
    }

    state do_skip {
        packet.advance(8*skip_size);
        skip_count = skip_count + 1;
        transition skip_loop;
    }
}

@Xilinx_MaxPacketRegion(MTU)
parser SubSelect(packet_in packet, in bit<8> tag, out xy_h hdr) {
    state start {
        transition select(tag) {
            0: parse_x;
            1: parse_y;
        }
    }

    state parse_x {
        packet.extract(hdr.x);
    }

    state parse_y {
        packet.extract(hdr.y);
    }

}

@Xilinx_MaxPacketRegion(MTU)
parser SubSkipper(packet_in packet, in bit<8> skip) {
    PacketSkipperLinear(1) skipper;

    state start {
        skipper.apply(packet, skip);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MTU)
parser TopParser(packet_in packet, 
                 out local_t local) {
    SubSelect()  sub_select;
    SubSkipper() sub_skipper;
    state start {
        packet.extract(local.hdr.tag);
        sub_select.apply(packet, local.hdr.tag.val, local.hdr.xy);
        packet.extract(local.hdr.skip_size);
        sub_skipper.apply(packet, local.hdr.skip_size.val);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MTU)
control TopPipe(inout local_t local,
                inout switch_meta_t s) {

    apply {
        local.hdr.xy.x.val = 16w47;
        s.sume.dst_port = 8w1; // NF0
    }
}

@Xilinx_MaxPacketRegion(MTU)
parser TopDeparser(in local_t local,
                   packet_mod pkt) {

    state start{
        pkt.update(local.hdr.xy.x); // -- can't just do xy, because for SDNet it's a struct and pkt.update only takes headers
        pkt.update(local.hdr.xy.y); // _/
        transition accept; // don't forget! :D
    }
}

XilinxStreamSwitch(TopParser(), TopPipe(), TopDeparser()) main;
