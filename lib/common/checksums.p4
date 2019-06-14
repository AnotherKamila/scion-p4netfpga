// Checksums for IP & family
// TODO somebody should think this file through so that it doesn't
// unconditionally use NetFPGA-specific externs. Or maybe I should just move it to
// lib/netfpga.
#ifndef SC_LIB_COMMON_CHECKSUMS_P4_
#define SC_LIB_COMMON_CHECKSUMS_P4_


#include <common/datatypes.p4>
#include <common/headers.p4>

// They know I have the stuff in a header.
// Therefore...
// This must be the ugliest interface in the Universe.
@Xilinx_MaxLatency(3)
@Xilinx_ControlWidth(0)
extern void compute_ip_chksum(in bit<4> version, 
                              in bit<4> ihl,
                              in bit<8> tos,
                              in bit<16> totalLen,
                              in bit<16> identification,
                              in bit<3> flags,
                              in bit<13> fragOffset,
                              in bit<8> ttl,
                              in bit<8> protocol,
                              in bit<16> hdrChecksum,
                              in bit<32> srcAddr,
                              in bit<32> dstAddr,
                              out bit<16> result);

// The following must be controls, because SDNet does not support calling
// externs from actions (and does not support functions).
@brief("Updates the IPv4 header's checksum.")
control UpdateIPv4Checksum(inout ipv4_h hdr) {
    bit<16> result;
    apply {
        compute_ip_chksum(hdr.version, 
                          hdr.ihl,
                          hdr.tos,
                          hdr.total_len,
                          hdr.identification,
                          hdr.flags,
                          hdr.frag_offset,
                          hdr.ttl,
                          hdr.protocol,
                          hdr.hdr_checksum,
                          hdr.src_addr,
                          hdr.dst_addr,
                          result);
        hdr.hdr_checksum = result;
    }
}

@brief("Updates the UDP header's checksum.")
control UpdateUDPChecksum(inout udp_h hdr) {
    apply {
        hdr.checksum = 0; // checksum not used -- TODO one day :D
    }
}


#endif