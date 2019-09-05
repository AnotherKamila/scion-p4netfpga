# Adds SCION interfaces info into the P4 switch's overlay table.
# Maybe TODO split into scion_settings (reads the settings) and scion_links
# (fills the tables) and something for the AS key (maybe can be in the
# settings)... or maybe just rename to scion_settings, IDK

import os
import sys

import attr
import netifaces
import treq
from twisted.internet import defer
from twisted.internet import task
from twisted.internet.utils import getProcessOutput

from netfpga.datatypes import SUME_IFACE_MAP
from . import utils

try:
    from lib.topology import Topology
    from lib.crypto.symcrypto import kdf
    from lib.crypto.util import (
        get_master_key,
        MASTER_KEY_0,
        MASTER_KEY_1
    )
except ImportError as e:
    print('Cannot import SCION Python lib, make sure scion/python is in PYTHONPATH', file=sys.stderr)
    raise e


defer.setDebugging(True)

# TODO split this into its own module; allow specifying this with a flag
SCION_PATH = os.getenv('SC', default=os.path.join(os.getenv('GOPATH'), 'src/github.com/scionproto/scion'))
GEN_FOLDER_NAME = 'gen'
GEN_FOLDER_PATH = os.path.join(SCION_PATH, GEN_FOLDER_NAME)

# TODO this should be derived from ISD-AS, which should be either read from
# gen/ia or passed as a commandline flag
MY_CONFIG_PATH = 'ISD1/ASff00_0_110/br1-ff00_0_110-1'
TOPO_FILE = os.path.join(GEN_FOLDER_PATH, MY_CONFIG_PATH, 'topology.json')

# let's see how this split goes...
@attr.s
class ASSettings:
    """Parses the AS settings and makes them easily available.

    Attributes:
      - topo_file: path to the BR's topology.json file inside the gen folder
      - topo: SCION's lib.topology.Topology object; will be initialised from
        topo_file if not provided

    TODO this should actually expose all of the AS settings, not just the BR,
    and allow to load them selectively.
    """
    conf_dir  = attr.ib(default=os.path.join(GEN_FOLDER_PATH, MY_CONFIG_PATH))
    topo_file = attr.ib(default=TOPO_FILE)
    topo = attr.ib(default=None)  # none => read from TOPO_FILE

    # TODO this should be given the BR ID instead of having it hardcoded above
    def get(self):
        if not self.topo: self.topo = Topology.from_file(self.topo_file)
        return self


def make_ip2iface_maps():
    ip2iface = {}
    for addrfamily in (netifaces.AF_INET, netifaces.AF_INET6):
        ip2iface[addrfamily] = {}
        for iface in netifaces.interfaces():
            for addr in netifaces.ifaddresses(iface).get(addrfamily, []):
                ip2iface[addrfamily][addr['addr']] = iface
    return ip2iface

@attr.s
class ASLinks:
    """Adds SCION links/interfaces information to the switch's overlay table.

    Attributes:
      - p4switch: netfpga.p4_api.P4Switch
      - reactor: Twisted reactor
      - settings: ASSettings for my AS
      - TODO BR ID or whatever it is

    Currently does not support IPv6 (TODO).
    """
    p4switch = attr.ib()
    reactor  = attr.ib()
    settings = attr.ib()

    ip2iface = attr.ib(factory=make_ip2iface_maps)

    @property
    def my_settings(self):
        return self.settings.get()  # TODO pass BR ID

    def fill_p4_tables(self, squished=True, overlay=True):
        for iface in self.my_settings.topo.get_all_interfaces():
            print("will attempt to add IFID for {}".format(iface))
            self.reactor.callLater(0, self.add_link, iface, squished, overlay)

    # TODO support IPv6
    @utils.ensure_deferred_f
    async def add_link(self, iface, squished=True, overlay=True):
        if iface.bind:
            raise NotImplemented("error adding link for interface #{}: bind != public is not implemented".format(iface.if_id))
        addrfamily             = netifaces.AF_INET  
        my_ip, my_port         = str(iface.public[0].addr), iface.public[1]
        remote_ip, remote_port = str(iface.remote[0].addr), iface.public[1]
        my_device = None
        try:
            my_device = self.ip2iface[addrfamily][my_ip]
        except KeyError:
            print("WARNING: IFID {} does not have an IPv4 address that is set up on this system, ignoring".format(iface.if_id), file=sys.stderr)
        if not my_device or not my_device.startswith('nf'):
            # TODO logging :D
            print("WARNING: IFID {} is not set up for a NetFPGA interface, ignoring".format(iface.if_id), file=sys.stderr)
        my_mac         = netifaces.ifaddresses(my_device)[netifaces.AF_LINK][0]['addr']
        my_nf_eth_port = SUME_IFACE_MAP[my_device.replace('nf', 'eth')]
        remote_mac     = await self.get_mac(remote_ip)

        print("*** Adding link for IFID #{}".format(iface.if_id))
        print("     - device: {}".format(my_device))
        print("     - my MAC addr: {}".format(my_mac))
        print("     - public: {}:{}".format(iface.public[0], iface.public[1]))
        print("     - remote: {}:{}".format(iface.remote[0], iface.remote[1]))
        print("     - remote MAC addr: {}".format(remote_mac))

        if not squished:
            # SCION IFID => port mapping
            self.p4switch.table_add('egress_ifid_to_port', [iface.if_id],
                                    'set_dst_port', [my_nf_eth_port])

            if overlay:
                # my MAC address
                self.p4switch.table_add('my_mac', [my_nf_eth_port], 'set_src_mac', [my_mac])

                # SCION overlay table
                self.p4switch.table_add(
                    'link_overlay',
                    [iface.if_id],
                    'set_overlay_udp_v4',
                    [my_ip, my_port, remote_ip, remote_port, remote_mac]
                )

        else:
            # squished all of the above into one table to save CAM lookups, so here goes that one biiig table
            self.p4switch.table_add(
                'squished',
                [iface.if_id],
                'all_the_things_overlay_v4',
                [
                    my_nf_eth_port,
                    my_mac,
                    my_ip, my_port, remote_ip, remote_port,
                    remote_mac,
                ]
            )

    def set_as_key(self):
        master0 = get_master_key(self.settings.conf_dir, MASTER_KEY_0)
        as_key  = kdf(master0, b"Derive OF Key")
        print(master0.hex())
        print(int.from_bytes(as_key, byteorder='big'))
        # TODO this throws because the NetFPGA API only supports 32-bit
        # registers, we need to figure out how to write bigger ones
        self.p4switch.reg_write('as_key', 0, as_key)

    # TODO support IPv6
    @utils.ensure_deferred_f
    async def get_mac(self, ipaddr):
        print('poking host {} to get MAC address'.format(ipaddr))
        try:
            # 47 is reserved => nothing's there
            await treq.get('http://{}/:47'.format(ipaddr),
                           timeout=0.5,
                           reactor=self.reactor)
        except Exception as ex:
            pass  # we don't care how this fails
        arptable = (await getProcessOutput(
            '/usr/sbin/arp', ['-n'], reactor=self.reactor
        )).decode('utf-8')
        myline = [x for x in arptable.split('\n') if ipaddr in x]
        if not myline:
            raise RuntimeError("Could not get MAC address for {}, is it on the same link?".format(ipaddr))
        return myline[0].split()[2]
