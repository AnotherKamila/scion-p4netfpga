// Error types that indicate when something is wrong with the SCION packet

#ifndef SC_LIB_SCION_HEADERS_P4_
#define SC_LIB_SCION_HEADERS_P4_


error {
    NotScion,                 // This is not a SCION packet
    UnknownScionHostAddrType, // The address type in the SCION common header is unknown
};


#endif