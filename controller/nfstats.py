import prometheus_client.core as prom

from .base_controller import BaseController

SUME_IFACES = ['eth0', 'dma0', 'eth1', 'dma1', 'eth2', 'dma2', 'eth3', 'dma3']

class NFStatsCollector:
    PREFIX = 'nf_'
    def __init__(self, p4switch):
        self.p4switch = p4switch

    def collect(self):
        # create metrics
        # TODO would be super cute to read the metric name and description
        # straight from P4 annotations!
        recv = prom.CounterMetricFamily(
            self.PREFIX+'receive_packets_total',
            'Total number of packets received by the P4 pipeline',
            labels=['interface'],
            unit='packets',
        )
        send = prom.CounterMetricFamily(
            self.PREFIX+'transmit_packets_total',
            'Total number of packets sent by the P4 pipeline',
            labels=['interface'],
            unit='packets',
        )
        queues = prom.GaugeMetricFamily(
            self.PREFIX+'queue_size_blocks',
            'Input queue sizes for each interface, in 32-byte blocks',
            labels=['interface'],
        )

        # add data
        for i, name in enumerate(SUME_IFACES):
            recv.add_metric([name], self.p4switch.reg_read('stat_recv_pkt_cnt', i))
            send.add_metric([name], self.p4switch.reg_read('stat_send_pkt_cnt', i))

            # There is just one queue for all DMA stuff => handled separately
            if name.startswith('dma'): continue
            queues.add_metric([name], self.p4switch.reg_read('stat_queue_sizes', i))

        # DMA queue size lives at index 1
        queues.add_metric(['dma'], self.p4switch.reg_read('stat_queue_sizes', 1))

        # give metrics to prometheus_client
        yield recv
        yield send
        yield queues


class NFStats(BaseController):
    def init(self):
        prom.REGISTRY.register(NFStatsCollector(self.p4switch))
