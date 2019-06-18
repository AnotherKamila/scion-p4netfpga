#!/usr/bin/env python3

import itertools
import typing
import random
import sys
from collections import namedtuple

assert sys.version_info >= (3,5), "Python 3.5 or newer is needed."

from scapy.all import *

from netfpga.datatypes import *  # TODO remove import * after cleaning up this file

from scion_scapy import * # yes, I am terrible too

random.seed(47)

SCION_IFID_MAP = {'eth{}'.format(i): i+1 for i in range(4)}
VERBOSE=False

TUPLES_APPLIED_FILE       = "Tuple_in.txt"
TUPLES_EXPECTED_FILE      = "Tuple_expect.txt"
ALL_PACKETS_APPLIED_FILE  = "in.pcap"
ALL_PACKETS_EXPECTED_FILE = "expect.pcap"
PACKETS_APPLIED_FILE      = "{}_applied.pcap"   # formatted with interface name
PACKETS_EXPECTED_FILE     = "{}_expected.pcap"

ALL_PKTS_IF = '_union_'  # used to hold the union of all packets applied/expected on all interfaces

PktTup = namedtuple('PktTup', ['pkt', 'tup'])

applied  = {iface: [] for iface in (SUME_IFACES+[ALL_PKTS_IF])} # if => [PktTup]
def apply_pkt(pkt:Packet, ingress_if:str, time:int):
    pkt.time = time
    tup = SwitchMeta(
        sume=SumeMetadata(
            pkt_len=len(pkt),
            src_port=ingress_if,
        )
    )
    applied[ingress_if].append(PktTup(pkt=pkt, tup=tup))
    applied[ALL_PKTS_IF].append(PktTup(pkt=pkt, tup=tup))

expected  = {iface: [] for iface in (SUME_IFACES+[ALL_PKTS_IF])} # if => [PktTup]
def expect_pkt(pkt:Packet, egress_if:str, ingress_if:str=None, digest:Digest=None, error:str="NoError"):
    if not digest: digest = Digest(error=error)
    tup = SwitchMeta(
        digest=digest,
        sume=SumeMetadata(
            pkt_len=len(pkt),
            src_port=ingress_if if ingress_if else egress_if,
            dst_port=egress_if,
            send_dig_to_cpu=1 if hasattr(digest, 'sent') and digest.sent else 0,
        )
    )
    expected[egress_if].append(PktTup(pkt=pkt, tup=tup))
    expected[ALL_PKTS_IF].append(PktTup(pkt=pkt, tup=tup))

def apply_and_expect(time:int,
                     in_pkt:Packet, ingress_if:str,
                     exp_pkt:Packet, egress_if:str,
                     digest:Digest=None,
                     error:str="NoError"):
    apply_pkt(in_pkt, ingress_if, time)
    expect_pkt(exp_pkt, egress_if, ingress_if=ingress_if, digest=digest, error=error)

def wrtuple(fname, tuples):
    print(tuples)
    with open(fname, 'w') as f:
        for t in tuples:
            f.write(bytes(t).hex() + '\n')

def write_files():
    def pcap(fname, pkttups):
        if pkttups:
            wrpcap(fname, [p for (p, t) in pkttups])

    def tup(fname, pkttups):
        wrtuple(fname, [t for (p, t) in pkttups])

    # these are needed for pcap -> axi conversion for vivado sim
    pcap(ALL_PACKETS_APPLIED_FILE,  applied[ALL_PKTS_IF])
    pcap(ALL_PACKETS_EXPECTED_FILE, expected[ALL_PKTS_IF])

    tup(TUPLES_APPLIED_FILE,  applied[ALL_PKTS_IF])
    tup(TUPLES_EXPECTED_FILE, expected[ALL_PKTS_IF])

    for iface in SUME_IFACES:
        pcap(PACKETS_APPLIED_FILE.format(iface),
           applied[iface])
        pcap(PACKETS_EXPECTED_FILE.format(iface), expected[iface])

#####################
# generate testdata #
#####################

def padded(pkt, pad_to):
    pad_len = pad_to - len(pkt)
    if pad_len <= 0: return pkt
    return pkt/Padding(b'\x00'*pad_len)

