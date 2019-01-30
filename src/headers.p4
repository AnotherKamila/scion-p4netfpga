#ifdef SC_SRC_HEADERS_P4_
#define SC_SRC_HEADERS_P4_


struct headers_t { 
    ethernet_h ethernet; 
    scion_encapsulation_t scion_encapsulation;
    scion_common_t scion_common;
}

struct user_metadata_t {
    scion_metadata_t scion;
}

// MUST be 256 bits for NetFPGA
struct digest_data_t {
    bit<256>  unused;
}


#endif