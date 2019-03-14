#ifndef SC__LIB__COMPAT__MACROS_P4_
#define SC__LIB__COMPAT__MACROS_P4_


#include <core.p4>

// Reason: SDNet does not support variable-length things; see P4-SDNet p.8
#ifdef TARGET_SUPPORTS_HEADER_UNIONS
#define HEADER_UNION  header_union
#else
#define HEADER_UNION  struct
#endif

// Reason: SDNet does not support errors; see P4-SDNet p.8
#ifdef TARGET_SUPPORTS_VERIFY
#define ERROR(err)              verify(false, error.err); transition reject
#define ERROR2(err, save_dest)  verify(false, error.err); transition reject
#else
// assumes that "meta" is in current scope
#define ERROR(err)              meta.error_flag = UserError.err; transition reject
#define ERROR2(err, save_dest)  save_dest       = UserError.err; transition reject
#endif

// If we have packet_mod, we can actually skip parts of headers without losing
// them; otherwise we save them so that we can emit them.
// dest is expected to be a varbit type.
#ifdef TARGET_SUPPORTS_PACKET_MOD
#define PACKET_SKIP(pkt, size, save_dest) pkt.advance(size)
#else
#define PACKET_SKIP(pkt, size, save_dest) pkt.extract(save_dest, size)
#endif


#endif