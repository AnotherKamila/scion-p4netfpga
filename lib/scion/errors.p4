// Error types that indicate when something is wrong with the SCION packet

#ifndef SC_LIB_SCION_HEADERS_P4_
#define SC_LIB_SCION_HEADERS_P4_


error {
    notScion,                 // This is not a SCION packet
    unknownScionHostAddrType, // The address type in the SCION common header is unknown
};


#endif