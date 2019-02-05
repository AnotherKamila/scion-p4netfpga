#ifndef SC_LIB_SCION_HEADERS_P4_
#define SC_LIB_SCION_HEADERS_P4_


#include <common/datatypes.p4>
#include <common/headers.p4>
#include <scion/datatypes.p4>


/// Encapsulation

struct scion_encaps_t {
    ip_h       ip;
    udp_h      udp;
}


/// Common header

header scion_common_h {
    bit<4>                 version;
    scion_host_addr_type_t dst_type;
    scion_host_addr_type_t src_type;
    bit<16>                total_len;
    bit<8>                 hdr_len;
    bit<8>                 curr_INF;
    bit<8>                 curr_HF;
    protocol_t             next_hdr;
}


/// Address header

header scion_isdas_addr_h {
    scion_isd   isd;
    scion_as    as;
}

// Wrappers for host address data types.
// These must be headers because a header union may only contain headers, not
// flat types.
header scion_host_addr_ipv4_h { ipv4_addr_t      a; }
header scion_host_addr_ipv6_h { ipv6_addr_t      a; }
header scion_host_addr_svc_h  { scion_svc_addr_t a; }

// This has to be wrapped because packet.extract() only accepts headers.
#ifndef TARGET_SUPPORTS_PACKET_MOD
// SDNet refuses to compile anything with the slightest mention of varbit, so I have to hide it behind this guard.
header scion_addr_align_bits_h { varbit<8*6> a; }
#endif

HEADER_UNION scion_host_addr_h {
    scion_host_addr_ipv4_h ipv4;
    scion_host_addr_ipv6_h ipv6;
    scion_host_addr_svc_h  service;
}


struct scion_addr_header_t {
    scion_isdas_addr_h dst_isdas;
    scion_isdas_addr_h src_isdas;
    scion_host_addr_h  dst_host;
    scion_host_addr_h  src_host;

// addr_header must always be a multiple of 8 bytes, so if we don't have
// packet_mod, we need to put the right number of bytes somewhere
#ifndef TARGET_SUPPORTS_PACKET_MOD
    scion_addr_align_bits_h align_bits;
#endif
}


/// Top-level SCION header

struct scion_header_t {
    scion_common_h      common;
    scion_addr_header_t addr;
    // TODO
}

struct scion_all_headers_t {
    ethernet_h     ethernet; 
    scion_encaps_t encaps;
    scion_header_t scion;
}


/// SCION metadata
struct scion_metadata_t {
    scion_host_addr_type_t dst_addr_type;
    scion_host_addr_type_t src_addr_type;
}


#endif