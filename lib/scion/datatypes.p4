// Flat data types used in SCION: addresses, tags, etc.
#ifndef SC_LIB_SCION_DATATYPES_P4_
#define SC_LIB_SCION_DATATYPES_P4_


/// Type aliases

typedef bit<16> scion_isd;
typedef bit<48> scion_as;
typedef bit<6>  scion_host_addr_type_t;
typedef bit<16> scion_svc_addr_t;

typedef bit<16> packet_size_t; // in bytes => max len 64kB

/// Errors

#ifdef TARGET_SUPPORTS_ERROR_TYPE
error {
#else
enum UserError { // hard-coded in ../compat/macros.p4
#endif
    UserErrorNoError,
    NotScion, // Wrong ethertype or unknown encapsulation
    InvalidOffset, // INF or HF pointer go beyond header length; or INF >= HF
    UnknownHostAddrType, // The address type in the SCION common header is unknown
    InternalError, // This should never happen. If it happened, something somewhere went terribly wrong.
    Iamherebecausenotrailingcommassuck // no trailing commas suck
}

/// SCION metadata
struct scion_metadata_t {
#ifndef TARGET_SUPPORTS_VERIFY
    UserError error_flag; // otherwise verify() is used
#endif
    bit<64> debug1; // used as a debug signal
    bit<64> debug2; // used as a debug signal
}


#endif