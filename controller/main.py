import os

import attr
from prometheus_client.twisted import MetricsResource
from twisted.web import resource, server
from twisted.internet import reactor, endpoints

from .p4_api import P4Switch

PORT = os.getenv('PORT', 8000)

# TODO move somewhere appropriate
import prometheus_client.core as prom

class P4SwitchCollector:
    def __init__(self, p4switch):
        self.p4switch = p4switch

    def collect(self):
        c = prom.CounterMetricFamily(
            'p4switch_packets_total',
            'Total number of packets processed by the P4 pipeline',
            labels=['interface'],
            unit='packets',
        )
        c.add_metric(['TODO'], self.p4switch.reg_read('stat_counter', 0))
        yield c

def main():
    http_root = resource.Resource()
    http_root.putChild(b'metrics', MetricsResource())
    print('HTTP server running on port {}'.format(PORT))
    endpoints.serverFromString(
        reactor, r'tcp:interface=\:\:0:port={}'.format(PORT)
    ).listen(server.Site(http_root))

    reactor.run()


if __name__ == '__main__':
    p4switch = P4Switch(
        extern_defines='platforms/netfpga/xilinx_stream_switch/sw/CLI/Scion_extern_defines.json'
    )
    prom.REGISTRY.register(P4SwitchCollector(p4switch))
    main()
