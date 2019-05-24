// Controls that handle passing packets through to/from the CPU

#ifndef SC_LIB_NETFPGA_PASSTHROUGH_TO_CPU_P4_
#define SC_LIB_NETFPGA_PASSTHROUGH_TO_CPU_P4_


#include <sume_switch.p4>

#define IS_CPU_PORT(p)  ((p) == 0b1 || (p) == 0b100 || (p) == 0b10000 || (p) == 0b1000000)

// You must check for IS_CPU_PORT(sume.src_port) before using these!
// sume: sume_metadata_t
#define PASS_FROM_CPU(sume)  sume.dst_port = sume.src_port << 1
#define PASS_TO_CPU(sume)    sume.dst_port = sume.src_port >> 1


#endif