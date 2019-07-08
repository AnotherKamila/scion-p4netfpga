// SCION parsers.
//
// Use ScionParser to do everything, or the parsers for various
// components to parse only some parts.
//
// The top-level ScionParser expects the full L2 packet (starting with the
// Ethernet header), and it will reject anything that is not SCION and indicate
// this by setting error to error.notScion.
// If you want to parse non-SCION packets as well, create your own equivalent
// of ScionParser by replacing the ScionEncapsulationParser with what you need
// and re-using ScionHeaderParser.

#ifndef SC__LIB__SCION__PARSERS_P4_
#define SC__LIB__SCION__PARSERS_P4_


#include <compat/macros.p4>
#include <compat/parser_utils.p4>
#include <common/constants.p4>
#include <scion/constants.p4>
#include <scion/datatypes.p4>
#include <scion/headers.p4>


#ifndef MTU
#error You must #define MTU before including this file.
#endif

#if !(defined TARGET_SUPPORTS_VAR_LEN_PARSING || defined TARGET_SUPPORTS_PACKET_MOD)
#error This file requires one of TARGET_SUPPORTS_{VAR_LEN_PARSING,PACKET_MOD}.
#endif

// Reason: SDNet does not support errors; see P4-SDNet p.8
// Also note that SDNet breaks in weird ways if I try to use the packet after a
// reject; so I define PARSE_ERROR to accept everything here.
#ifdef TARGET_SUPPORTS_VERIFY
#define PARSE_ERROR(e)              verify(false, ERROR.e)
#define PARSE_ERROR2(e, save_dest)  verify(false, ERROR.e)
#else
// assumes that "err" is in current scope
#define PARSE_ERROR(e)              err.error_flag = ERROR.e; transition accept
// this one doesn't
#define PARSE_ERROR2(e, save_dest)  save_dest      = ERROR.e; transition accept
#endif

#define IS_ERROR(err)  err.error_flag != ERROR.NoError
#define MERGE_ERRS(e1, e2)  (IS_ERROR(e1) ? e1 : e2)

