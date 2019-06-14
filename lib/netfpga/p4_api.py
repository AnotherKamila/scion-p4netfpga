import json
import os
import functools
from ctypes import c_uint, c_int, c_char_p

import attr

from netfpga import utils


PLATFORM           = 'netfpga'
ARCH               = 'xilinx_stream_switch'
PLATFORM_FOLDER    = os.path.join(os.path.dirname(__file__), '../../platforms',
                                  PLATFORM, ARCH)
PLATFORM_SW_FOLDER = os.path.join(PLATFORM_FOLDER, 'sw/CLI')


def json_from_file(path):
    with open(path) as f:
        return json.load(f)

def dict_or_json_from_file(arg):
    return json_from_file(arg) if isinstance(arg, str) else arg

def merge_table_data(p4tables, switchinfo):
    res = {}

    # get stuff from p4tables
    for tables in p4tables.values():
        for name, data in tables.items():
            res[name] = data

    #get stuff from switchinfo
    for block_name, block_dict in switchinfo.items():
        if 'px_lookups' in block_dict.keys():
            for table_dict in block_dict['px_lookups']:
                name = table_dict['p4_name']
                res[name].update(table_dict)
                res[name]['enclosing_block'] = block_name




    from pprint import pprint
    pprint(res)



    return res

@attr.s
class P4Switch:
    switchinfo         = attr.ib(converter=dict_or_json_from_file,
                                 default=os.path.join(PLATFORM_FOLDER, 'sdnet_switch.info'))
    externs            = attr.ib(converter=dict_or_json_from_file,
                                 default=os.path.join(PLATFORM_SW_FOLDER, 'Scion_extern_defines.json'))
    tables             = attr.ib()
    cam_libs_folder    = attr.ib(default=PLATFORM_SW_FOLDER)
    sume_lib_folder    = attr.ib(default=os.path.expandvars('$SUME_FOLDER/lib/sw/std/hwtestlib'))
    sumereg_lib_folder = attr.ib(default=os.path.expandvars('$SUME_SDNET/sw/sume'))
    lib                = attr.ib()  # initialised by self.load_libs()

    @lib.default
    def load_libs(self):
        lib = utils.CLibs()
        lib.load_libs(self.sume_lib_folder, {
            'sume': {
                'regread':  ((c_uint,),        c_uint),
                'regwrite': ((c_uint, c_uint), c_uint),
            },
        })
        lib.load_libs(self.cam_libs_folder, {
            'cam': {
                'cam_read_entry':   ((c_uint, c_char_p, c_char_p, c_char_p), None),
                'cam_add_entry':    ((c_uint, c_char_p, c_char_p),           None),
                'cam_delete_entry': ((c_uint, c_char_p),                     None),
                'cam_error_decode': ((c_int,),                               c_char_p),
                'cam_get_size':     ((c_uint,),                              c_uint),
            },
        })
        return lib

    @tables.default
    def init_tables(self, arg=os.path.join(PLATFORM_SW_FOLDER, 'Scion_table_defines.json')):
        if not isinstance(arg, str):  # assume it's already processed
            return arg
        return merge_table_data(p4tables=json_from_file(arg),
                                switchinfo=self.switchinfo)

    ### REGISTERS ############################################################

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

    ### TABLES ###############################################################

    # replicates netfpga api while fixing the most annoying things

    def _table_poke(self, table_name, keys, action_name=None, action_data=None):
        t = self.tables[table_name]
        if t['match_type'] != 'EM':
            raise NotImplementedError(
                'Cannot add to table {}: Only exact match tables are currently supported'.format(
                    table_name))
        ret = [t]
        # TODO:
        # 1. convert keys
        # 2. find action_id
        # 3. convert action_data
        # 2. bunch them all together into key, value
        # ret += TODO keys
        # if action_name and action_data: ret += TODO action_name, action_data
        return ret

    def table_add(self, table_name, keys, action_name, action_data):
        t, key, value = self._table_poke(keys, action_name, action_data)
        ret = libcam.cam_add_entry(tableID, "{:X}".format(key), "{:X}".format(value))
        err = libcam.cam_error_decode(rc)
        if err: raise err

