import attr
import prometheus_client.core as prom

from .datatypes import SUME_IFACES

@attr.s(cmp=False)
class NFStats:
    p4switch  = attr.ib()

    PREFIX = 'nf_'

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
            if not name.startswith('dma'):
                queues.add_metric([name], self.p4switch.reg_read('stat_queue_sizes', i))

        # DMA queue size lives at index 1
        queues.add_metric(['dma'], self.p4switch.reg_read('stat_queue_sizes', 1))

        # give metrics to prometheus_client
        yield recv
        yield send
        yield queues

    def register_metrics(self, registry=prom.REGISTRY):
        registry.register(self)
