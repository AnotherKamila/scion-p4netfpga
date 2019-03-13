#!/usr/bin/env python

#
# Copyright (c) 2017 Stephen Ibanez
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

from scapy.all import*

from nf_sim_tools import *
import random
from collections import OrderedDict
import sss_sdnet_tuples
from scion_scapy import * # yes, I am terrible too

###########
# pkt generation tools
###########

pktsApplied = []
pktsExpected = []

# Pkt lists for SUME simulations
nf_applied = OrderedDict()
nf_applied[0] = []
nf_applied[1] = []
nf_applied[2] = []
nf_applied[3] = []
nf_expected = OrderedDict()
nf_expected[0] = []
nf_expected[1] = []
nf_expected[2] = []
nf_expected[3] = []

nf_port_map = {"nf0":0b00000001, "nf1":0b00000100, "nf2":0b00010000, "nf3":0b01000000, "dma0":0b00000010}
nf_id_map = {"nf0":0, "nf1":1, "nf2":2, "nf3":3}

sss_sdnet_tuples.clear_tuple_files()

def applyPkt(pkt, ingress, time):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['pkt_len'] = len(pkt) 
    sss_sdnet_tuples.sume_tuple_in['src_port'] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect['pkt_len'] = len(pkt) 
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = nf_port_map[ingress]
    pkt.time = time
    nf_applied[nf_id_map[ingress]].append(pkt)

def expPkt(pkt, egress):
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect['dst_port'] = nf_port_map[egress]
    sss_sdnet_tuples.write_tuples()
    if egress in ["nf0","nf1","nf2","nf3"]:
        nf_expected[nf_id_map[egress]].append(pkt)
    elif egress == 'bcast':
        nf_expected[0].append(pkt)
        nf_expected[1].append(pkt)
        nf_expected[2].append(pkt)
        nf_expected[3].append(pkt)

def write_pcap_files():
    wrpcap("in.pcap",     pktsApplied)
    wrpcap("expect.pcap", pktsExpected)

    for i in nf_applied.keys():
        if (len(nf_applied[i]) > 0):
            wrpcap('nf{0}_applied.pcap'.format(i), nf_applied[i])

    for i in nf_expected.keys():
        if (len(nf_expected[i]) > 0):
            wrpcap('nf{0}_expected.pcap'.format(i), nf_expected[i])

    for i in nf_applied.keys():
        print "nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]]

#####################
# generate testdata #
#####################

# Yes, nf_sim_tools has a function like this.
# It doesn't work.
def padded(pkt, pad_to):
    pad_len = pad_to - len(pkt)
    if pad_len <= 0: return pkt
    return pkt/Padding(b'\x00'*pad_len)

for i in range(100):
    sender = '00:60:dd:44:c2:c4' # enp3s0
    recver = '00:60:dd:44:c2:c5' # enp5s0
    scion = SCION(
        addr=SCIONAddr(
            dst_isdas=ISD_AS(ISD=47, AS=0x4747), src_isdas=ISD_AS(ISD=42, AS=0x4242),
            dst_host='10.0.0.47', src_host='10.0.0.42',
        ),
        path=[
            PathSegment(timestamp=147, isd=42, hops=[
                HopField(ingress_if=0, egress_if=1),
                HopField(ingress_if=1, egress_if=0),
            ]),
            PathSegment(timestamp=147, isd=43, hops=[
                HopField(ingress_if=0, egress_if=1),
            ]),
            PathSegment(timestamp=147, isd=47, hops=[
                HopField(ingress_if=1, egress_if=0),
            ]),
        ]
    )
    # scion.show2()
    encaps = (Ether(dst=recver, src=sender) /
              IP(dst='2.2.2.2', src='1.1.1.1') /
              UDP(dport=50000, sport=50000))
    payload = UDP(dport=1047, sport=1042) / "hello {}\n".format(i)
    applyPkt(encaps/set_current_inf_hf(0,0, scion)/payload, 'nf0', i)
    expPkt(  encaps/set_current_inf_hf(0,1, scion)/payload, 'nf1')

write_pcap_files()

