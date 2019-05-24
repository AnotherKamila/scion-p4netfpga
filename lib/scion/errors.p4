// Error data types.
// Currently incomplete!
// Error numbers don't match because SDNet does not support explicit enum values.
// SCION book section 15.6.3 / p. 365

#ifndef SC_LIB_SCION_ERRORS_P4_
#define SC_LIB_SCION_ERRORS_P4_

#ifdef TARGET_SUPPORTS_ERROR_TYPE
#define ERROR error
error {
#else
#define ERROR UserError
enum UserError {
    NoError,
#endif
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
    BadMAC,
    ExpiredHF,
    BadIf,
    RevokedIf,
    NonForwardHof,
    DeliveryFwdOnly,
    DeliveryNonLocal,
    // EXTENSION
    // SIBRA

    // Not implemented -- these are used to indicate that the packet should be
    // passed to CPU, because we can't handle it in hardware (yet?)
    NotImpl_UnsupportedFlags,
    NotImpl_PathTooLong,
    NotImpl_UnsupportedExtension,
    InternalError // This should never happen. If it happened, something somewhere went terribly wrong.
}

// Reason: SDNet does not support errors; see P4-SDNet p.8
#ifdef TARGET_SUPPORTS_VERIFY
#define PARSE_ERROR(e)              verify(false, ERROR.e)
#define PARSE_ERROR2(e, save_dest)  verify(false, ERROR.e)
#else
// assumes that "err" is in current scope
#define PARSE_ERROR(e)              err.error_flag = ERROR.e; transition reject
// this one doesn't
#define PARSE_ERROR2(e, save_dest)  save_dest      = ERROR.e; transition reject
#endif


#endif