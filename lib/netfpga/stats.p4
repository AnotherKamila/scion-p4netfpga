// Stats/metrics for the NetFPGA, to be read from the control plane

/*
NetFPGA only supports 1 write into the same register (can't call the same extern multiple times). Therefore, I have to create multiple registers -- I have to split everything that can be updated in the same packet's pipeline.

These are the splits I made here:

- receive packet counts, depth 3 (element per interface)
- transmit packet counts, depth 3 (element per interface)
- queue sizes: I need to update all of them, so I'll have a one-element register with all the queue sizes concatenated, so I can do it in one write

*/

#ifndef SC_LIB_NETFPGA_STATS_P4_
#define SC_LIB_NETFPGA_STATS_P4_


#include <sume_switch.p4>

const bit<8> REG_READ  = 8w0;
const bit<8> REG_WRITE = 8w1;
const bit<8> REG_ADD   = 8w2;


#define QUEUE_SIZES_REG_DEPTH 1
#define QUEUE_SIZES_REG_WIDTH 80

@brief("Register used for reporting queue sizes.")
@description("The control plane is expected to read this register over DMA.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(QUEUE_SIZES_REG_DEPTH)
extern void stat_queue_sizes_reg_rw(in bit<QUEUE_SIZES_REG_DEPTH> index,
                                    in bit<QUEUE_SIZES_REG_WIDTH> newVal,
                                    in bit<8> opCode,
                                    out bit<QUEUE_SIZES_REG_WIDTH> result);

#define PKT_CNT_REG_DEPTH 3
#define PKT_CNT_REG_WIDTH 32

@brief("Register used for reporting total received packet count.")
@description("The control plane is expected to read this register over DMA.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(PKT_CNT_REG_DEPTH)
extern void stat_recv_pkt_cnt_reg_raw(in bit<PKT_CNT_REG_DEPTH> index,
                                      in bit<PKT_CNT_REG_WIDTH> newVal,
                                      in bit<PKT_CNT_REG_WIDTH> incVal,
                                      in bit<8> opCode,
                                      out bit<PKT_CNT_REG_WIDTH> result);

@brief("Register used for reporting total sent packet count.")
@description("The control plane is expected to read this register over DMA.")
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(PKT_CNT_REG_DEPTH)
extern void stat_send_pkt_cnt_reg_raw(in bit<PKT_CNT_REG_DEPTH> index,
                                      in bit<PKT_CNT_REG_WIDTH> newVal,
                                      in bit<PKT_CNT_REG_WIDTH> incVal,
                                      in bit<8> opCode,
                                      out bit<PKT_CNT_REG_WIDTH> result);

control GetPortIndex(in port_t port, out bit<3> index) {
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

control WriteStats(in sume_metadata_t sume) {
    bit<PKT_CNT_REG_DEPTH>     port_index;

    // SDNet does not support using _ with an extern 
    bit<QUEUE_SIZES_REG_WIDTH> notneededq;
    bit<PKT_CNT_REG_WIDTH>     notneededp;


    apply {
        // Copy queue sizes
        stat_queue_sizes_reg_rw(
            0,
            sume.dma_q_size ++
            sume.nf3_q_size ++
            sume.nf2_q_size ++
            sume.nf1_q_size ++
            sume.nf0_q_size,
            REG_WRITE,
            notneededq
        );

        // increment received
        GetPortIndex.apply(sume.src_port, port_index);
        stat_recv_pkt_cnt_reg_raw(port_index, 0, 1, REG_ADD, notneededp);
        // increment sent
        GetPortIndex.apply(sume.dst_port, port_index);
        stat_send_pkt_cnt_reg_raw(port_index, 0, 1, REG_ADD, notneededp);
    }
}

#endif