// SCION parsers.
//
// Use ScionParser to do everything, or the parsers for various
// components to parse only some parts.
//
// The top-level ScionParser expects the full L2 packet (starting with the
// Ethernet header), and it will reject anything that is not SCION and indicate
// this by setting error to error.notScion.
// If you want to process non-SCION packets as well, create your own equivalent
// of ScionParser by replacing the ScionEncapsulationParser with what you need
// and re-using ScionHeaderParser.
//
// TODO Actually, it is possible to parametrise the parsers with whether it
// should accept or reject non-SCION: just replayce verify(false, ...) with
// verify(parameter, ...) and put a transition: accept below

#ifndef SC__LIB__SCION__PARSERS_P4_
#define SC__LIB__SCION__PARSERS_P4_


// TODO actually, I desperately want verify... figure out how we can implement
// it for SDNet
// TODO ...and then handle parser errors properly :D

#include <compat/macros.p4>
#include <common/constants.p4>
#include <scion/constants.p4>
#include <scion/datatypes.p4>
#include <scion/headers.p4>

#if !(defined TARGET_SUPPORTS_VAR_LEN_PARSING || defined TARGET_SUPPORTS_PACKET_MOD)
#error This parser requires one of TARGET_SUPPORTS_{VAR_LEN_PARSING,PACKET_MOD}.
#endif

#ifndef MTU
#error You must #define MTU before including this file.
#endif

@brief("Parses IP/UDP encapsulation (if present), choosing by ethertype.")
@Xilinx_MaxPacketRegion(MTU)
parser ScionEncapsulationParser(packet_in          packet,
                                in  ethertype_t    ethertype,
                                out scion_encaps_t encaps,
                                out error_data_t   err) {
    state start {
        err = {ERROR.NoError, 0};

        transition select(ethertype) {
            ETHERTYPE_IPV4: parse_ipv4;
            ETHERTYPE_IPV6: parse_ipv6;
            // TODO non-encapsulated SCION, once we have an Ethertype:
            // ETHERTYPE_SCION: accept;
            default:        not_scion;
        } 
    }

    // TODO IP and UDP get more complex when OPTIONS happen, so this should go
    // into <common/parsers.p4> instead
    state parse_ipv4 { 
        // TODO options
        packet.extract(encaps.ip.v4);
        transition select(encaps.ip.v4.protocol) {
            PROTOCOL_UDP: parse_udp;
            default:      not_scion;
        }
    }

    state parse_ipv6 { 
        // TODO extensions
        packet.extract(encaps.ip.v6);
        transition select(encaps.ip.v6.next_hdr) {
            PROTOCOL_UDP: parse_udp;
            default:      not_scion;
        }
    }

    state parse_udp {
        packet.extract(encaps.udp);
        // TODO UDP checksum
        transition select(encaps.udp.dst_port) {
            SCION_PORT: accept;
            default:    not_scion;
        }
    }

    state not_scion {
        PARSE_ERROR(L2Error);
    }
}

// Note: if I happen to want to increase clock frequency, I should make
// pos_in_hdr not inout if I run into timing problems
@brief("Parses the SCION Common Header.")
@Xilinx_MaxPacketRegion(MTU)
parser ScionCommonHeaderParser(packet_in            packet, 
                               inout packet_size_t  pos_in_hdr,
                               out   scion_common_h hdr,
                               out   error_data_t   err) {
    state start {
        err = {ERROR.NoError, 0};

        packet.extract(hdr);
        pos_in_hdr = pos_in_hdr + SCION_COMMON_H_SIZE;
        transition check_offsets;
    }

    // This has to be a select instead of just a call to verify() because SDNet
    // doesn't support verify
    // TODO might be worth it to re-write with #ifdef TARGET_SUPPORTS_VERIFY
    state check_offsets {
        // check that INF/HF isn't beyond end of header
        transition select(hdr.curr_INF < hdr.hdr_len &&
                          hdr.curr_HF  < hdr.hdr_len &&
                          hdr.curr_INF < hdr.curr_HF) {
            true:    accept;
            default: invalid_offset;
        }
    }

    state invalid_offset {
        PARSE_ERROR(InvalidOffset);
    }

}

