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


#include <compat/macros.p4>
#include <common/constants.p4>
#include <scion/constants.p4>
#include <scion/datatypes.p4>
#include <scion/errors.p4>
#include <scion/headers.p4>

// TODO clean up param ordering: in first, inout middle, out last

// Parses Ethernet and IP/UDP encapsulation (if present).
@Xilinx_MaxPacketRegion(MTU)
parser ScionEncapsulationParser(packet_in packet,
                                in  ethertype_t    ethertype,
                                out scion_encaps_t encaps) {
    state start {
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
        // TODO don't forget UDP checksum!
        //  1. find out if it's possible to put it into the parser
        //  2. find out what's faster
        transition select(encaps.udp.dst_port) {
            SCION_PORT: accept;
            default:    not_scion;
        }
    }

    state not_scion {
        // TODO
        // verify(false, error.NotScion);
        ERROR(error.NoMatch);
        // transition reject;
    }
}

// Parses the SCION Common Header
@Xilinx_MaxPacketRegion(MTU)
parser ScionCommonHeaderParser(packet_in packet, 
                               out scion_common_h     hdr,
                               inout scion_metadata_t meta) {
    state start {
        meta.pos_in_hdr = 0;

        packet.extract(hdr);
        meta.pos_in_hdr = meta.pos_in_hdr + SCION_COMMON_H_SIZE;
        transition check_offsets;
    }

    // This has to be a select instead of just a call to verify() because SDNet
    // doesn't support verify
    // TODO might be worth it to re-write with #ifdef TARGET_SUPPORTS_VERIFY
    state check_offsets {
        // check that INF/HF isn't beyond end of header
        transition select(hdr.curr_INF < hdr.hdr_len &&
                          hdr.curr_HF  < hdr.hdr_len) {
            true:  accept;
            false: err_invalid_pointer;
        }
    }

    state err_invalid_pointer {
        ERROR(error.HeaderTooShort);
    }

}

// Parses the given type of SCION host address (IPv4, IPv6 or Service).
// Used inside ScionAddressHeaderParser.
@Xilinx_MaxPacketRegion(MTU)
parser ScionHostAddressParser(packet_in packet,
                              in  scion_host_addr_type_t type,
                              out scion_host_addr_h      hdr,
                              out packet_size_t          addr_len) {
    state start {
        transition select(type) {
            SCION_HOST_ADDR_IPV4: ipv4;
            SCION_HOST_ADDR_IPV6: ipv6;
            SCION_HOST_ADDR_SVC:  svc;
            default:              error_unknown_host_addr_type;
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

    state error_unknown_host_addr_type {
        // verify(false, error.UnknownScionHostAddrType);
        // TODO
        ERROR(error.NoMatch);
        // transition reject;
    }
}

// Parses the SCION Address Header
@Xilinx_MaxPacketRegion(MTU)
parser ScionAddressHeaderParser(packet_in packet, 
                                in    scion_common_h      common,
                                out   scion_addr_header_t hdr,
                                inout scion_metadata_t    meta) {

    ScionHostAddressParser() dst_host_parser;
    ScionHostAddressParser() src_host_parser;
    packet_size_t host_addr_len;

    state start {
        packet.extract(hdr.dst_isdas);
        packet.extract(hdr.src_isdas);
        meta.pos_in_hdr = meta.pos_in_hdr + 2*SCION_ISDAS_ADDR_H_SIZE;

        dst_host_parser.apply(packet, common.dst_addr_type, hdr.dst_host, host_addr_len);
        meta.pos_in_hdr = meta.pos_in_hdr + host_addr_len;

        src_host_parser.apply(packet, common.src_addr_type, hdr.src_host, host_addr_len);
        meta.pos_in_hdr = meta.pos_in_hdr + host_addr_len;

        // align to 8 bytes
        bit<4> skip = 4w8 - (bit<4>)meta.pos_in_hdr[2:0]; // last 3 bits => mod 8
        meta.pos_in_hdr = meta.pos_in_hdr + (packet_size_t)skip;

#ifdef TARGET_SUPPORTS_VAR_LEN_PARSING

        PACKET_SKIP(packet, 8*(bit<32>)skip, hdr.align_bits);
        transition accept;

#else
        // buaaaaaaaaaaaaaaah T-T
        // have to make separate states for this because SDNet is horrible
        // TODO this should be a macro because I'll need it in path parsing too
        transition select(skip) {
            0: accept;
            2: skip_2;
            4: skip_4;
            6: skip_6;
            // odd values are currently impossible
        }
#endif

    }

#ifndef TARGET_SUPPORTS_VAR_LEN_PARSING
    // TODO kill it!!!! (with a higher-level macro)
    state skip_2 {
        packet.advance(8*2);
        transition accept;
    }
    state skip_4 {
        packet.advance(8*4);
        transition accept;
    }
    state skip_6 {
        packet.advance(8*6);
        transition accept;
    }
#endif

}

// TODO
@Xilinx_MaxPacketRegion(MTU)
parser ScionPathParser(packet_in packet, 
                       in  scion_common_h common,
                       out scion_path_header_t hdr,
                       inout scion_metadata_t meta) {
    state start {
        transition skip_to_inf;
    }

    state skip_to_inf {
        transition skip_to_hf;
    }

    state skip_to_hf {
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
parser ScionHeaderParser(packet_in packet, 
                         out scion_header_t hdr,
                         out scion_metadata_t meta) {

    ScionCommonHeaderParser()  common_header_parser;
    ScionAddressHeaderParser() address_header_parser;
    // ScionPathParser()          path_parser;
    // ScionExtensionsParser()    extensions_parser;

    state start {
        common_header_parser.apply(packet, hdr.common, meta);
        address_header_parser.apply(packet, hdr.common, hdr.addr, meta);
        // TODO:
        // path_parser.apply(packet, hdr.path, meta);
        // extensions_parser.apply(packet, hdr, meta);

        transition accept;
    }
}

// As stated above, this expects the full packet including Ethernet.
@Xilinx_MaxPacketRegion(MTU)
parser ScionParser(packet_in packet, 
                   out scion_all_headers_t hdr,
                   out scion_metadata_t meta) {

    ScionEncapsulationParser() encaps_parser;
    ScionHeaderParser()        scion_header_parser;

    state start {
        packet.extract(hdr.ethernet);
        encaps_parser.apply(packet, hdr.ethernet.ethertype, hdr.encaps);
        scion_header_parser.apply(packet, hdr.scion, meta);
        transition accept;
    }
}


#endif