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
                      in scion_headers_t hdr) {
    apply {
        packet.emit(hdr.ethernet); 
        packet.emit(hdr.encaps.ipv4);
        packet.emit(hdr.encaps.ipv6);
        packet.emit(hdr.encaps.udp);
    }
}


#endif