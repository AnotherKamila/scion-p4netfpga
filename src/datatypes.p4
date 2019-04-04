// types and metadata definitions
#ifndef SC__SRC__DATATYPES_P4_
#define SC__SRC__DATATYPES_P4_


#include <scion/errors.p4>

// MUST be 256 bits for NetFPGA
struct digest_data_t {
    ERROR   error_flag;
    bit<64> debug1;
    bit<64> debug2;

    // these are copied from sume_metadata_t
    bit<16> dma_q_size; // measured in 32-byte words
    bit<16> nf3_q_size; // measured in 32-byte words
    bit<16> nf2_q_size; // measured in 32-byte words
    bit<16> nf1_q_size; // measured in 32-byte words
    bit<16> nf0_q_size; // measured in 32-byte words

    bit<16> unused;
}


#endif