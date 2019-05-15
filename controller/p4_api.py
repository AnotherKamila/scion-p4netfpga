import os
import sys

# TODO move this file to lib/
# TODO choose the correct platform, somehow?
platform_lib_path = os.path.join(os.path.dirname(__file__),
                                 '../platforms/netfpga/sw/')
sys.path.append(platform_lib_path)
from p4_regs_api import Regs

# TODO add table API
class P4Switch(Regs):
    pass
