# corresponds to src/datatypes.p4
# TODO should be (partly? largely!) generated

import scapy.all as scapy

SUME_IFACES = ['nf0', 'dma0', 'nf1', 'dma1', 'nf2', 'dma2', 'nf3', 'dma3']
# the SUME representation of interfaces is one-hot encoded:
SUME_IFACE_MAP = { 1<<i: iface for i, iface in enumerate(SUME_IFACES)}

# TODO don't hardcode -- maybe just make a comma-separated thing that can be
# #included into P4 and parsed into here
# or maybe it lives in some JSON
ERROR_TYPES = { i: t for (i,t) in enumerate([
   "NoError",
   "L2Error",
   "BadVersion",
   "BadHostAddrType",
   "BadDstType",
   "BadSrcType",
   "InvalidOffset",
   "BadPktLen",
   "BadINFOffset",
   "BadHFOffset",
   "PathRequired",
   "BadMAC",
   "ExpiredHF",
   "BadIf",
   "RevokedIf",
   "NonForwardHof",
   "DeliveryFwdOnly",
   "DeliveryNonLocal",
   "InternalError",
])}

QUEUE_SIZES_FIELDS = [
    scapy.XBitField('dma_q_size', 0, 16),
    scapy.XBitField('nf3_q_size', 0, 16),
    scapy.XBitField('nf2_q_size', 0, 16),
    scapy.XBitField('nf1_q_size', 0, 16),
    scapy.XBitField('nf0_q_size', 0, 16),
]

class SumeMetadata(scapy.Packet):
    """SUME tuple structure. Corresponds to p4include/sume_switch.p4/#sume_metadata_t."""
    name = 'SumeMetadata'
    fields_desc = QUEUE_SIZES_FIELDS + [
        scapy.XBitField('send_dig_to_cpu', 0, 8),
        scapy.XBitField('drop',            0, 8),
        scapy.BitEnumField('dst_port',     None, 8, SUME_IFACE_MAP),
        scapy.BitEnumField('src_port',     None, 8, SUME_IFACE_MAP),
        scapy.XBitField('pkt_len',         None, 16),
    ]

class Digest(scapy.Packet):
    """Digest data structure. Corresponds to src/datatypes.p4#digest_data_t."""
    name = 'Digest'
    fields_desc = [
        scapy.IntEnumField('error', 0, ERROR_TYPES),
        scapy.XBitField('debug1',   0, 64),
        scapy.XBitField('debug2',   0, 64),
    ] + QUEUE_SIZES_FIELDS + [
        scapy.XBitField('unused',   0, 16),
    ]

class SwitchMeta(scapy.Packet):
    """Switch metadata format. Corresponds to src/main-xilinx-stream-switch.p4#switch_meta_t.

    Technically never a packet on the wire, but if I'm using scapy for everything else...
    """
    name = 'SwitchMeta'
    fields_desc = [
        scapy.PacketField('digest', Digest(),       Digest),
        scapy.PacketField('sume',   SumeMetadata(), SumeMetadata),
    ]
