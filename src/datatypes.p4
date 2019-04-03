// types and metadata definitions
#ifndef SC__SRC__DATATYPES_P4_
#define SC__SRC__DATATYPES_P4_


// MUST be 256 bits for NetFPGA
struct digest_data_t {
    ERROR   error_flag;
    bit<64> debug1;
    bit<64> debug2;
    bit<96> unused;
}


#endif