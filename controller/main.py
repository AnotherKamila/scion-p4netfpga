import os

from prometheus_client.twisted import MetricsResource
from twisted.web import resource, server
from twisted.internet import reactor, endpoints

from .p4_api import P4Switch

PORT = os.getenv('PORT', 9600)

# TODO move somewhere appropriate
# TODO probably make a lib/python or something...
import prometheus_client.core as prom

SUME_IFACES = ['eth0', 'dma0', 'eth1', 'dma1', 'eth2', 'dma2', 'eth3', 'dma3']

class P4SwitchCollector:
    def __init__(self, p4switch):
        self.p4switch = p4switch

    def collect(self):
        # create metrics
        # TODO would be super cute to read the metric name and description
        # straight from P4 annotations!
        recv = prom.CounterMetricFamily(
            'p4switch_receive_packets_total',
            'Total number of packets received by the P4 pipeline',
            labels=['interface'],
            unit='packets',
        )
        send = prom.CounterMetricFamily(
            'p4switch_transmit_packets_total',
            'Total number of packets sent by the P4 pipeline',
            labels=['interface'],
            unit='packets',
        )
        queues = prom.GaugeMetricFamily(
            'p4switch_queue_size_bytes',
            'Input queue sizes for each interface', # TODO really? :D
            labels=['interface'],
            unit='bytes',
        )

        # add data
        for i, name in enumerate(SUME_IFACES):
            recv.add_metric([name], self.p4switch.reg_read('stat_recv_pkt_cnt', i))
            send.add_metric([name], self.p4switch.reg_read('stat_send_pkt_cnt', i))

            # There is just one queue for all DMA stuff => handled separately
            if name.startswith('dma'): continue
            # NetFPGA measures in 32-byte blocks, so we have to multiply by 32 here
            queues.add_metric([name], self.p4switch.reg_read('stat_queue_sizes', i)*32)

        # DMA queue size lives at index 1
        queues.add_metric(['dma'], self.p4switch.reg_read('stat_queue_sizes', 1)*32)

        # give metrics to prometheus_client
        yield recv
        yield send
        yield queues


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
