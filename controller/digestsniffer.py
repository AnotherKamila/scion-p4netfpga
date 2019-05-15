# TODO doc
#
# to enable python to sniff packets without running as root:
#
#   $ sudo setcap cap_net_raw=eip $(readlink -f $(which python))

import threading
import sys

import attr
from scapy.all import sniff
from twisted.internet import defer, reactor, task

from . import utils
from .datatypes import Digest


DMA_IFACES  = ['nf{}'.format(i) for i in range(4)]
defer.setDebugging(True)


class SnifferThread(threading.Thread):
    def __init__(self, reactor, shared_queue, iface):
        threading.Thread.__init__(self)
        self.reactor = reactor
        self.shared_queue = shared_queue
        self.iface = iface

    def run(self):
        # exceptions in threads are a terrible idea -.-
        try:
            sniff(iface=self.iface, prn=self.consume_packet)
        except PermissionError as err:
            self.shared_queue.put(err)

    def consume_packet(self, raw_packet):
        self.reactor.callFromThread(self.shared_queue.put, (self.iface, raw_packet))

@attr.s
class NFDigestSniffer:
    ifaces   = attr.ib(factory=list)
    _sniffers = attr.ib(factory=list)
    _queue   = attr.ib(factory=defer.DeferredQueue)

    ERROR_MSG = """
    Cannot sniff the network interface.
    To enable Python to sniff traffic, give it the cap_net_raw capability with:
    $ sudo setcap cap_net_raw=eip $(readlink -f $(which python3))"""

    def process_packet(self, iface, packet):
        digest = Digest(bytes(packet)[::-1])  # reversed because NetFPGA messes up endianity here :-/
        print(iface, digest.summary())

    @utils.ensure_deferred_f
    async def _consume_from_queue(self):
        item = await self._queue.get()
        if isinstance(item, PermissionError):
            raise PermissionError(self.ERROR_MSG) from item
        iface, packet = item
        return self.process_packet(iface, packet)

    @utils.ensure_deferred_f
    async def start(self, reactor):
        for iface in self.ifaces:
            t = SnifferThread(reactor, self._queue, iface)
            t.daemon = True  # die when the main thread dies
            t.start()
            self._sniffers.append(t)
        while True:
            await self._consume_from_queue()


def sniff_all():
    print("will listen on interfaces: {}".format(' '.join(DMA_IFACES)), file=sys.stderr)
    task.react(NFDigestSniffer(DMA_IFACES).start)

if __name__ == '__main__':
    sniff_all()
