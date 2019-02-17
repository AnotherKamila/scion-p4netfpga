// SCION deparsers.

// Use ScionDeparser to do everything, or the deparsers for various
// components to deparse only some parts.


#ifndef SCION__DEPARSERS_P4_
#define SCION__DEPARSERS_P4_


// TODO(modularity) split this out into several deparsers:
//  - ScionEncapsulationDeparser
//  - ScionCommonHeaderDeparser
//  - ScionPathDeparser
//  - ScionPathSegmentDeparser

#include <scion/headers.p4>

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control ScionDeparser(packet_out packet,
                      in scion_all_headers_t hdr) {
    apply {
        packet.emit(hdr.ethernet); 
        // packet.emit(hdr.encaps.ip.v4); // - only one will be valid
        // packet.emit(hdr.encaps.ip.v6); // /
        // packet.emit(hdr.encaps.udp);
    }
}

#ifdef TARGET_SUPPORTS_PACKET_MOD
// TODO remove:
#ifndef TARGET_SUPPORTS_SUCKING_AND_IM_LYING_ABOUT_PACKET_MOD

@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
parser ScionModDeparser(packet_mod pkt, in scion_all_headers_t hdr) {
    state start{
        pkt.update(hdr.ethernet);
        transition accept;
    }
}

#endif
#endif


#endif