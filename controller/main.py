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
from .scion_links import ASSettings, ASLinks

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
        self.settings   = ASSettings()
        self.links      = ASLinks(self.p4switch, self.reactor, self.settings)
        self.stats      = NFStats(self.p4switch)
        self.wall_clock = NFWallClock(self.p4switch)

        self.links.fill_p4_tables()
        self.links.set_as_key()
        self.stats.register_metrics()
        self.wall_clock.start()
        self.start_http_server()

        if DEBUG:
            self.wall_clock.forced_time = 247  # to make testing independent of time

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
    reactor.run()


if __name__ == '__main__':
    main()
