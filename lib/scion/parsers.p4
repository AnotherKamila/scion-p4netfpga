// SCION parsers.
//
// Use ScionTopParser to do everything, or the parsers for various
// components to parse only some parts.

#ifndef SC__LIB__SCION__PARSERS_P4_
#define SC__LIB__SCION__PARSERS_P4_


// TODO figure out whether SCION is always encapsulated and re-structure
// accordingly.

// TODO an option here would be to make this parametrised with
// bool allow_non_scion;
// then we could have a default: (allow_non_scion ? accept : reject) thing

#include "headers.p4"

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionEncapsulationParser(packet_in packet,
                                out headers_t hdr,
                                out scion_metadata_t meta) {

    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ethertype) {
            ETHERTYPE_IPV4: parse_ipv4;
            ETHERTYPE_IPV6: parse_ipv6;
            // TODO non-encapsulated SCION, if it exists
            // if nothing matched, an error will be set and should be handled
        } 
    }

    state parse_ipv4 { 
        // TODO options
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            PROTOCOL_UDP: parse_udp;
            // if nothing matched, an error will be set and should be handled
        }
    }

    state parse_ipv6 { 
        // TODO extensions
        packet.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_header) {
            PROTOCOL_UDP: parse_udp;
            // if nothing matched, an error will be set and should be handled
        }
    }

    state parse_udp {
        packet.extract(hdr.udp);
        // TODO don't forget UDP checksum!
        //  1. find out if it's possible to put it into the parser
        //  2. find out what's faster
        transition select(hdr.udp.dst_port) {
            SCION_PORT: accept;
            // if nothing matched, an error will be set and should be handled
        }
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionCommonHeaderParser(packet_in packet, 
                               out headers_t hdr,
                               out scion_metadata_t meta) {

    state start {
        packet.extract(hdr.scion_common_h);
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionAddressParser(packet_in packet, 
                          out headers_t hdr,
                          out scion_metadata_t meta) {

    state start {
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionPathParser(packet_in packet, 
                       out headers_t hdr,
                       out scion_metadata_t meta) {

    state start {
        transition accept;
    }
}

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionExtensionsParser(packet_in packet, 
                             out headers_t hdr,
                             out scion_metadata_t meta) {

    state start {
        transition accept;
    }
}


@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionParser(packet_in packet, 
                   out headers_t hdr,
                   out scion_metadata_t meta) {

    ScionEncapsulationParser() encapsulation_parser;
    ScionCommonHeaderParser()  common_header_parser;
    ScionAddressParser()       address_parser;
    ScionPathParser()          path_parser;
    ScionExtensionsParser()    extensions_parser;

    state start {
        encapsulation_parser.apply(packet, hdr, meta);
        common_header_parser.apply(packet, hdr, meta);
        address_parser.apply(      packet, hdr, meta);
        path_parser.apply(         packet, hdr, meta);
        extensions_parser.apply(   packet, hdr, meta);

        transition accept;
    }
}


#endif