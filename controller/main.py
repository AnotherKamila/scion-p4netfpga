# TODO this file should be cleaned up some day :D
import os
import sys

import attr
from prometheus_client.twisted import MetricsResource
from twisted.web import resource, server
from twisted.internet import defer, reactor, endpoints

from .p4_api import P4Switch
from .base_controller import BaseController
from .nfstats import NFStats
from .nfwallclock import NFWallClock

DEBUG = os.getenv('DEBUG', '0') != '0'

@attr.s
class NFScionController(BaseController):
    reactor   = attr.ib()
    http_port = attr.ib()
    http_root = attr.ib()

    @http_root.default
    def make_http_root(self):
        root = resource.Resource()
        root.putChild(b'metrics', MetricsResource())
        return root

    def init(self):
        self.wall_clock     = NFWallClock.get_initialised(self.p4switch)
        self.stats          = NFStats.get_initialised(self.p4switch)
        self.init_http_server()

        if DEBUG:
            self.wall_clock.force_time(247)

    def init_http_server(self):
        endpoints.serverFromString(
            self.reactor, r'tcp:interface=\:\:0:port={}'.format(self.http_port)
        ).listen(server.Site(self.http_root))
        print('HTTP server listening on port {}'.format(self.http_port))


def main():
    p4switch = P4Switch(
        extern_defines='platforms/netfpga/xilinx_stream_switch/sw/CLI/Scion_extern_defines.json'
    )
    PORT = os.getenv('PORT', 9600)
    ctrl = NFScionController.get_initialised(reactor=reactor, p4switch=p4switch, http_port=PORT)

    reactor.run()


if __name__ == '__main__':
    main()
