import attr

# TODO clean this up
SUME_IFACES = ['eth0', 'dma0', 'eth1', 'dma1', 'eth2', 'dma2', 'eth3', 'dma3']
DMA_IFACES  = [iface for iface in SUME_IFACES if     iface.startswith('dma')]
REAL_IFACES = [iface for iface in SUME_IFACES if not iface.startswith('dma')]

@attr.s
class BaseController:
    p4switch = attr.ib()  # .p4_api.P4Switch

    def init(self):
        pass

    @classmethod
    def get_initialised(cls, *args, **kwargs):
        obj = cls(*args, **kwargs)
        obj.init()
        return obj
