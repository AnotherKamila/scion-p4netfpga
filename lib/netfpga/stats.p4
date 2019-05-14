// Stats/metrics for the NetFPGA, to be read from the control plane

/*
NetFPGA only supports 1 write into the same register (can't call the same extern multiple times). Therefore, I have to create multiple registers -- I have to split everything that can be updated in the same packet's pipeline.

These are the splits I made here:

- receive packet counts, depth 3 (element per interface)
- transmit packet counts, depth 3 (element per interface)
- queue sizes: for simplicity, I only update the queue size of "this" packet's
  interface here; should be good enough IRL because if I don't see any packets,
  the size likely got to and stayed at 0

*/

#ifndef SC_LIB_NETFPGA_STATS_P4_
#define SC_LIB_NETFPGA_STATS_P4_


#include <sume_switch.p4>
#include <netfpga/regs.p4>


#define STATS_REGS_DEPTH 3
#define STATS_REGS_WIDTH 32


@brief("Register used for reporting queue sizes.")
@description("The control plane is expected to read this register over DMA. \
Note that this register is NOT fully updated on every round: we only update \
the interface for which we just got the packet. This should be approximately \
good enough, hopefully. \
We could update everything on every round, but it would be a little bit more \
complicated. \
Note also that the DMA queue is reported at index 1 and the other odd indices \
are unused.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(STATS_REGS_DEPTH)
extern void stat_queue_sizes_reg_rw(in bit<STATS_REGS_DEPTH> index,
                                    in bit<STATS_REGS_WIDTH> newVal,
                                    in bit<8> opCode,
                                    out bit<STATS_REGS_WIDTH> result);

@brief("Register used for reporting total received packet count.")
@description("The control plane is expected to read this register over DMA.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(STATS_REGS_DEPTH)
extern void stat_recv_pkt_cnt_reg_raw(in bit<STATS_REGS_DEPTH> index,
                                      in bit<STATS_REGS_WIDTH> newVal,
                                      in bit<STATS_REGS_WIDTH> incVal,
                                      in bit<8> opCode,
                                      out bit<STATS_REGS_WIDTH> result);

@brief("Register used for reporting total sent packet count.")
@description("The control plane is expected to read this register over DMA.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(STATS_REGS_DEPTH)
extern void stat_send_pkt_cnt_reg_raw(in bit<STATS_REGS_DEPTH> index,
                                      in bit<STATS_REGS_WIDTH> newVal,
                                      in bit<STATS_REGS_WIDTH> incVal,
                                      in bit<8> opCode,
                                      out bit<STATS_REGS_WIDTH> result);

control GetPortIndex(in port_t port, out bit<STATS_REGS_DEPTH> index) {
    // has to be a control, because SDNet does not support ifs in actions
    // there's no switch statement in P4 :-/
    apply {
        if (port == 0b1) {
            index = 0;
        } else if (port == 0b10) {
            index = 1;
        } else if (port == 0b100) {
            index = 2;
        } else if (port == 0b1000) {
            index = 3;
        } else if (port == 0b10000) {
            index = 4;
        } else if (port == 0b100000) {
            index = 5;
        } else if (port == 0b1000000) {
            index = 6;
        } else {
            index = 7;
        }
    }
}

control GetThisQueue(in  port_t                port,
                     in  sume_metadata_t       sume,
                     out bit<STATS_REGS_DEPTH> index,
                     out bit<16>               q_size) {
    apply {
        if (port == 0b1) {
            index = 0;
            q_size = sume.nf0_q_size;
        } else if (port == 0b100) {
            index = 2;
            q_size = sume.nf1_q_size;
        } else if (port == 0b10000) {
            index = 4;
            q_size = sume.nf2_q_size;
        } else if (port == 0b1000000) {
            index = 6;
            q_size = sume.nf3_q_size;
        } else {
            index = 1;
            q_size = sume.dma_q_size;
        }
    }
}

control ExposeStats(in sume_metadata_t sume) {
    bit<STATS_REGS_DEPTH> port_index;
    bit<16> q_size;
    bit<STATS_REGS_WIDTH> notneeded; // SDNet does not support using _ with an extern

    apply {
        // increment received
        GetPortIndex.apply(sume.src_port, port_index);
        stat_recv_pkt_cnt_reg_raw(port_index, 0, 1, REG_ADD, notneeded);
        // increment sent
        GetPortIndex.apply(sume.dst_port, port_index);
        stat_send_pkt_cnt_reg_raw(port_index, 0, 1, REG_ADD, notneeded);
        // copy queue size
        GetThisQueue.apply(sume.src_port, sume, port_index, q_size);
        stat_queue_sizes_reg_rw(port_index, 16w0 ++ q_size, REG_WRITE, notneeded);
    }
}

#endif