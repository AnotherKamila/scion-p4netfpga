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
    scion_host_addr_type_t dst_addr_type;
    scion_host_addr_type_t src_addr_type;
    bit<16>                total_len;
    bit<8>                 hdr_len;
    bit<8>                 curr_INF; // absolute offset to the info field (from beginning of SCION common header), in units of 8B
    bit<8>                 curr_HF;
    protocol_t             next_hdr;
}
// there will be a sizeof in the next P4...
const packet_size_t SCION_COMMON_H_SIZE = 8;

// header field masks to be used with packet_mod to only change some fields
const bit<32> SCION_COMMON_HDR_MASK_INF_HF = 32w0b00000110;


/// Address header

header scion_isdas_addr_h {
    scion_isd   isd;
    scion_as    as;
}
const packet_size_t SCION_ISDAS_ADDR_H_SIZE = 8; // here I *really* want sizeof :D

// Wrappers for host address data types.
// These must be headers because a header union may only contain headers, not
// flat types.
header scion_host_addr_ipv4_h { ipv4_addr_t      a; }
header scion_host_addr_ipv6_h { ipv6_addr_t      a; }
header scion_host_addr_svc_h  { scion_svc_addr_t a; }

// This has to be wrapped because packet.extract() only accepts headers.
#ifdef TARGET_SUPPORTS_VAR_LEN_PARSING
// SDNet refuses to compile anything with the slightest mention of varbit, so I have to hide it behind this guard.
header scion_addr_align_bits_h { varbit<(8*6)> a; }
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


/// Path header

header scion_inf_h {
    bit<8>            flags;
    scion_timestamp_t timestamp;
    scion_isd         isd;
    bit<8>            nhops;
}

header scion_hf_h {
    bit<8>    flags;
    bit<8>    expiry;
    bit<12>   ingress_if;
    bit<12>   egress_if;
    bit<24>   mac;
}
const bit<8> SCION_HF_FLAG_UP = 0; // TODO
const bit<8> SCION_HF_FLAG_XOVER = 0; // TODO
const bit<8> SCION_HF_IMMUTABLE_FLAGS = 0x0; // SCION book, p. 162

struct scion_path_header_t {
    scion_inf_h current_inf;
    scion_hf_h  prev_hf;     // needed for MAC verification
    scion_hf_h  current_hf;
}

/// Top-level SCION header

struct scion_header_t {
    scion_common_h      common;
    scion_addr_header_t addr;
    scion_path_header_t path;
}

struct scion_all_headers_t {
    ethernet_h     ethernet; 
    scion_encaps_t encaps;
    scion_header_t scion;
}


#endif