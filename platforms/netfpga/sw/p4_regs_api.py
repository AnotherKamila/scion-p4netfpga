#!/usr/bin/env python3

import json
import os
from ctypes import cdll, c_uint

class Regs:
    def __init__(self, extern_defines, libsume_path=None):
        if not libsume_path: libsume_path = os.path.join(
                os.environ['SUME_FOLDER'],'lib','sw','std','hwtestlib','libsume.so')
        self.libsume=cdll.LoadLibrary(libsume_path)
        self.libsume.regread.argtypes = [c_uint]
        self.libsume.regwrite.argtypes= [c_uint, c_uint]

        with open(extern_defines) as f:
            self.externs = json.load(f)

    def get_address(self, reg_name, index):
        reg_width = self.externs.get(reg_name, {}).get('control_width', 0)
        if reg_width == 0:
            raise ValueError("{0} is not a register accessible to the control plane".format(reg_name))
        if not 0 <= index <= 2**reg_width:
            raise IndexError("{0}[1]: index out of bounds".format(reg_name, index))
        return self.externs[reg_name]['base_addr'] + index

    def read(self, reg_name, index):
        return self.libsume.regread(self.get_address(reg_name, index))

    def write(self, reg_name, index, val):
        return libsume.regwrite(self.get_address(reg_name, index), val)
