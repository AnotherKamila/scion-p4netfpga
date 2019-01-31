// Common Internet parsers.

#ifndef SC__LIB__COMMON__PARSERS_P4_
#define SC__LIB__COMMON__PARSERS_P4_


#include <common/headers.p4>

// Ethernet is just packet.extract(hdr.ethernet), so that's not worth having a
// separate parser for, just use the header defined in ./headers.p4.


#endif