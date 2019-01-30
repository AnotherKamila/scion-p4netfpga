#ifndef SC_LIB_SCION_HEADERS_P4_
#define SC_LIB_SCION_HEADERS_P4_


#include <common/headers.p4>


// TODO in an ideal world, these would be generated from the capnp
// (https://github.com/scionproto/scion/tree/master/proto)

const udp_port_t SCION_PORT = 50000;

struct scion_encapsulation_t {
    ipv4_h     ipv4;
    ipv6_h     ipv6;
    udp_h      udp;
}

header scion_common_h {
}

struct scion_metadata_t {
}


#endif