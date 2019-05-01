import os
from p4_regs_api import Regs

if __name__ == '__main__':
    regs = Regs(extern_defines='platforms/netfpga/xilinx_stream_switch/sw/CLI/Scion_extern_defines.json')
    print(regs.read('stat_counter', 0))
