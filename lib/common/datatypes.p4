// Flat data types used in common Internet protocols: addresses, ports, etc.
#ifndef SC_LIB_COMMON_DATATYPES_P4_
#define SC_LIB_COMMON_DATATYPES_P4_


/// Ethernet
typedef bit<48> eth_addr_t;
typedef bit<16> ethertype_t;

/// IP
typedef bit<32>  ipv4_addr_t;
typedef bit<128> ipv6_addr_t;
typedef bit<8>   protocol_t;

/// UDP
typedef bit<16>  udp_port_t;


#endif
