// table sizes, register widths, and such
#ifndef SC__SRC__SETTINGS_P4
#define SC__SRC__SETTINGS_P4

// Max *Ethernet* frame size (L2), in bits
#define MTU 16384

// compile with -DEBUG to turn on debugging ;-)
#ifdef EBUG
#define DEBUG true
// needed because if sometimes does weird things with SDNet
#define IFDBG(x) x
#else
#define DEBUG false
#define IFDBG(x)
#endif

#endif