// I wish SDNet supported verify, but it doesn't, hence the plethora of states
// containing only a PARSE_ERROR.

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
        // Ideally, here I'd check whether this is coming from a SCION port, but
        // I can't get the information about the overlay ports here, so I can't do
        // that and therefore I just accept everything here.
        transition accept;
    }

    state not_scion {
        PARSE_ERROR(NotSCION);
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
        transition check_version;
    }

    state check_version {
        transition select(hdr.version) {
            0:       check_offsets;
            default: bad_version;
        }
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

    state bad_version {
        PARSE_ERROR(BadVersion);
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
    PacketSkipper8(1) skipper;

    state start {
        packet.extract(hdr.dst_isdas);
        packet.extract(hdr.src_isdas);

        dst_host_parser.apply(packet, common.dst_addr_type, host_addr_len1, hdr.dst_host, err);
        src_host_parser.apply(packet, common.src_addr_type, host_addr_len2, hdr.src_host, err);

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
    state align_to_8_bytes {
        bit<3> skip = -pos_in_hdr[2:0]; // unary minus of last 3 bits = 8 - thingy
        pos_in_hdr = pos_in_hdr + (packet_size_t)skip;
        skipper.apply(packet, skip);
        transition accept;
    }
#endif
}

// Currently only supports 8-byte HFs -- TODO
@Xilinx_MaxPacketRegion(MTU)
parser ScionPathParser(packet_in packet, 
                       in  packet_size_t pos_in_hdr,
                       in  scion_common_h common,
                       out scion_path_header_t path,
                       out error_data_t err) {
    // TODO make this set smaller :-)
    const bit<8> UNSUPPORTED_INF_FLAGS = INF_FLAG_UP;
    const bit<8> UNSUPPORTED_HF_FLAGS  = HF_FLAG_CONTINUE | HF_FLAG_VRF_ONLY;

    // note: offsets validation happens in CommonHeaderParser, so we don't have
    // to worry about that here
    PacketSkipper16(8) skipper1; // TODO can we re-use the same one?
    PacketSkipper16(8) skipper2;
    bit<8> skips_to_inf = common.curr_INF - (bit<8>)(pos_in_hdr/8);
    bit<8> skips_to_hf  = common.curr_HF  - (bit<8>)(pos_in_hdr/8) - skips_to_inf - 1;
    // -1 because we extract current_inf, which is 1 8-byte block

    state start {
        err = {ERROR.NoError, 0};
        transition select(skips_to_hf[7:4] == 0 && skips_to_inf[7:4] == 0) {
            true:    skip_to_inf;
            default: path_too_long;
        }
    }

    state skip_to_inf {
        skipper1.apply(packet, skips_to_inf[3:0]);
        packet.extract(path.current_inf);
        transition select(path.current_inf.flags & UNSUPPORTED_INF_FLAGS) {
            0:       skip_to_hf;
            default: unsupported_flags;
        }
    }

    state skip_to_hf {
        // is this the first HF in this segment?
        transition select(skips_to_hf[3:0]) {
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
        skipper2.apply(packet, skips_to_hf[3:0] - 1); // -1 because we want prev
        packet.extract(path.prev_hf);
        transition parse_current_hf;
    }

    state parse_current_hf {
        packet.extract(path.current_hf);
        transition select(path.current_hf.flags & UNSUPPORTED_HF_FLAGS) {
            0: accept;
            default: unsupported_flags;
        }
    }

    state path_too_long {
        PARSE_ERROR(NotImpl_PathTooLong);
    }

    state unsupported_flags {
        PARSE_ERROR(NotImpl_UnsupportedFlags);
    }
}

@Xilinx_MaxPacketRegion(MTU)
parser ScionExtensionsParser(packet_in packet,
                             in  packet_size_t pos_in_hdr,
                             in  protocol_t    next_hdr,
                             out error_data_t err) {

    state start {
        transition select(next_hdr) {
            0x00:    hop_by_hop;
            default: accept; // not something that the BR cares about
        }
    }

    state hop_by_hop {
        PARSE_ERROR(NotImpl_UnsupportedExtension); // TODO :D
    }
}

@brief("Parses the SCION header (NOT including encapsulation).")
@Xilinx_MaxPacketRegion(MTU)
parser ScionHeaderParser(packet_in          packet, 
                         out scion_header_t hdr,
                         out error_data_t   err) {
    packet_size_t pos_in_hdr = 0; // current absolute position in bytes
    ScionCommonHeaderParser()  common_header_parser;
    ScionAddressHeaderParser() address_header_parser;
    ScionPathParser()          path_parser;
    // ScionExtensionsParser()    extensions_parser;

    // Because of SDNet, we have to accept everywhere, even if we have an error,
    // and we need to check for error manually here.

    state start {
        // parameters:              packet  state       input data  parsed header err
        common_header_parser.apply( packet, pos_in_hdr,             hdr.common,   err);
        transition select(err.error_flag) {
            ERROR.NoError: parse_address_header;
            default:       accept;  // stop parsing and give what you have to the pipeline
        }
    }

    state parse_address_header {
        address_header_parser.apply(packet, pos_in_hdr, hdr.common, hdr.addr,     err);
        transition select(err.error_flag) {
            ERROR.NoError: parse_path;
            default:       accept;  // stop parsing and give what you have to the pipeline
        }
    }

    state parse_path {
        path_parser.apply(          packet, pos_in_hdr, hdr.common, hdr.path,     err);
        transition accept;
        // TODO extensions
        // transition select(err.error_flag) {
        //     ERROR.NoError: parse_extensions;
        //     default:       accept;  // stop parsing and give what you have to the pipeline
        // }
    }

    // state parse_extensions {
    //     extensions_parser.apply(    packet, pos_in_hdr, hdr.common.next_hdr,      err);
    //     transition accept;
    // }
}

@brief("Parses SCION packets. Expects the full packet including Ethernet.")
@Xilinx_MaxPacketRegion(MTU)
parser ScionParser(packet_in               packet, 
                   out scion_all_headers_t hdr,
                   out error_data_t        err) {

    ScionEncapsulationParser() encaps_parser;
    ScionHeaderParser()        scion_header_parser;

    // Because of SDNet, we have to accept everywhere, even if we have an error,
    // and we need to check for error manually here.

    state start {
        packet.extract(hdr.ethernet);
        encaps_parser.apply(packet, hdr.ethernet.ethertype, hdr.encaps, err);
        transition select(err.error_flag) {
            ERROR.NoError: parse_scion;
            default:       accept;  // stop parsing and give what you have to the pipeline
        }
    }

    state parse_scion {
        scion_header_parser.apply(packet, hdr.scion, err);
        transition accept;
    }
}


#endif
