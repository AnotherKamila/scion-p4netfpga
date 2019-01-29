// SCION deparsers.

// Use ScionTopDeparser to do everything, or the deparsers for various
// components to deparse only some parts.


#ifndef SCION__DEPARSERS_P4_
#define SCION__DEPARSERS_P4_


// TODO(modularity) split this out into several deparsers:
//  - ScionEncapsulationDeparser
//  - ScionCommonHeaderDeparser
//  - ScionPathDeparser
//  - ScionPathSegmentDeparser
// Also: think about moving this into a different directory than main, let's say
// lib/scion or something.

#include "headers.p4"


@Xilinx_MaxPacketRegion(MAX_PACKET_REGION)
control ScionDeparser(packet_out packet,
                      in headers_t hdr) {
    apply {
        packet.emit(hdr.ethernet); 
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
    }
}


#endif