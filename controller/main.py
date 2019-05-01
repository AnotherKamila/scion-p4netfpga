import os

from .p4_api import P4Switch

if __name__ == '__main__':
    switch = P4Switch(extern_defines='platforms/netfpga/xilinx_stream_switch/sw/CLI/Scion_extern_defines.json')
    print(switch.reg_read('stat_counter', 0))
