# TODO this file should be cleaned up some day :D
import os
import sys

import attr
from prometheus_client.twisted import MetricsResource
from twisted.web import resource, server
from twisted.internet import defer, reactor, endpoints

# TODO choose the correct platform, somehow?
from netfpga.p4_api import P4Switch
from netfpga.stats import NFStats
from netfpga.wallclock import NFWallClock

DEBUG = os.getenv('DEBUG', '0') != '0'

@attr.s
class NFScionController:
    p4switch  = attr.ib()
    reactor   = attr.ib()
    http_port = attr.ib()
    http_root = attr.ib()

    @http_root.default
    def make_http_root(self):
        root = resource.Resource()
        root.putChild(b'metrics', MetricsResource())
        return root

    def start(self):
        # TODO(realtraffic) write into SCION interfaces table
        # TODO(realtraffic) write AS key into a reg
        self.stats          = NFStats(self.p4switch)
        self.wall_clock     = NFWallClock(self.p4switch)
        self.stats.register_metrics()
        self.wall_clock.start()
        self.start_http_server()

        if DEBUG:
            self.wall_clock.forced_time = 247  # to make testing independent of time

    def fill_tables_TODO_dont_hardcode_me(self):
        """Currently hard-codes the same things as commands.txt.

        Should be changed into a proper controller one day.
        """
        # set my MAC addresses
        self.p4switch.table_add('my_mac', [0b00000001], 'set_src_mac', ['7f:9a:b3:3a:00:00'])
        self.p4switch.table_add('my_mac', [0b00000100], 'set_src_mac', ['7f:9a:b3:3a:00:01'])
        self.p4switch.table_add('my_mac', [0b00010000], 'set_src_mac', ['7f:9a:b3:3a:00:02'])
        self.p4switch.table_add('my_mac', [0b01000000], 'set_src_mac', ['7f:9a:b3:3a:00:03'])
        self.p4switch.table_add('my_mac', [0b00000010], 'set_src_mac', ['7f:9a:b3:3a:00:f0'])
        self.p4switch.table_add('my_mac', [0b00001000], 'set_src_mac', ['7f:9a:b3:3a:00:f1'])
        self.p4switch.table_add('my_mac', [0b00100000], 'set_src_mac', ['7f:9a:b3:3a:00:f2'])
        self.p4switch.table_add('my_mac', [0b10000000], 'set_src_mac', ['7f:9a:b3:3a:00:f3'])

        # SCION IFID => port mapping
        self.p4switch.table_add('egress_ifid_to_port', [1], 'set_dst_port', [0b00000001])
        self.p4switch.table_add('egress_ifid_to_port', [2], 'set_dst_port', [0b00000100])

        # SCION overlay table
        self.p4switch.table_add('link_overlay', [0x1], 'set_overlay_udp_v4',
                                ['10.10.10.1', 50000, '10.10.10.11', 50000, '00:60:dd:44:c2:c4'])
        self.p4switch.table_add('link_overlay', [0x2], 'set_overlay_udp_v4',
                                ['10.10.10.2', 50000, '10.10.10.12', 50000, '00:60:dd:44:c2:c5'])

    def start_http_server(self):
        endpoints.serverFromString(
            self.reactor, r'tcp:interface=\:\:0:port={}'.format(self.http_port)
        ).listen(server.Site(self.http_root))
        print('HTTP server listening on port {}'.format(self.http_port))


def main():
    p4switch = P4Switch()
    http_port = os.getenv('PORT', 9600)
    ctrl = NFScionController(reactor=reactor, p4switch=p4switch, http_port=http_port)
    ctrl.start()


    # TODO remove
    ctrl.fill_tables_TODO_dont_hardcode_me()

    reactor.run()


if __name__ == '__main__':
    main()
