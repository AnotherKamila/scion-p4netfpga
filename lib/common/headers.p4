#ifndef SC_LIB_COMMON_HEADERS_P4_
#define SC_LIB_COMMON_HEADERS_P4_


#include <compat/macros.p4>
#include <common/datatypes.p4>

/// Ethernet

header ethernet_h {
    eth_addr_t dst_addr;
    eth_addr_t src_addr;
    bit<16>    ethertype;
}


/// IP

header ipv4_h {
    bit<4>      version;
    bit<4>      ihl;
    bit<8>      tos;
    bit<16>     total_len;
    bit<16>     identification;
    bit<3>      flags;
    bit<13>     frag_offset;
    bit<8>      ttl;
    protocol_t  protocol;
    bit<16>     hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
    // TODO options
}

header ipv6_h {
    bit<4>      version;
    bit<8>      traffic_class;
    bit<20>     flow_label;
    bit<16>     payload_length;
    protocol_t  next_hdr;
    bit<8>      hop_limit;
    ipv6_addr_t src_addr;
    ipv6_addr_t dst_addr;
    // TODO extensions
}

HEADER_UNION ip_h {
    ipv4_h v4;
    ipv6_h v6;
}


/// UDP

header udp_h {
    udp_port_t src_port;
    udp_port_t dst_port;
    bit<16>    len;
    bit<16>    checksum; // can be set to 0 if unused
}


#endif
