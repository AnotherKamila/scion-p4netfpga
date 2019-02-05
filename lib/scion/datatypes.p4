// Flat data types used in SCION: addresses, tags, etc.
#ifndef SC_LIB_SCION_DATATYPES_P4_
#define SC_LIB_SCION_DATATYPES_P4_


typedef bit<16> scion_isd;
typedef bit<48> scion_as;
typedef bit<6>  scion_host_addr_type_t;
typedef bit<16> scion_svc_addr_t;

typedef bit<16> packet_size_t; // in bytes => max len 64kB


#endif