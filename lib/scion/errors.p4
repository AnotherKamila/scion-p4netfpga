// Error data types.
// Currently incomplete!
// Error numbers don't match because SDNet does not support explicit enum values.
// SCION book section 15.6.3 / p. 365

#ifndef SC_LIB_SCION_ERRORS_P4_
#define SC_LIB_SCION_ERRORS_P4_

#ifdef TARGET_SUPPORTS_ERROR_TYPE
#define ERRTYPE(x) error.x
error {
#else
#define ERRTYPE(x) UserError.x
enum UserError {
#endif
    UserErrorNoError,

    // GENERAL
    L2Error,
    // COMMON HEADER
    BadVersion,
    BadHostAddrType, // NOT a SCION error: used to signal one of the following two
    BadDstType, // The destination address type in the SCION common header is unknown
    BadSrcType, // s/destination/source/
    InvalidOffset, // NOT a SCION error: used instead of the three following ones
    BadPktLen,
    BadINFOffset,
    BadHFOffset,
    // PATH
    PathRequired,
    BadMac,
    ExpiredHF,
    BadIf,
    RevokedIf,
    NonForwardHof,
    DeliveryFwdOnly,
    DeliveryNonLocal,
    // EXTENSION
    // SIBRA

    InternalError // This should never happen. If it happened, something somewhere went terribly wrong.
}

// Reason: SDNet does not support errors; see P4-SDNet p.8
#ifdef TARGET_SUPPORTS_VERIFY
#define ERROR(err)              verify(false, error.err); transition reject
#define ERROR2(err, save_dest)  verify(false, error.err); transition reject
#else
// assumes that "meta" is in current scope
#define ERROR(err)              meta.error_flag = UserError.err; transition reject
// this one doesn't
#define ERROR2(err, save_dest)  save_dest       = UserError.err; transition reject
#endif


#endif