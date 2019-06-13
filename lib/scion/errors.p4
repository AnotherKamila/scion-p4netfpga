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
    NotSCION,
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

    // INTERNAL
    // Not implemented -- these are used to indicate that the packet should be
    // passed to CPU, because we can't handle it in hardware (yet?)
    NotImpl_UnsupportedFlags,
    NotImpl_PathTooLong,
    NotImpl_UnsupportedExtension,
    InternalError_UnconfiguredIFID, // The IFID looks valid, but we don't have overlay/L2 info about the peer
    InternalError // This should never happen. If it happened, something somewhere went terribly wrong.
}


#endif