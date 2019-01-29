// Packet headers, plus the metadata struct.

// TODO split this into multiple files

#ifndef HEADERS_P4
#define HEADERS_P4


///// Ethernet /////

typedef bit<48>  eth_addr_t; 

header ethernet_h { 
    eth_addr_t dst_addr; 
    eth_addr_t src_addr; 
    bit<16>    ethertype;
}

const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<16> ETHERTYPE_IPV6 = 0x86DD;


///// IP /////

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


///// UDP /////

typedef bit<16>  udp_port_t;

header udp_h {
    udp_port_t src_port;
    udp_port_t dst_port;
    bit<16>    len;
    bit<16>    checksum; // can be set to 0 if unused
}


///// SCION (TODO split me out) /////

const udp_port_t SCION_PORT = 50000;

struct scion_encapsulation_t {
    ipv4_h     ipv4;
    ipv6_h     ipv6;
    udp_h      udp;
}

struct scion_metadata_t {
}

///// local /////

struct headers_t { 
    ethernet_h ethernet; 
    scion_encapsulation_t scion_encapsulation;
    scion_common_t scion_common;
}

struct user_metadata_t {
    scion_metadata_t scion;
}

// MUST be 256 bits!
struct digest_data_t {
    bit<256>  unused;
}


#endif