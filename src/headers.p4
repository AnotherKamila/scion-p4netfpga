/* packet headers, plus the metadata struct */
#ifndef HEADERS_P4
#define HEADERS_P4


typedef bit<48>  eth_addr_t; 
typedef bit<32>  ipv4_addr_t;
typedef bit<128> ipv6_addr_t;
typedef bit<16>  udp_port_t;

const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<16> ETHERTYPE_IPV6 = 0x86DD;

header ethernet_h { 
    eth_addr_t dst_addr; 
    eth_addr_t src_addr; 
    bit<16>    ethertype;
}

header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  tos; 
    bit<16> total_len; 
    bit<16> identification; 
    bit<3>  flags;
    bit<13> frag_offset; 
    bit<8> ttl;
    bit<8> protocol; 
    bit<16> hdr_checksum; 
    ipv4_addr_t src_addr; 
    ipv4_addr_t dst_addr;
}

/* https://en.wikipedia.org/wiki/IPv6_packet */
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

struct headers_t { 
    ethernet_h ethernet; 
    ipv4_h     ipv4;
    ipv6_h     ipv6;
}

struct user_metadata_t {
    bit<8>  unused;
}

// MUST be 256 bits!
struct digest_data_t {
    bit<256>  unused;
}


#endif