// main for NetFPGA SUME switch with the XilinxStreamSwitch architecture

#include <core.p4>        // P4 core
#include <xilinx_core.p4> // packet_mod
#include <xilinx.p4>      // XilinxStreamSwitch
#include <sume_switch.p4> // sume_metadata

#include "settings.p4" // must be included *before* SCION

#include <scion/datatypes.p4>
#include <scion/headers.p4>
#include <scion/parsers.p4>
#include <scion/mod_deparsers.p4>

#include "datatypes.p4"

const bit<128> HF_MAC_KEY = 128w0x47; // TODO set by control plane instead of compiling in

struct local_t {
    user_metadata_t     meta;
    scion_all_headers_t hdr;
}

// DO NOT change this: the NetFPGA expects exactly this format
// TODO maybe I should move this to its own header?
struct switch_meta_t {
    digest_data_t   digest;
    sume_metadata_t sume;
}

@Xilinx_MaxPacketRegion(MTU)
parser TopParser(packet_in packet, out local_t d) {

    ScionParser() scion_parser;
    state start {
        scion_parser.apply(packet, d.meta.scion, d.hdr);
        transition accept;
    }
}

// TODO Move this somewhere reasonable in lib/scion

// TODO figure out a more reasonable externs thingy or something, IDK
// the @brief and @description should certainly be instance-specific, so the
// general stuff should go elsewhere
@brief("AES-128-ECB encryption for a single block of data")
@description("Deterministic single-block AES encryption. Should not be used \
as is: this is intended as a building block for various modes.")
@Xilinx_MaxLatency(5)
@Xilinx_ControlWidth(0)
extern void cmac1_aes128(in bit<128> K, in bit<128> data, out bit<128> result);

@Xilinx_MaxLatency(5)
@Xilinx_ControlWidth(0)
extern void cmac2_aes128(in bit<128> K, in bit<128> data, out bit<128> result);

// TODO pass HFs instead of M
@brief("Checks the given HF's MAC.")
@description("Computes the AES-CMAC of current (plus prev without flags). \
See SCION book, p. 122 / eq. 7.8. \
Implements a *simplified* version of https://tools.ietf.org/html/rfc4493.")
control VerifyHF(in    bit<128>         K,
                 inout scion_metadata_t meta,
                 in    scion_timestamp  timestamp,
                 in    scion_hf_h       current,
                 in    scion_hf_h       prev) {
    /*******************************************************************
    This is an *incomplete* implementation of AES-CMAC, *simplified*
    because we have exactly one exactly 128-bit block of data.
    What could possibly go wrong :D
    Dear reader, please ignore this until I get my security MSc :D

    This is how I've modified RFC4493
    (https://tools.ietf.org/html/rfc4493):
    
                        Algorithm Generate_Subkey                      
                                                                       
       Input    : K (128-bit key)                                      
       Output   : K1 (128-bit first subkey)                            
                  K2 (128-bit second subkey)         <== never needed  
                                                                       
       Constants: const_Zero is 0x00000000000000000000000000000000     
                  const_Rb   is 0x00000000000000000000000000000087     
       Variables: L          for output of AES-128 applied to 0^128    
                                                                       
       Step 1.  L := AES-128(K, const_Zero);                           
       Step 2.  if MSB(L) is equal to 0                                
                then    K1 := L << 1;                                  
                else    K1 := (L << 1) XOR const_Rb;                   
       Step 3.  if MSB(K1) is equal to 0           <== only for K2 --  
                then    K2 := K1 << 1;                -- never needed  
                else    K2 := (K1 << 1) XOR const_Rb;                  
       Step 4.  return K1, K2;                                         
                                                                       
    +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                       Algorithm AES-CMAC                              
                                                                       
       Input    : K    ( 128-bit key )                                 
                : M    ( message to be authenticated )                 
                : len  ( length of the message in octets )             
       Output   : T    ( message authentication code )                 
                                                                       
       Constants: const_Zero is 0x00000000000000000000000000000000     
                  const_Bsize is 16                                    
                                                                       
       Variables: K1, K2 for 128-bit subkeys                           
                  M_i is the i-th block (i=1..ceil(len/const_Bsize))   
                  M_last is the last block xor-ed with K1 or K2        
                  n      for number of blocks to be processed          
                  r      for number of octets of last block            
                  flag   for denoting if last block is complete or not 
                                                                       
       Step 1.  (K1,K2) := Generate_Subkey(K);                         
       Step 2.  n := ceil(len/const_Bsize);                            
       Step 3.  if n = 0                            <== always false   
                then                                \                  
                     n := 1;                         > never happens   
                     flag := false;                 /                  
                else                                                   
                     if len mod const_Bsize is 0    <== always true    
                     then flag := true;             <== always happens 
                     else flag := false;            <== never happens  
                                                                       
       Step 4.  if flag is true                     <== always true    
                then M_last := M_n XOR K1;          <== always happens 
                else M_last := padding(M_n) XOR K2; <== never happens  
       Step 5.  X := const_Zero;                                       
       Step 6.  for i := 1 to n-1 do                <== not executed   
                    begin                             /                
                      Y := X XOR M_i;                |                 
                      X := AES-128(K,Y);             |                 
                    end                             /                  
                Y := M_last XOR X;      <== M_last == M XOR K1; X == 0 
                T := AES-128(K,Y);      <== Y == M XOR K1              
       Step 7.  return T;                                              

    ********************************************************************/

    // SDNet doesn't support calling externs from actions,
    // so this all has to be one big apply block :-/

    bit<56> prev_data = (
        prev.expiry ++           //  8b
        prev.ingress_if ++       // 12b
        prev.egress_if ++        // 12b
        prev.mac                 // 24b
    );
    bit<128> M = (
        timestamp ++                                   // 32b
        (current.flags & SCION_HF_IMMUTABLE_FLAGS) ++  //  8b
        current.expiry ++                              //  8b
        current.ingress_if ++                          // 12b
        current.egress_if ++                           // 12b
        prev_data                                      // 56b
    );

    // for Generate_Subkey
    const bit<128> const_Rb = 128w0x87;
    bit<128> L;
    bit<128> K1;

    // for AES-CMAC
    bit<128> Y; // everything else is not needed
    bit<128> T;

    apply {
        // Not quite Generate_Subkey:
        cmac1_aes128(K, 128w0, L);
        if (L[1:0] == 0) {
            K1 = L << 1;
        } else {
            K1 = (L << 1) ^ const_Rb;
        }

        // Not quite AES-CMAC:
        //  - step 1 (Generate_Subkey) is above
        //  - step 2 (computing n) not needed: n is always 1
        //  - step 3 (setting flag) not needed: flag always true
        // step 4 is inline: M_last = M ^ K1
        // step 5 has disappeared because we're not doing the loop
        // step 6 chaining loop would be here, if we had more than 1 block
        // step 6 last block:
        Y = M ^ K1; // ^ X disappeared because xor 0 is identity
        cmac2_aes128(K, Y, T); // that's it :D

        // Validation:
        bit<24> mac = T[127:128-3*8]; // SCION uses 3 bytes of the tag
        meta.error_flag = mac == current.mac ? ERRTYPE(NoError) : ERRTYPE(BadMAC);

        // Debugging signals:
        meta.debug2 = mac ++ 16w0xfeee ++ current.mac;
        // meta.debug2 = T[127:64];
        // meta.debug1 = T[63:0];
    }

}


