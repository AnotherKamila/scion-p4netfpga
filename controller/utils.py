import contextlib
import functools
import os

from twisted.internet import defer


# @contextlib.contextmanager
# def dir_in_path(value, var='PATH'):
#     old = os.environ.get(var, None)
#     new = old + ':' + value if old else value
#     os.environ[var] = new
#     yield
#     if old:
#         os.environ[var] = old
#     else:
#         del os.environ[var]

def ensure_deferred_f(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        result = f(*args, **kwargs)
        return defer.ensureDeferred(result)
    return wrapper
