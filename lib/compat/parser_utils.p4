#ifndef SC__LIB__COMPAT__PARSER_UTILS_P4_
#define SC__LIB__COMPAT__PARSER_UTILS_P4_


#include <core.p4>
#include <compat/macros.p4>


#ifndef MTU
#error You must #define MTU before including this file.
#endif


@brief("Skips bytes from packet in multiples of skip_size.")
@description("Can skip at most 8 blocks. \
If not TARGET_SUPPORTS_VAR_LEN_PARSING, it uses more FPGA area, but it works. \
Note that unless you use packet_mod, the skipped bytes are lost.")
@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipper8(packet_in packet, in bit<3> skips) (bit<32> skip_size) {

    #ifdef TARGET_SUPPORTS_VAR_LEN_PARSING

    state start {
        packet.advance(8*skip_size*skips);
        transition accept;
    }

    #else

    // A loop doesn't work because SDNet gets extremely confused and generates
    // invalid px code.
    // Can't really reproduce with simpler code either, so...
    // ♪♫ We do what we must because we can... ♫
    state start {
        transition select(skips) {
            #define LOOPBODY(i) i: skip_##i;
            #include <compat/loop8.itm>
            #undef LOOPBODY
        }
    }

    #define LOOPBODY(i) state skip_##i { packet.advance(8*skip_size*i); transition accept; }
    #include <compat/loop8.itm>
    #undef LOOPBODY

    #endif
}

@brief("Skips bytes from packet in multiples of skip_size bytes.")
@description("Can skip at most 64 blocks. \
If not TARGET_SUPPORTS_VAR_LEN_PARSING, it uses more FPGA area, but it works. \
Note that unless you use packet_mod, the skipped bytes are lost.")
@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipper64(packet_in packet, in bit<6> skips) (bit<32> skip_size) {

    #ifdef TARGET_SUPPORTS_VAR_LEN_PARSING

    state start {
        packet.advance(8*skip_size*skips);
        transition accept;
    }

    #else

    // Square root idea:
    // 1. let maximum supported skips = k^2
    // 2. then we can write skips = k*a + b
    //                      where a = skips / 8, b = skips mod 8
    // => we skip in two stages, stage 1 with "big" skips sized k*skip_size and stage 2 with "normal-sized" skips

    // in our case k = 8:
    // SDNet does not consider X*8 a compile time constant, but X<<3 is fine :D
    PacketSkipper8(skip_size << 3) stage1; // skips to skip_size/8 * floor(skips / 8)
    PacketSkipper8(skip_size)      stage2; // skips to skips % 8
    state start {
        stage1.apply(packet, skips[5:3]);
        stage2.apply(packet, skips[2:0]);
        transition accept;
    }

    #endif
}

// Never tested this because of an extremely weird SDNet compiler bug. I do not
// know if it would be better than the unrolled one.
// TODO test with a different main() to compare.
@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipperLinear(packet_in packet, in bit<6> skips) (bit<32> skip_size) {

    bit<6> skip_count = 0;

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

// If we have packet_mod, we can actually skip parts of headers without losing
// them; otherwise we have to save them if we want to emit them.
// save_dest is expected to be a varbit type.
#ifdef TARGET_SUPPORTS_PACKET_MOD
#define PACKET_SKIP(pkt, size, save_dest)  pkt.advance(size)
#define PACKET_SKIP_SAVE_DEST(x)
#else
#define PACKET_SKIP(pkt, size, save_dest)  pkt.extract(save_dest, size)
#define PACKET_SKIP_SAVE_DEST(x)  x
#endif


#endif