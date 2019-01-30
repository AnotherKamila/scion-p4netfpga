#ifndef SC_LIB_COMMON_HEADERS_P4_
#define SC_LIB_COMMON_HEADERS_P4_


///// Ethernet ///////////////////////////////////////////////////////////////

typedef bit<48>  eth_addr_t;

header ethernet_h {
    eth_addr_t dst_addr;
    eth_addr_t src_addr;
    bit<16>    ethertype;
}

const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<16> ETHERTYPE_IPV6 = 0x86DD;


///// IP /////////////////////////////////////////////////////////////////////

// TODO options

typedef bit<32>  ipv4_addr_t;
typedef bit<128> ipv6_addr_t;

header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  tos;
    bit<16> total_len;
    bit<16> identification;
    bit<3>  flags;
    bit<13> frag_offset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header ipv6_h {
    bit<4>      version;
    bit<8>      traffic_class;
    bit<20>     flow_label;
    bit<16>     payload_length;
    bit<8>      next_header;
    bit<8>      hop_limit;
    ipv6_addr_t src_addr;
    ipv6_addr_t dst_addr;
}

const bit<8> PROTOCOL_UDP = 0x11;


///// UDP ////////////////////////////////////////////////////////////////////

typedef bit<16>  udp_port_t;

header udp_h {
    udp_port_t src_port;
    udp_port_t dst_port;
    bit<16>    len;
    bit<16>    checksum; // can be set to 0 if unused
}


#endif
