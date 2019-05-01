import os

from .p4_api import P4Switch

from prometheus_client.twisted import MetricsResource
from twisted.web import resource, server
from twisted.internet import reactor, endpoints

PORT = os.getenv('PORT', 8000)


def main():
    http_root = resource.Resource()
    http_root.putChild(b'metrics', MetricsResource())
    print('HTTP server running on port {}'.format(PORT))
    endpoints.serverFromString(
        reactor, r'tcp:interface=\:\:0:port={}'.format(PORT)
    ).listen(server.Site(http_root))

    reactor.run()


if __name__ == '__main__':
    switch = P4Switch(
        extern_defines='platforms/netfpga/xilinx_stream_switch/sw/CLI/Scion_extern_defines.json'
    )
    print(switch.reg_read('stat_counter', 0))
    main()
