#include <core.p4>
#include <sume_switch.p4>

typedef bit<48> eth_addr_t; 
typedef bit<32> ipv4_addr_t;

#define ETHERTYPE_IPV4 0x0800

header ethernet_h { 
    eth_addr_t dst_addr; 
    eth_addr_t src_addr; 
    bit<16>    ethertype;
}

header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  tos; 
    bit<16> total_len; 
    bit<16> identification; 
    bit<3>  flags;
    bit<13> frag_offset; 
    bit<8> ttl;
    bit<8> protocol; 
    bit<16> hdr_checksum; 
    ipv4_addr_t src_addr; 
    ipv4_addr_t dst_addr;
}

struct headers_t { 
    ethernet_h ethernet; 
    ipv4_h     ipv4;
}

struct user_metadata_t {
    bit<8>  unused;
}

// MUST be 256 bits!
struct digest_data_t {
    bit<256>  unused;
}

@Xilinx_MaxPacketRegion(16384)
parser TopParser(packet_in packet, 
                 out headers_t hdr, 
                 out user_metadata_t user_metadata,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {

    state start {
        packet.extract(hdr.ethernet);
        transition select(p.ethernet.ethertype) {
            ETHERTYPE_IPV4: parse_ipv4;
            default: reject;
        } 
    }

    state parse_ipv4 { 
        packet.extract(hdr.ipv4);
        transition accept; 
    }
}

control TopPipe(inout headers_t hdr,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    apply {}
}

@Xilinx_MaxPacketRegion(16384)
control TopDeparser(packet_out packet,
                    in headers_t hdr,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 
    apply {
        packet.emit(hdr.ethernet); 
        packet.emit(hdr.ipv4);
    }
}

SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;