// Parses the given type of SCION host address (IPv4, IPv6 or Service).
// Used inside ScionAddressHeaderParser.
@Xilinx_MaxPacketRegion(MTU)
parser ScionHostAddressParser(packet_in                  packet,
                              in  scion_host_addr_type_t type,
                              out packet_size_t          addr_len,
                              out scion_host_addr_h      hdr,
                              out error_data_t           err) {
    state start {
        err = {ERROR.NoError, 0};

        transition select(type) {
            SCION_HOST_ADDR_IPV4: ipv4;
            SCION_HOST_ADDR_IPV6: ipv6;
            SCION_HOST_ADDR_SVC:  svc;
            default:              bad_host_addr_type;
        }
    }

    state ipv4 {
        packet.extract(hdr.ipv4);
        addr_len = 4;
        transition accept;
    }

    state ipv6 {
        packet.extract(hdr.ipv6);
        addr_len = 16;
        transition accept;
    }

    state svc {
        packet.extract(hdr.service);
        addr_len = 2;
        transition accept;
    }

    state bad_host_addr_type {
        PARSE_ERROR(BadHostAddrType);
    }
}

// Parses the SCION Address Header
@Xilinx_MaxPacketRegion(MTU)
parser ScionAddressHeaderParser(packet_in packet, 
                                inout packet_size_t       pos_in_hdr,
                                in    scion_common_h      common,
                                out   scion_addr_header_t hdr,
                                out   error_data_t        err) {

    ScionHostAddressParser() dst_host_parser;
    ScionHostAddressParser() src_host_parser;
    packet_size_t host_addr_len1;
    packet_size_t host_addr_len2;

    state start {
        packet.extract(hdr.dst_isdas);
        packet.extract(hdr.src_isdas);

        dst_host_parser.apply(packet, common.dst_addr_type, host_addr_len1, hdr.dst_host, err);
        src_host_parser.apply(packet, common.src_addr_type, host_addr_len2, hdr.src_host, err);
        // if both had an error, some error will fall out at the end :D

        pos_in_hdr = pos_in_hdr + 2*SCION_ISDAS_ADDR_H_SIZE + host_addr_len1 + host_addr_len2;
        transition align_to_8_bytes;
    }

#ifdef TARGET_SUPPORTS_VAR_LEN_PARSING
    state align_to_8_bytes {
        bit<3> skip = -pos_in_hdr[2:0]; // unary minus of last 3 bits = 8 - thingy
        pos_in_hdr = pos_in_hdr + (packet_size_t)skip;
        PACKET_SKIP(packet, 8*(bit<32>)skip, hdr.align_bits);
        transition accept;
    }
#else
    // buaaaaaaaaaaaaaaah T-T
    // have to make separate states for this because SDNet is horrible
    // TODO use PacketSkipper8 instead
    state align_to_8_bytes {
        transition select(pos_in_hdr[2:0]) {
            0: accept;
            2: skip_6;
            4: skip_4;
            6: skip_2;
            default: panic; // odd values are currently impossible
        }
    }

    // TODO kill it!!!! (with a higher-level macro)
    state skip_2 {
        packet.advance(8*2);
        pos_in_hdr = pos_in_hdr + 8*2;
        transition accept;
    }
    state skip_4 {
        packet.advance(8*4);
        pos_in_hdr = pos_in_hdr + 8*4;
        transition accept;
    }
    state skip_6 {
        packet.advance(8*6);
        pos_in_hdr = pos_in_hdr + 8*6;
        transition accept;
    }
    #endif

    state panic {
        PARSE_ERROR(InternalError);
    }
}

// TODO we could use the PacketSkipper for above too
// TODO move to compat/
@brief("Skips bytes from packet in multiples of skip_size.")
@description("If not TARGET_SUPPORTS_VAR_LEN_PARSING, can skip at most \
8 blocks and uses more FPGA area, but it works.")
@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipper8(packet_in packet, in bit<8> skips, out error_data_t err) (bit<32> skip_size) {

    #ifdef TARGET_SUPPORTS_VAR_LEN_PARSING
    // TODO do the same as in SCIONAddrParser
    #error Not implemented yet
    #else // assume TARGET_SUPPORTS_PACKET_MOD
    // ♪♫ we do what we must because we can ♫
    state start {
        err = {ERROR.NoError, 0};

        transition select(skips) {
            #define LOOPBODY(i) i: skip_##i;
            #include <compat/loop8.itm>
            #undef LOOPBODY
            default: panic; // somebody asked us to skip more than 32 things
        }
    }

    #define LOOPBODY(i) state skip_##i { packet.advance(8*skip_size*i); transition accept; }
    #include <compat/loop8.itm>
    #undef LOOPBODY

    #endif

    state panic {
        PARSE_ERROR(InternalError);
    }
}