def gen(badmacs=False, num_hfs_per_seg=3):
    """It's not really num hfs per seg :D TODO!"""
    sender  = '00:60:dd:44:c2:c4' # enp3s0
    me_base = '7f:9a:b3:3a:00:{}' # last byte is 0 for eth0 .. 3 for eth3
    recver  = '00:60:dd:44:c2:c5' # enp5s0

    for s in range(3):
        for h in range(num_hfs_per_seg):
            # ifs     = random.choice([('nf0','nf1'), ('nf1','nf0')])
            ifs     = ('eth0','eth1')
            ifids = SCION_IFID_MAP[ifs[0]], SCION_IFID_MAP[ifs[1]]
            if badmacs: ifs[1].replace('eth', 'dma') # send to CPU on error

            seg     = [(SCION_IFID_MAP['eth2'], SCION_IFID_MAP['eth3'])]*(num_hfs_per_seg)
            currseg = seg[:]
            currseg.insert(h, ifids)
            segs    = [seg[:], seg[:]]
            segs.insert(s, currseg)
            # print(h, s, segs)

            scion = SCION(
                addr=SCIONAddr(
                    dst_isdas=ISD_AS(ISD=47, AS=0x4747), src_isdas=ISD_AS(ISD=42, AS=0x4242),
                    dst_host='10.0.0.47', src_host='10.0.0.42',
                ),
                path=[
                    PathSegment(timestamp=0, isd=42, hops=[
                        HopField(ingress_if=in_if, egress_if=eg_if, mac=(0x47 if badmacs else None))
                        for (in_if, eg_if) in seg
                    ])
                    for seg in segs
                ]
            )
            # scion.show2()
            encaps_there = (Ether(src=sender, dst=me_base.format(0)) /
                    IP(src='10.10.10.11', dst='10.10.10.1') /
                    UDP(dport=50000, sport=50000, chksum=0))  # checksum not used
            encaps_back = (Ether(dst=recver, src=me_base.format(1)) /
                    IP(src='10.10.10.2', dst='10.10.10.12') /
                    UDP(dport=50000, sport=50000, chksum=0))  # checksum not used
            payload = UDP(dport=1047, sport=1042) / "hello seg {} hop {}\n".format(s, h)

            if not badmacs:
                yield (encaps_there / set_current_inf_hf(s,h,   scion)/payload, ifs[0],
                       encaps_back  / set_current_inf_hf(s,h+1, scion)/payload, ifs[1],
                       Digest())
            else:  # send to CPU and note the error
                yield (encaps_there / set_current_inf_hf(s,h, scion)/payload, ifs[0],
                       encaps_there / set_current_inf_hf(s,h, scion)/payload, ifs[0].replace('eth', 'dma'),
                       Digest(error='BadMAC'))

def gen_nonscion():
    packet = IP(dst="192.168.0.47") / ICMP() / (b'\x47'*1000)
    yield packet, 'dma0', packet, 'eth0', Digest()  # no error, just passthrough from CPU
    yield packet, 'eth1', packet, 'dma1', Digest(error="NotSCION")  # not SCION + expect passthrough


PAD_TO = 1450

def mkpackets(only_times=None):
    # TODO really test error handling: make sure that the correct errors are
    # returned in all cases
    # packets = itertools.chain(gen_nonscion(), gen(), gen(badmacs=True), gen(num_hfs_per_seg=7))
    packets = itertools.chain(
        gen(),
        gen(badmacs=True),
        gen(num_hfs_per_seg=7),
        gen_nonscion(),
    )
    for t, data in enumerate(packets, 1):
        in_pkt, in_if, exp_pkt, exp_if, exp_digest = data
        if only_times:
            if t not in only_times: continue
        if VERBOSE:
            print('================ packet {} ================'.format(t))
            in_pkt.show2()
            print('================ end packet {} ================'.format(t))
        apply_and_expect(t, padded(in_pkt, PAD_TO), in_if, padded(exp_pkt, PAD_TO), exp_if, exp_digest)
    write_files()


if __name__ == '__main__':
    times = [int(x) for x in sys.argv[1:]] if len(sys.argv) > 1 else None
    mkpackets(times)
