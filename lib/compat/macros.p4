#ifndef SC__LIB__COMPAT__MACROS_P4_
#define SC__LIB__COMPAT__MACROS_P4_


#include <core.p4>

// Reason: SDNet does not support variable-length things; see P4-SDNet p.8
#ifdef TARGET_SUPPORTS_HEADER_UNIONS
#define HEADER_UNION  header_union
#else
#define HEADER_UNION  struct
#endif


#endif