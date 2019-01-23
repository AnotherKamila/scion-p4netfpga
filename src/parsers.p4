/* parser and deparser */
#ifndef PARSERS_P4
#define PARSERS_P4


#include "headers.p4"

// this portability thing may have been a terrible idea
#ifdef PARSER_HAS_REJECT
#define REJECT_IF_CAN reject
#else
#define REJECT_IF_CAN accept
#endif


///////// PARSER /////////////////////////////////////////////////////////////

// TODO figure out whether SCION is always encapsulated and re-structure
// accordingly
@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser MaybeScionTopParser(packet_in packet, 
                           out headers_t hdr) {

    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ethertype) {
            ETHERTYPE_IPV4: parse_ipv4;
            ETHERTYPE_IPV6: parse_ipv6;
            // TODO non-encapsulated SCION
            default: REJECT_IF_CAN;
        } 
    }

    state parse_ipv4 { 
        packet.extract(hdr.ipv4);
        transition accept; 
    }

    state parse_ipv6 { 
        packet.extract(hdr.ipv6);
        transition accept; 
    }
}


///////// DEPARSER ///////////////////////////////////////////////////////////

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control ScionTopDeparser(packet_out packet,
                         in headers_t hdr) {
    apply {
        packet.emit(hdr.ethernet); 
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
    }
}


#endif