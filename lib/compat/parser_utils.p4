#ifndef SC__LIB__COMPAT__PARSER_UTILS_P4_
#define SC__LIB__COMPAT__PARSER_UTILS_P4_


#include <core.p4>
#include <compat/macros.p4>


#if !(defined TARGET_SUPPORTS_VAR_LEN_PARSING || defined TARGET_SUPPORTS_PACKET_MOD)
#error This file requires one of TARGET_SUPPORTS_{VAR_LEN_PARSING,PACKET_MOD}.
#endif

#ifndef MTU
#error You must #define MTU before including this file.
#endif


// If we have packet_mod, we can actually skip parts of headers without losing
// them; otherwise we save them so that we can emit them.
// dest is expected to be a varbit type.
#ifdef TARGET_SUPPORTS_PACKET_MOD
#define PACKET_SKIP(pkt, size, save_dest)  pkt.advance(size)
#define PACKET_SKIP_SAVE_DEST(x)
#else
#define PACKET_SKIP(pkt, size, save_dest)  pkt.extract(save_dest, size)
#define PACKET_SKIP_SAVE_DEST(x)  x
#endif

@brief("Skips bytes from packet in multiples of skip_size.")
@description("If not TARGET_SUPPORTS_VAR_LEN_PARSING, can skip at most \
8 blocks and uses more FPGA area, but it works.")
@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipper8(packet_in packet, in bit<8> skips, out bool too_long) (bit<32> skip_size) {

    #ifdef TARGET_SUPPORTS_VAR_LEN_PARSING
    // TODO do the same as in SCIONAddrParser
    #error Not implemented yet
    #else // assume TARGET_SUPPORTS_PACKET_MOD
    // ♪♫ we do what we must because we can ♫
    state start {
        too_long = false;

        transition select(skips) {
            #define LOOPBODY(i) i: skip_##i;
            #include <compat/loop8.itm>
            #undef LOOPBODY
            default: fail; // somebody asked us to skip more than 32 things
        }
    }

    #define LOOPBODY(i) state skip_##i { packet.advance(8*skip_size*i); transition accept; }
    #include <compat/loop8.itm>
    #undef LOOPBODY

    #endif

    state fail {
        too_long = true;
        transition accept;
    }
}

// TODO move to compat/
@brief("Skips bytes from packet in multiples of skip_size bytes.")
@description("If not TARGET_SUPPORTS_VAR_LEN_PARSING, can skip at most \
64 blocks and uses more FPGA area, but it works.")
@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipper64(packet_in packet, in bit<8> skips, out bool too_long) (bit<32> skip_size) {

    #ifdef TARGET_SUPPORTS_VAR_LEN_PARSING
    // TODO do the same as in SCIONAddrParser
    #error Not implemented yet
    #else // assume TARGET_SUPPORTS_PACKET_MOD
    // Square root idea:
    // 1. let maximum supported skips = k^2
    // 2. then we can write skips = k*a + b
    //                      where a = skips / 8, b = skips mod 8
    // => we skip in two stages, stage 1 with "big" skips sized k*skip_size and stage 2 with "normal-sized" skips

    // in our case k = 8:
    // SDNet does not consider X*8 a compile time constant, but X<<3 is fine :D
    PacketSkipper8(skip_size << 3) stage1; // skips to skip_size/8 * floor(skips / 8)
    PacketSkipper8(skip_size)      stage2; // skips to skips % 8
    bool too_long1;
    bool too_long2;
    state start {
        stage1.apply(packet, skips / 8, too_long1);
        stage2.apply(packet, skips % 8, too_long2);
        too_long = too_long1 || too_long2;
        transition accept;
    }

    #endif
}


#endif