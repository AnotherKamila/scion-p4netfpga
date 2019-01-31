// Common Internet constants: ethertype numbers, protocol numbers, etc.
#ifndef SC_LIB_COMMON_CONSTANTS_P4_
#define SC_LIB_COMMON_CONSTANTS_P4_


#include <common/datatypes.p4>

/// Ethernet
const ethertype_t ETHERTYPE_IPV4 = 0x0800;
const ethertype_t ETHERTYPE_IPV6 = 0x86DD;

/// IP
const protocol_t PROTOCOL_UDP = 0x11;


#endif
