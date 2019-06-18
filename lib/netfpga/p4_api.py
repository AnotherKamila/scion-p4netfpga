# This file is somewhat terrifying and somebody should refactor it some day.
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


class TableError(RuntimeError):
    pass

@attr.s
class P4Table:
    name = attr.ib()
    d    = attr.ib()
    lib  = attr.ib()

    def add(self, keys, action_name, action_data):
        key, value = self._poke(keys, action_name, action_data)
        ret = self.lib.cam.cam_add_entry(self.table_id,
                                         bytes('{:X}'.format(key),   'ascii'),
                                         bytes('{:X}'.format(value), 'ascii'))
        err = self.lib.cam.cam_error_decode(ret)
        if err: raise TableError(err)

    def _poke(self, keys, action_name=None, action_data=None):
        if self.d['match_type'] != 'EM':
            raise NotImplementedError(
                'Cannot add to table {}: Only exact match tables are currently supported'.format(
                    table_name))
        ret = []
        # 1. convert keys
        key_fields = [(f['px_name'], f['size']) for f in self.d['request_fields']]
        ret.append(self._convert_fields(keys, key_fields))
        # 2. find action_id and convert action_data
        if action_name and action_data:
            fields = []
            values = []
            for f in self.d['response_fields']:
                if f['type'] == 'bits':
                    fields.append((f['px_name'], f['size']))
                    values.append(self.action_id(action_name) if f['px_name'] == 'action_run' else 0)
                elif f['type'] == 'struct':
                    fields += [(c['px_name'], c['size']) for c in f['fields']]
                    if f['p4_action'] == self.full_action_name(action_name):
                        values += action_data
                    else:
                        values += [0]*len(f['fields'])
            ret.append(self._convert_fields(values, fields))
        return ret

    @utils.print_method_call
    def _convert_fields(self, values, fields):
        ret = 0
        for val, (name, size) in zip(map(utils.to_int, values), fields):
            if 'padding' in name or 'hit' in name: continue  # libcam does not want these fields
            self._ensure_fit(val, size, name)
            ret = (ret << size) + val
        return ret

    def _ensure_fit(self, value, size, field):
        mask = 2**size - 1
        if value != (value & mask):
            raise ValueError(
                "Adding into table {}, field {}: Value {} does not fit into {} bits".format(
                    self.name, field, value, size
                )
            )

    def action_id(self, action_name):
        return self.d['action_ids'][self.full_action_name(action_name)]

    def full_action_name(self, action_name):
        if '.' in action_name: return action_name
        if action_name == 'NoAction': return '.NoAction'
        return self.d['enclosing_block'] + '.' + action_name

    @property
    def table_id(self):
        return int(self.d['tableID'])


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
    return res

@attr.s
class P4Switch:
    switchinfo         = attr.ib(converter=dict_or_json_from_file,
                                 default=os.path.join(PLATFORM_FOLDER, 'sdnet_switch.info'))
    externs            = attr.ib(converter=dict_or_json_from_file,
                                 default=os.path.join(PLATFORM_SW_FOLDER, 'Scion_extern_defines.json'))
    cam_libs_folder    = attr.ib(default=PLATFORM_SW_FOLDER)
    sume_lib_folder    = attr.ib(default=os.path.expandvars('$SUME_FOLDER/lib/sw/std/hwtestlib'))
    sumereg_lib_folder = attr.ib(default=os.path.expandvars('$SUME_SDNET/sw/sume'))
    lib                = attr.ib()  # initialised by self.load_libs()
    tables             = attr.ib()

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
                'cam_read_entry':   ((c_uint, c_char_p, c_char_p, c_char_p), c_int),
                'cam_add_entry':    ((c_uint, c_char_p, c_char_p),           c_int),
                'cam_delete_entry': ((c_uint, c_char_p),                     c_int),
                'cam_error_decode': ((c_int,),                               c_char_p),
                'cam_get_size':     ((c_uint,),                              c_uint),
            },
        })
        return lib

    @tables.default
    def init_tables(self, arg=os.path.join(PLATFORM_SW_FOLDER, 'Scion_table_defines.json')):
        if not isinstance(arg, str):  # assume it's already processed
            return arg
        table_data = merge_table_data(p4tables=json_from_file(arg),
                                      switchinfo=self.switchinfo)
        return {name: P4Table(name, d, self.lib) for name, d in table_data.items()}

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

    # Kinda sorta replicates (a subset of) netfpga api while fixing the most annoying things

    def table_add(self, table_name, keys, action_name, action_data):
        """Alias to self.tables[name].add(...)"""
        return self.tables[table_name].add(keys, action_name, action_data)
