// table sizes, register widths, and such
#ifndef SC__SRC__SETTINGS_P4
#define SC__SRC__SETTINGS_P4

// Max *Ethernet* frame size (L2), in bits
#define MTU 16384

// compile with -DEBUG to turn on debugging ;-)
#ifdef EBUG
#define DEBUG true
#else
#define DEBUG false
#endif

#endif