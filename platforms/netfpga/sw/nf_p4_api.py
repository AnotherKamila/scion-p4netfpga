#!/usr/bin/env python3

import json
import os
import functools
from ctypes import cdll, c_uint, c_int, c_char_p

import attr


@attr.s(cmp=False)
class CLibAPI:
    """Simple wrapper for loading and accessing several C libraries.

    After calling load_libs, you may access the library as this.lib.name.
    See Regs below for a usage example.
    """
    libs_folder  = attr.ib()

    def load_libs(self, libs_fns_dict):
        """
        Parameters:
         - libs_fns_dict: {libname => {function_name => (argtypes_tuple, restype)}}
        """
        for libname, fns_dict in libs_fns_dict.items():
            lib = cdll.LoadLibrary(os.path.join(self.libs_folder, 'lib{}.so'.format(libname)))
            for fn, argtypes in fns_dict.items():
                (getattr(lib, fn).argtypes, getattr(lib, fn).restype) = argtypes
            setattr(self, libname, lib)


class Regs:
    def __init__(self, extern_defines, libs_folder=os.path.expandvars('$SUME_FOLDER/lib/sw/std/hwtestlib')):
        self.lib = CLibAPI(libs_folder)
        self.lib.load_libs({
            'sume': {
                'regread':  ((c_uint,),        c_uint),
                'regwrite': ((c_uint, c_uint), c_uint),
            }
        })

        with open(extern_defines) as f:
            self.externs = json.load(f)

    def get_reg_addr(self, reg_name, index):
        reg_width = self.externs.get(reg_name, {}).get('control_width', 0)
        if reg_width == 0:
            raise ValueError(
                "{0} is not a register accessible to the control plane".format(reg_name)
            )
        if not 0 <= index <= 2 ** reg_width:
            raise IndexError(
                "{0}[1]: index out of bounds".format(reg_name, index)
            )
        if self.externs[reg_name]['output_fields']:
            width = self.externs[reg_name]['output_fields'][0]['size']
            if width != 32:
                raise NotImplementedError(
                    'Only 32 bits wide registers are implemented ({} is {} bits wide)'.format(reg_name, width)
                )
        return self.externs[reg_name]['base_addr'] + index

    def reg_read(self, reg_name, index):
        return self.lib.sume.regread(self.get_reg_addr(reg_name, index))

    def reg_write(self, reg_name, index, val):
        return self.lib.sume.regwrite(self.get_reg_addr(reg_name, index), val)


# TODO add table API
class NFSwitchAPI(Regs):
    pass
