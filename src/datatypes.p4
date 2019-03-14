// types and metadata definitions
#ifndef SC__SRC__DATATYPES_P4_
#define SC__SRC__DATATYPES_P4_


struct user_metadata_t {
    scion_metadata_t scion;
}

// MUST be 256 bits for NetFPGA
struct digest_data_t {
    bit<32>   debug; // 32 bits of debug signal should be enough for everyone
    bit<224>  unused;
}


#endif