from __future__ import absolute_import, print_function

import scapy.all as scapy
import struct
import time
from scapy.all import Ether, IP, UDP

SCION_ADDR_TYPE = {1: 'ipv4', 2: 'ipv6', 3: 'svc'}

ISDField = scapy.ShortField
ASField  = lambda name, default: scapy.XBitField(name, default, 6*8)

class UnixTimeField(scapy.IntField):
    def i2repr(self, pkt, x):
        if x is None: return None
        return time.strftime('%d %b %Y %H:%M:%S UTC', time.gmtime(x))

class ISD_AS(scapy.Packet):
    name = 'ISD-AS'
    fields_desc = [
        ISDField('ISD', None),
        ASField('AS', None),
    ]

    def extract_padding(self, p):
        return "", p

class SCIONAddr(scapy.Packet):
    name = 'SCION Address header'
    fields_desc = [
        scapy.PacketField('dst_isdas', None, ISD_AS),
        scapy.PacketField('src_isdas', None, ISD_AS),
        # hard-coded v4 for now
        scapy.IPField('dst_host', None),
        scapy.IPField('src_host', None),
    ]

    def extract_padding(self, p):
        # TODO fix when removing hard-coded v4
        return "", p

    # def post_build(self, pkt, pay):
    #     # pad to a multiple of 8
    #     # TODO fix when removing hard-coded v4
    #     pass

class HopField(scapy.Packet):
    __slots__ = ('_current',)
    name = 'SCION Hop field'
    fields_desc = [
        scapy.BitField('flags', 0x0, 8),
        scapy.ByteField('expiry', 63),
        scapy.BitField('ingress_if', None, 12),
        scapy.BitField('egress_if', None, 12),
        scapy.BitField('mac', 0, 3*8), # TODO
    ]

    def extract_padding(self, p):
        return "", p

class PathSegment(scapy.Packet):
    __slots__ = ('_current',)
    name = 'SCION Path segment'
    fields_desc = [
        scapy.BitField('flags', 0x0, 8),
        UnixTimeField('timestamp', None),
        ISDField('isd', None),
        scapy.FieldLenField('nhops', None, count_of='hops', fmt='B'),
        scapy.PacketListField('hops', None, HopField, count_from=lambda p: p.nhops),
    ]

    def extract_padding(self, p):
        return "", p

# def count_segments(path_hdr):
#     count = 0
#     here = 0
#     while here < len(path_hdr):
#         if 

class SCION(scapy.Packet):
    name = 'SCION'
    fields_desc = [
        # Common header
        scapy.BitField(    'version',      0, 4),
        scapy.BitEnumField('dst_type',     1, 6, SCION_ADDR_TYPE),
        scapy.BitEnumField('src_type',     1, 6, SCION_ADDR_TYPE),
        scapy.BitField(    'total_len', None, 16),
        scapy.BitField(    'hdr_len',   None, 8),
        scapy.BitField(    'curr_inf',  None, 8),
        scapy.BitField(    'curr_hf',   None, 8),
        scapy.BitEnumField('next_hdr',  None, 8, scapy.IP_PROTOS),

        scapy.PacketField('addr', None, SCIONAddr),

        scapy.PacketListField('path', None, PathSegment, count_from=lambda _: 3)
    ]

    # this is terrible, but apparently that's how scapy works :-/
    def post_build(self, pkt, pay):
        # compute lengths
        if self.total_len == None:
            self.total_len = len(pkt) + len(pay)
            pkt = pkt[:2] + struct.pack('!H', self.total_len) + pkt[4:]
        if self.hdr_len == None:
            self.hdr_len = len(pkt)//8
            if self.hdr_len*8 != len(pkt):
                raise ValueError("SCION packet header length not multiple of 8 bytes!")
            pkt = pkt[:4] + struct.pack('B', self.hdr_len) + pkt[5:]

        return pkt+pay

scapy.bind_layers(UDP, SCION, sport=50000)
scapy.bind_layers(UDP, SCION, dport=50000)

scapy.bind_layers(SCION, UDP, next_hdr=scapy.IP_PROTOS.udp)

def set_current_inf_hf(seg, hf, pkt):
    """Calculates offsets for hf-th HF in seg-th segment and saves them in the packet.
    """
    # TODO will break when ipv4 is not hard-coded
    total_before = sum((1 + len(pkt.path[prev])) for prev in range(seg-1))
    pkt.curr_inf = 32/8 + total_before
    pkt.curr_hf  = 32/8 + total_before + 1 + hf
    return pkt

def some_scion_packet():
    return SCION(
        addr=SCIONAddr(
            dst_isdas=ISD_AS(ISD=47, AS=0x4747), src_isdas=ISD_AS(ISD=42, AS=0x4242),
            dst_host='10.0.0.47', src_host='10.0.0.42',
        ),
        path=[
            PathSegment(timestamp=147, isd=42, hops=[
                HopField(ingress_if=1, egress_if=2),
                HopField(ingress_if=0, egress_if=3),
            ]),
            PathSegment(timestamp=147, isd=43, hops=[
                HopField(ingress_if=0, egress_if=3),
            ]),
            PathSegment(timestamp=147, isd=47, hops=[
                HopField(ingress_if=1, egress_if=2),
            ]),
        ]
    )

def gen_packet():
    sender = '00:60:dd:44:c2:c4' # enp3s0
    recver = '00:60:dd:44:c2:c5' # enp5s0
    return (
        Ether(dst=recver, src=sender) /
        IP(src='1.1.1.1', dst='2.2.2.2') /
        UDP(dport=50000, sport=50000) /
        set_current_inf_hf(0, 0, some_scion_packet()) /
        UDP(dport=10047, sport=10042) /
        "hello world\n"
    )

def main():
    gen_packet().show()
    print()
    gen_packet().show2()
    # wrpcap([gen_packet()])
    # scapy.rdpcap('./packets.pcap')[0].show()

if __name__ == '__main__':
    main()





        # scapy.MultipleTypeField(
        #     [
        #         (
        #             scapy.IPField('dst_host'),
        #             (
        #                 (lambda pkt:),
        #                 (lambda pkt, val:)
        #             )
        #         ),
        #         (
        #             scapy.IP6Field('dst_host'),
        #             TODO
        #         ),
        #         (
        #             ServiceAddrField('dst_host'),
        #             TODO
        #         ),
        #     ],
        #     None
        # )
