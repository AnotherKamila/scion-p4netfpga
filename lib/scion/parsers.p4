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

#ifndef SC__LIB__SCION__PARSERS_P4_
#define SC__LIB__SCION__PARSERS_P4_


#include <scion/datatypes.p4>
#include <scion/errors.p4>
#include <scion/headers.p4>

// Parses Ethernet and IP/UDP encapsulation (if present).
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionEncapsulationParser(packet_in packet,
                                out   ethernet_h     ethernet,
                                out   scion_encaps_t encaps) {
    state start {
        packet.extract(ethernet);
        transition select(ethernet.ethertype) {
            ETHERTYPE_IPV4: parse_ipv4;
            ETHERTYPE_IPV6: parse_ipv6;
            // TODO non-encapsulated SCION, once we have an Ethertype:
            // ETHERTYPE_SCION: accept;
            default: verify(false, error.notScion);
        } 
    }

    // TODO IP and UDP get more complex when OPTIONS happen, so this should go
    // into <common/parsers.p4> instead
    state parse_ipv4 { 
        // TODO options
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            PROTOCOL_UDP: parse_udp;
            default: verify(false, error.notScion);
        }
    }

    state parse_ipv6 { 
        // TODO extensions
        packet.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_header) {
            PROTOCOL_UDP: parse_udp;
            default: verify(false, error.notScion);
        }
    }

    state parse_udp {
        packet.extract(hdr.udp);
        // TODO don't forget UDP checksum!
        //  1. find out if it's possible to put it into the parser
        //  2. find out what's faster
        transition select(hdr.udp.dst_port) {
            SCION_PORT: accept;
            default: verify(false, error.notScion);
        }
    }
}

// Parses the SCION Common Header
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionCommonHeaderParser(packet_in packet, 
                               out   scion_common_h   hdr,
                               inout scion_metadata_t meta) {
    state start {
        packet.extract(hdr.common);
        meta.dst_addr_type = hdr.common.dst_type;
        meta.src_addr_type = hdr.common.src_type;
        transition accept;
    }
}

// Parses the given type of SCION host address (IPv4, IPv6 or Service).
// Used inside ScionAddressHeaderParser.
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionHostAddressParser(packet_in packet,
                              in  scion_host_addr_type_t type,
                              out scion_host_addr_h      hdr) {
    state start {
        transition select(type) {
            SCION_HOST_ADDR_IPV4: ipv4;
            SCION_HOST_ADDR_IPV6: ipv6;
            SCION_HOST_ADDR_SVC:  svc;
            default: verify(false, error.unknownScionHostAddrType);
        }
    }

    state ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

    state ipv6 {
        packet.extract(hdr.ipv6);
        transition accept;
    }

    state svc {
        packet.extract(hdr.service);
        transition accept;
    }
}

// Parses the SCION Address Header
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionAddressHeaderParser(packet_in packet, 
                                out scion_addr_header_t hdr,
                                in scion_metadata_t     meta) {

    ScionHostAddressParser() dst_host_parser;
    ScionHostAddressParser() src_host_parser;

    state start {
        packet.extract(hdr.addr.dst_isdas);
        packet.extract(hdr.addr.src_isdas);
        dst_host_parser.apply(packet, hdr.dst_host, meta.dst_addr_t);
        src_host_parser.apply(packet, hdr.src_host, meta.src_addr_t);
        transition accept;
    }

}

// TODO
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionPathParser(packet_in packet, 
                       out scion_headers_t hdr,
                       out scion_metadata_t meta) {
    state start {
        transition accept;
    }
}

// TODO
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionExtensionsParser(packet_in packet, 
                             out scion_headers_t hdr,
                             out scion_metadata_t meta) {

    state start {
        transition accept;
    }
}

// Parses the SCION header (NOT including encapsulation).
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionHeaderParser(packet_in packet, 
                         out scion_headers_t hdr,
                         out scion_metadata_t meta) {

    ScionCommonHeaderParser()  common_header_parser;
    ScionAddressHeaderParser() address_header_parser;
    ScionPathParser()          path_parser;
    ScionExtensionsParser()    extensions_parser;

    state start {
        common_header_parser.apply(packet, hdr.common, meta);
        address_header_parser.apply(packet, hdr.addr, meta);
        // TODO:
        // path_parser.apply(packet, hdr, meta);
        // extensions_parser.apply(packet, hdr, meta);

        transition accept;
    }
}

// As stated above, this expects the full packet including Ethernet.
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionParser(packet_in packet, 
                   out scion_all_headers_t hdr,
                   out scion_metadata_t meta) {

    ScionEncapsulationParser() encapsulation_parser;
    ScionHeaderParser()        scion_header_parser;

    state start {
        encapsulation_parser.apply(packet, hdr.ethernet, hdr.encaps);
        scion_header_parser.apply(packet, hdr.scion)
        transition accept;
    }
}


#endif