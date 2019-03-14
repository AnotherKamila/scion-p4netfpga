// SCION deparsers for use with the `packet_mod` feature.

// Use ScionModDeparser to do everything, or the deparsers for various
// components to deparse only some parts.

#ifndef SCION__MOD_DEPARSERS_P4_
#define SCION__MOD_DEPARSERS_P4_

// Crazy idea: use #define tricks to generate both the parser and this from the same file?

// Parses Ethernet and IP/UDP encapsulation (if present).
@Xilinx_MaxPacketRegion(MTU)
parser ScionEncapsulationModDeparser(packet_mod packet,
                                     in ethertype_t    ethertype,
                                     in scion_encaps_t encaps) {
    state start {
        transition select(ethertype) {
            ETHERTYPE_IPV4: deparse_ipv4;
            ETHERTYPE_IPV6: deparse_ipv6;
            // TODO non-encapsulated SCION, once we have an Ethertype:
            // ETHERTYPE_SCION: accept;
        } 
    }

    // TODO IP and UDP get more complex when OPTIONS happen, so this should go
    // into <common/deparsers.p4> instead
    state deparse_ipv4 { 
        // TODO options
        packet.update(encaps.ip.v4);
        transition select(encaps.ip.v4.protocol) {
            PROTOCOL_UDP: deparse_udp;
        }
    }

    state deparse_ipv6 { 
        // TODO extensions
        packet.update(encaps.ip.v6);
        transition select(encaps.ip.v6.next_hdr) {
            PROTOCOL_UDP: deparse_udp;
        }
    }

    state deparse_udp {
        packet.update(encaps.udp);
        transition accept;
    }
}

// @Xilinx_MaxPacketRegion(MTU)
// parser ScionHeaderModDeparser(packet_mod packet,
//                               in scion_header_t hdr) {

//     ScionCommonHeaderModDeparser()  common_header_deparser;
//     ScionAddressHeaderModDeparser() address_header_deparser;
//     // ScionPathParser()          path_parser;
//     // ScionExtensionsParser()    extensions_parser;

//     state start {
//         common_header_parser.apply(packet, hdr.common);
//         address_header_parser.apply(packet, hdr.common, hdr.addr, meta);
//         // TODO:
//         // path_parser.apply(packet, hdr.path, meta);
//         // extensions_parser.apply(packet, hdr, meta);

//         transition accept;
//     }
// }

// @Xilinx_MaxPacketRegion(MTU)
// parser ScionModDeparser(packet_mod pkt, in scion_all_headers_t hdr, in scion_metadata_t meta) {

//     ScionEncapsulationModDeparser() encaps_deparser;
//     // ScionHeaderModDeparser()        scion_header_deparser;

//     state start {
//         pkt.update(hdr.ethernet);
//         encaps_deparser.apply(pkt, hdr.ethernet.ethertype, hdr.encaps);
//         // scion_header_deparser.apply(packet, hdr.scion, meta);
//         transition accept;
//     }
// }


#endif