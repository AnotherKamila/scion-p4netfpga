// A wall clock implementation that relies on the control plane regularly writing the current time

#ifndef SC_LIB_NETFPGA_WALLCLOCK_P4_
#define SC_LIB_NETFPGA_WALLCLOCK_P4_


#include <sume_switch.p4>
#include <netfpga/regs.p4>


#define WALL_CLOCK_DEPTH 1
#define WALL_CLOCK_WIDTH 32


@brief("Register used for keeping wall time.")
@description("The control plane is expected to frequently update this register over DMA.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(WALL_CLOCK_DEPTH)
extern void wall_clock_reg_rw(in bit<WALL_CLOCK_DEPTH> index,
                              in bit<WALL_CLOCK_WIDTH> newVal,
                              in bit<8> opCode,
                              out bit<WALL_CLOCK_WIDTH> result);

@brief("Read wall clock time and store it in the curtime parameter")
control ReadWallClock(out bit<WALL_CLOCK_WIDTH> curtime) {
    // has to be a control, because SDNet does not support functions
    apply {
        wall_clock_reg_rw(0, 0, REG_READ, curtime);
    }
}


#endif