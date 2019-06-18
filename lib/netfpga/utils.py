import ctypes
import functools
import os
import sys
import types

import attr


def to_int(s, base=None, bytes_per_chunk=1, little_endian=True):
    """Converts string representations of bytes to ints.

    Interprets the string as follows:
     - dot-separated => decimal bytes (like IPv4 addresses)
     - colon-separated => hex bytes (like MAC addresses)
     - dot- or-colon-separated multi-byte chunks (like IPv6 addresses): pass bytes_per_chunk=2 (or whatever)
     - set base to force something instead of guessing from the separator
    """
    if   type(s) == int: return s
    elif type(s) == str:
        chunks = [s]
        if   ':' in s: chunks, base_ = s.split(':'), 16
        elif '.' in s: chunks, base_ = s.split('.'), 10
        if not base: base = base_
        # TODO instead of enumerate, I should do this here the same way as with convert_fields below, for consistency
        if little_endian: chunks = reversed(chunks)
        res = 0
        for i, ch in enumerate(chunks):
            res += int(ch, base) << 8*bytes_per_chunk*i
        return res
    else:
        raise TypeError("Cannot convert a {} to integer".format(type(s)))

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


def print_call(f):
    """Decorator that prints every function call to stderr."""
    @functools.wraps(f)
    def wrapped(*args, **kwargs):
        args_ = args
        name  = f.__name__
        if isinstance(f, types.MethodType) or hasattr(f, '_is_method'):
            self_, args_ = args[0], args[1:]
            name = self_.__class__.__name__ + '.' + f.__name__
        strargs = [str(a) for a in args_] + ["{}={}".format(k, v) for k, v in kwargs.items()]
        print("{}({})".format(name, ', '.join(strargs)), file=sys.stderr)
        res = f(*args, **kwargs)
        print('  -> {}'.format(res))
        return res
    return wrapped

def print_method_call(f):
    """Wrapper for print_call for python3.5, which cannot automatically detect methods"""
    f._is_method = True
    return print_call(f)
