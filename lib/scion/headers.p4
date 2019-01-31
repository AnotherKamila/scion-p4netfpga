#ifndef SC_LIB_SCION_HEADERS_P4_
#define SC_LIB_SCION_HEADERS_P4_


#include <common/datatypes.p4>
#include <common/headers.p4>
#include <scion/datatypes.p4>


/// Encapsulation

struct scion_encaps_h {
    ip_h       ip;
    udp_h      udp;
}


/// Common header

header scion_common_h {
    bit<4>             version;
    scion_host_addr_t  dst_type;
    scion_host_addr_t  src_type;
    bit<16>            total_len;
    bit<8>             hdr_len;
    bit<8>             curr_INF;
    bit<8>             curr_HF;
    bit<8>             next_hdr;
}


/// Address header

header scion_isdas_h {
    scion_isd   isd;
    scion_as    as;
}

// Wrappers for host address data types.
// These must be headers because a header union may only contain headers, not
// flat types.
header scion_host_addr_ipv4_h { ipv4_addr_t      a; }
header scion_host_addr_ipv6_h { ipv6_addr_t      a; }
header scion_host_addr_svc_h  { scion_svc_addr_t a; }

header_union scion_host_addr_h {
    scion_host_addr_ipv4_h ipv4;
    scion_host_addr_ipv6_h ipv6;
    scion_host_addr_svc_h  service;
}


struct scion_addr_header_t {
    scion_isdas_addr_h dst_isdas;
    scion_isdas_addr_h src_isdas;
    scion_host_addr_h  dst_host;
    scion_host_addr_h  src_host;
}


/// Top-level SCION header

struct scion_header_t {
    scion_common_h      common;
    scion_addr_header_t addr;
    // TODO
}

struct scion_all_headers_t {
    ethernet_h ethernet; 
    scion_encapsulation_t encaps;
    scion_header_t scion;
}


/// SCION metadata
struct scion_metadata_t {
    scion_host_addr_type_t dst_addr_type;
    scion_host_addr_type_t src_addr_type;
}


#endif