import os
import ctypes

import attr


@attr.s(cmp=False)
class CLibs:
    """Simple wrapper for loading and accessing several C libraries.

    After calling load_libs, you may access the library as this.lib.name.
    See Regs below for a usage example.
    """

    libs         = attr.ib(factory=dict)

    def load_libs(self, libs_folder, libs_fns_dict):
        """
        Parameters:
         - libs_fns_dict: {libname => {function_name => (argtypes_tuple, restype)}}
        """
        for libname, fns_dict in libs_fns_dict.items():
            lib_path = os.path.join(libs_folder, 'lib{}.so'.format(libname))
            lib = ctypes.cdll.LoadLibrary(lib_path)
            for fn, argtypes in fns_dict.items():
                (getattr(lib, fn).argtypes, getattr(lib, fn).restype) = argtypes
            self.libs[libname] = lib

    def __getattr__(self, name):
        return self.libs[name]

