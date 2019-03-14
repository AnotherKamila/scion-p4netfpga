// types and metadata definitions
#ifndef SC__SRC__DATATYPES_P4_
#define SC__SRC__DATATYPES_P4_


struct user_metadata_t {
    scion_metadata_t scion;
}

// MUST be 256 bits for NetFPGA
struct digest_data_t {
    UserError error_flag;
    bit<32>   marker1;
    bit<64>   debug1;
    bit<32>   marker2;
    bit<64>   debug2;
    bit<32>   marker3;
    bit<32>   unused;
}


#endif