// DO NOT RENAME the "s" parameter: the generated Verilog derives wire names
// from it, so if you change it, you'll have to also change
// platforms/netfpga/xilinx-stream-switch/hw/nf_sume_sdnet.v.
@Xilinx_MaxPacketRegion(MTU)
control TopPipe(inout local_t d,
                inout switch_meta_t s) {

    // TODO modularise this once the architecture is clear

    action reflect_L2() {
        eth_addr_t tmp_src_addr = d.hdr.ethernet.src_addr;
        d.hdr.ethernet.src_addr = d.hdr.ethernet.dst_addr;
        d.hdr.ethernet.dst_addr = tmp_src_addr;

        s.sume.dst_port = s.sume.src_port;
    }

    action set_dst_port(port_t port) {
        s.sume.dst_port = port;
    }

    // SCION egress interface ID to physical port
    // 1:1 mapping for now
    table egress_ifid_to_port {
        key = {
            d.hdr.scion.path.current_hf.egress_if: exact;
            // ha ha, netfpga scripts don't support direct match type
            // but TODO use direct one of these days, maybe
        }
        actions = {
            set_dst_port;
            NoAction;
        }
        size=64; // smallest possible for exact match
    }

    action update_checksums() {
        d.hdr.encaps.udp.checksum = 0; // checksum not used -- TODO one day :D
    }

    action increment_hf() {
        // TODO move current pointer properly -- with xover and stuff
        d.hdr.scion.common.curr_HF = d.hdr.scion.common.curr_HF + 1;
    }

    action copy_error_to_digest() {
        s.digest.error_flag = d.meta.scion.error_flag;
    }

    action copy_debug_to_digest() {
        s.digest.debug1     = d.meta.scion.debug1;
        s.digest.debug2     = d.meta.scion.debug2;
        s.digest.marker1    = 32w0xfeeefeee;
        s.digest.marker2    = 32w0xfeeefeee;
        s.digest.marker3    = 32w0xfeeefeee;
    }

    VerifyHF() verify_current_hf;
    apply {
        egress_ifid_to_port.apply();
        increment_hf();
        update_checksums();

        // TODO remove
        bit<128> res;
        verify_current_hf.apply(HF_MAC_KEY,
                                d.meta.scion,
                                d.hdr.scion.path.current_inf.timestamp,
                                d.hdr.scion.path.current_hf,
                                d.hdr.scion.path.prev_hf);

        copy_error_to_digest();
        if (s.digest.error_flag != ERRTYPE(NoError)) copy_debug_to_digest();
    }
}

// It does not make much sense to modularise the deparser, because we only want
// to update the parts we want to update, which depends on what we changed.
// However: TODO this could be split into a "fwd-only deparser" with the
// contract of changing L2, encaps and INF+HF offsets and nothing else.
@Xilinx_MaxPacketRegion(MTU)
parser TopDeparser(in local_t d, packet_mod pkt) {
    ScionEncapsulationModDeparser() encaps_deparser;

    state start{
        // we changed L2
        pkt.update(d.hdr.ethernet);

        // encapsulate; beware that this does not consume the encapsulation
        // if we want to remove it!
        // This would need to be thought about if we supported both encapsulated
        // and non-encapsulated SCION.
        encaps_deparser.apply(pkt, d.hdr.ethernet.ethertype, d.hdr.encaps);

        // update only INF and HF in SCION common header
        pkt.update(d.hdr.scion.common, SCION_COMMON_HDR_MASK_INF_HF);

        // done: we didn't change anything else
        transition accept;
    }
}

XilinxStreamSwitch(TopParser(), TopPipe(), TopDeparser()) main;