// TODO move to compat/
@brief("Skips bytes from packet in multiples of skip_size bytes.")
@description("If not TARGET_SUPPORTS_VAR_LEN_PARSING, can skip at most \
64 blocks and uses more FPGA area, but it works.")
@Xilinx_MaxPacketRegion(MTU)
parser PacketSkipper64(packet_in packet, in bit<8> skips, out error_data_t err) (bit<32> skip_size) {

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
    state start {
        stage1.apply(packet, skips / 8, err);
        stage2.apply(packet, skips % 8, err);
        transition accept;
    }

    #endif
}

@Xilinx_MaxPacketRegion(MTU)
parser ScionPathParser(packet_in packet, 
                       in  packet_size_t pos_in_hdr,
                       in  scion_common_h common,
                       out scion_path_header_t path,
                       out error_data_t err) {
    // note: offsets validation happens in CommonHeaderParser, so we don't have
    // to worry about that here
    PacketSkipper64(8) skipper1; // TODO can we re-use the same one?
    PacketSkipper64(8) skipper2;
    bit<8> skips_to_inf = common.curr_INF - (bit<8>)(pos_in_hdr/8);
    bit<8> skips_to_hf  = common.curr_HF  - (bit<8>)(pos_in_hdr/8) - skips_to_inf - 1;
    // -1 because we extract current_inf, which is 1 8-byte block

    state start {
        transition skip_to_inf;
    }

    state skip_to_inf {
        skipper1.apply(packet, skips_to_inf, err);
        packet.extract(path.current_inf);
        transition skip_to_hf;
    }

    state skip_to_hf {
        // is this the first HF in this segment?
        transition select(skips_to_hf) {
            0:       no_prev_hf;
            default: skip_to_prev_hf;
        }
    }

    state no_prev_hf {
        // TODO is this necessary or are things defined to be 0?
        path.prev_hf.flags      = 0;
        path.prev_hf.expiry     = 0;
        path.prev_hf.ingress_if = 0;
        path.prev_hf.egress_if  = 0;
        path.prev_hf.mac        = 0;
        transition parse_current_hf;
    }

    state skip_to_prev_hf {
        skipper2.apply(packet, skips_to_hf - 1, err); // -1 because we want prev
        packet.extract(path.prev_hf);
        transition parse_current_hf;
    }

    state parse_current_hf {
        packet.extract(path.current_hf);
        transition accept;
    }

}

// TODO
@Xilinx_MaxPacketRegion(MTU)
parser ScionExtensionsParser(packet_in packet, 
                             out scion_header_t hdr) {

    state start {
        transition accept;
    }
}

// Parses the SCION header (NOT including encapsulation).
@Xilinx_MaxPacketRegion(MTU)
parser ScionHeaderParser(packet_in          packet, 
                         out scion_header_t hdr,
                         out error_data_t   err) {
    packet_size_t pos_in_hdr = 0; // current absolute position in bytes
    ScionCommonHeaderParser()  common_header_parser;
    ScionAddressHeaderParser() address_header_parser;
    ScionPathParser()          path_parser;
    // ScionExtensionsParser()    extensions_parser;

    state start {
        // TODO check errors!
        // parameters:              packet  state       input data  parsed header err
        common_header_parser.apply( packet, pos_in_hdr,             hdr.common,   err);
        address_header_parser.apply(packet, pos_in_hdr, hdr.common, hdr.addr,     err);
        path_parser.apply(          packet, pos_in_hdr, hdr.common, hdr.path,     err);
        // TODO:
        // extensions_parser.apply(packet, hdr, meta);

        transition accept;
    }
}

@brief("Parses SCION packets. Expects the full packet including Ethernet.")
@Xilinx_MaxPacketRegion(MTU)
parser ScionParser(packet_in               packet, 
                   out scion_all_headers_t hdr,
                   out error_data_t        err) {

    ScionEncapsulationParser() encaps_parser;
    ScionHeaderParser()        scion_header_parser;

    state start {
        packet.extract(hdr.ethernet);
        encaps_parser.apply(packet, hdr.ethernet.ethertype, hdr.encaps, err);
        transition select(err.error_flag) {
            ERROR.NoError: parse_scion;
            default:         handle_err;
        }
    }

    state parse_scion {
        scion_header_parser.apply(packet, hdr.scion, err);
        transition accept;
    }

    state handle_err {
        // TODO should we be accepting or rejecting if we want to generate an
        // error message?
        // TODO check what reject does; if it can be used, then we could apply
        // an ErrorChecker parser that just rejects in NetFPGA case or calls
        // verify(false, err) for bmv2
        transition accept;
    }
}


#endif