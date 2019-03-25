`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ETH Zurich
// Engineer: Seyedali Tabaeiaghdaei
// 
// Create Date: 08/06/2018 04:37:57 PM
// Design Name: 
// Module Name: aes_encrypt
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module aes_encrypt(datain, key, clk, in_valid, reset, dataout, aes_busy);

    input [127:0] datain;
    input [127:0] key;
    input clk, reset, in_valid; 
    output reg [127:0] dataout;
    output reg aes_busy;
    
    wire [127:0] r0_out;
    wire [127:0] r1_out,r2_out,r3_out,r4_out,r5_out,r6_out,r7_out,r8_out,r9_out, r10_out;
    
    wire [127:0] keyout1,keyout2,keyout3,keyout4,keyout5,keyout6,keyout7,keyout8,keyout9;
	
	reg enable1, enable2, enable3, enable4, enable5; 
	reg [127:0] datain_reg;
	reg [127:0] key_stage0, key_stage1, key_stage2, key_stage3, key_stage4;
	reg [127:0] r_stage1, r_stage2, r_stage3, r_stage4;
	
	//reg
	assign r0_out = datain_reg ^ key_stage0;
    rounds r1(.rc(4'b0000),.data(r0_out),.keyin(key_stage0),.keyout(keyout1),.rndout(r1_out));
    rounds r2(.rc(4'b0001),.data(r1_out),.keyin(keyout1),.keyout(keyout2),.rndout(r2_out));
    //reg
    rounds r3(.rc(4'b0010),.data(r_stage1),.keyin(key_stage1),.keyout(keyout3),.rndout(r3_out)); 
    rounds r4(.rc(4'b0011),.data(r3_out),.keyin(keyout3),.keyout(keyout4),.rndout(r4_out));
    //reg
    rounds r5(.rc(4'b0100),.data(r_stage2),.keyin(key_stage2),.keyout(keyout5),.rndout(r5_out));
    rounds r6(.rc(4'b0101),.data(r5_out),.keyin(keyout5),.keyout(keyout6),.rndout(r6_out));
    //reg
    rounds r7(.rc(4'b0110),.data(r_stage3),.keyin(key_stage3),.keyout(keyout7),.rndout(r7_out));
    rounds r8(.rc(4'b0111),.data(r7_out),.keyin(keyout7),.keyout(keyout8),.rndout(r8_out));
    //reg
    rounds r9(.rc(4'b1000),.data(r_stage4),.keyin(key_stage4),.keyout(keyout9),.rndout(r9_out));
    rounndlast r10(.rc(4'b1001),.rin(r9_out),.keylastin(keyout9),.fout(r10_out));
    //reg
   
    always @(posedge clk) begin
        if (reset || (aes_busy && enable5)) begin
            aes_busy <= 0;
        end
        else if (!aes_busy && in_valid) begin
            aes_busy  <= 1;
        end
    end 
   
    always @(posedge clk) begin
        if (reset || (aes_busy && enable1)) begin
            enable1 <= 0;
        end
        else if (!aes_busy && in_valid) begin
            enable1 <= 1;
        end
    end
    
    always @(posedge clk) begin
        if (reset || enable2) begin
            enable2 <= 0;
        end
        else if (enable1) begin
            enable2 <= 1;
        end
    end
 
    always @(posedge clk) begin
        if (reset || enable3) begin
            enable3 <= 0;
        end
        else if (enable2) begin
            enable3 <= 1;
        end
    end 

    always @(posedge clk) begin
        if (reset || enable4) begin
            enable4 <= 0;
        end
        else if (enable3) begin
            enable4 <= 1;
        end
    end 

    always @(posedge clk) begin
        if (reset || enable5) begin
            enable5 <= 0;
        end
        else if (enable4) begin
            enable5 <= 1;
        end
    end 
    
    always @(posedge clk) begin
        if (reset) begin
            datain_reg <= 0;
            key_stage0 <= 0;
        end
        else if (in_valid && !aes_busy) begin
            datain_reg <= datain;
            key_stage0 <= key;          
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            key_stage1 <= 0;
            r_stage1 <= 0;
        end
        else if (enable1) begin
            key_stage1 <= keyout2;
            r_stage1 <= r2_out;
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            key_stage2 <= 0;
            r_stage2 <= 0;
        end
        else if (enable2) begin
            key_stage2 <= keyout4;
            r_stage2 <= r4_out;
        end
    end
    
    always @(posedge clk) begin
       if (reset) begin
           key_stage3 <= 0;
           r_stage3 <= 0;
       end
       else if (enable3) begin
           key_stage3 <= keyout6;
           r_stage3 <= r6_out;
       end
   end
   
   always @(posedge clk) begin
      if (reset) begin
          key_stage4 <= 0;
          r_stage4 <= 0;
      end
      else if (enable4) begin
          key_stage4 <= keyout8;
          r_stage4 <= r8_out;
      end
  end
  
  always @(posedge clk) begin
    if (reset) begin
        dataout <= 0;
    end
    else if (enable5) begin
        dataout <= r10_out;
    end
    
  end 
    
endmodule

module KeyGeneration(rc,key,keyout);
    
   input [3:0] rc;
   input [127:0]key;
   output [127:0] keyout;
   
   wire [31:0] w0,w1,w2,w3,tem;
         
               
       assign w0 = key[127:96];
       assign w1 = key[95:64];
       assign w2 = key[63:32];
       assign w3 = key[31:0];
       
       
       assign keyout[127:96]= w0 ^ tem ^ rcon(rc);
       assign keyout[95:64] = w0 ^ tem ^ rcon(rc)^ w1;
       assign keyout[63:32] = w0 ^ tem ^ rcon(rc)^ w1 ^ w2;
       assign keyout[31:0]  = w0 ^ tem ^ rcon(rc)^ w1 ^ w2 ^ w3;
       
       
       sbox a1(.a(w3[23:16]),.c(tem[31:24]));
       sbox a2(.a(w3[15:8]),.c(tem[23:16]));
       sbox a3(.a(w3[7:0]),.c(tem[15:8]));
       sbox a4(.a(w3[31:24]),.c(tem[7:0]));
       
       
       
     function [31:0]	rcon;
      input	[3:0]	rc;
      case(rc)	
         4'h0: rcon=32'h01_00_00_00;
         4'h1: rcon=32'h02_00_00_00;
         4'h2: rcon=32'h04_00_00_00;
         4'h3: rcon=32'h08_00_00_00;
         4'h4: rcon=32'h10_00_00_00;
         4'h5: rcon=32'h20_00_00_00;
         4'h6: rcon=32'h40_00_00_00;
         4'h7: rcon=32'h80_00_00_00;
         4'h8: rcon=32'h1b_00_00_00;
         4'h9: rcon=32'h36_00_00_00;
         default: rcon=32'h00_00_00_00;
       endcase

     endfunction

endmodule


module mixcolumn(a,mcl);
    input [127:0] a;
    output [127:0] mcl;

    assign mcl[127:120]= mixcolumn32 (a[127:120],a[119:112],a[111:104],a[103:96]);
    assign mcl[119:112]= mixcolumn32 (a[119:112],a[111:104],a[103:96],a[127:120]);  
    assign mcl[111:104]= mixcolumn32 (a[111:104],a[103:96],a[127:120],a[119:112]);
    assign mcl[103:96]= mixcolumn32 (a[103:96],a[127:120],a[119:112],a[111:104]);

    assign mcl[95:88]= mixcolumn32 (a[95:88],a[87:80],a[79:72],a[71:64]);
    assign mcl[87:80]= mixcolumn32 (a[87:80],a[79:72],a[71:64],a[95:88]);
    assign mcl[79:72]= mixcolumn32 (a[79:72],a[71:64],a[95:88],a[87:80]);
    assign mcl[71:64]= mixcolumn32 (a[71:64],a[95:88],a[87:80],a[79:72]);

    assign mcl[63:56]= mixcolumn32 (a[63:56],a[55:48],a[47:40],a[39:32]);
    assign mcl[55:48]= mixcolumn32 (a[55:48],a[47:40],a[39:32],a[63:56]);
    assign mcl[47:40]= mixcolumn32 (a[47:40],a[39:32],a[63:56],a[55:48]);
    assign mcl[39:32]= mixcolumn32 (a[39:32],a[63:56],a[55:48],a[47:40]);

    assign mcl[31:24]= mixcolumn32 (a[31:24],a[23:16],a[15:8],a[7:0]);
    assign mcl[23:16]= mixcolumn32 (a[23:16],a[15:8],a[7:0],a[31:24]);
    assign mcl[15:8]= mixcolumn32 (a[15:8],a[7:0],a[31:24],a[23:16]);
    assign mcl[7:0]= mixcolumn32 (a[7:0],a[31:24],a[23:16],a[15:8]);


    function [7:0] mixcolumn32;
        input [7:0] i1,i2,i3,i4;
        begin
            mixcolumn32[7]=i1[6] ^ i2[6] ^ i2[7] ^ i3[7] ^ i4[7];
            mixcolumn32[6]=i1[5] ^ i2[5] ^ i2[6] ^ i3[6] ^ i4[6];
            mixcolumn32[5]=i1[4] ^ i2[4] ^ i2[5] ^ i3[5] ^ i4[5];
            mixcolumn32[4]=i1[3] ^ i1[7] ^ i2[3] ^ i2[4] ^ i2[7] ^ i3[4] ^ i4[4];
            mixcolumn32[3]=i1[2] ^ i1[7] ^ i2[2] ^ i2[3] ^ i2[7] ^ i3[3] ^ i4[3];
            mixcolumn32[2]=i1[1] ^ i2[1] ^ i2[2] ^ i3[2] ^ i4[2];
            mixcolumn32[1]=i1[0] ^ i1[7] ^ i2[0] ^ i2[1] ^ i2[7] ^ i3[1] ^ i4[1];
            mixcolumn32[0]=i1[7] ^ i2[7] ^ i2[0] ^ i3[0] ^ i4[0];
        end
    endfunction
endmodule

module rounds(rc,data,keyin,keyout,rndout);
    input [3:0]rc;
    input [127:0]data;
    input [127:0]keyin;
    output [127:0]keyout;
    output [127:0]rndout;

    wire [127:0] sb,sr,mcl;

    KeyGeneration t0(rc,keyin,keyout);
    subbytes t1(data,sb);
    shiftrow t2(sb,sr);
    mixcolumn t3(sr,mcl);
    assign rndout= keyout ^ mcl;

endmodule

module rounndlast(rc,rin,keylastin,fout);
    input [3:0]rc;
    input [127:0]rin;
    input [127:0]keylastin;
    output [127:0]fout;

    wire [127:0] sb,sr,mcl,keyout;

    KeyGeneration t0(rc,keylastin,keyout);
    subbytes t1(rin,sb);
    shiftrow t2(sb,sr);
    assign fout= keyout ^ sr;

endmodule


module sbox(a,c);
    
    input  [7:0] a;
    output [7:0] c;
    
    reg [7:0] c;
    
    
   always @(a)
    case (a)
      8'h00: c=8'h63;
	   8'h01: c=8'h7c;
	   8'h02: c=8'h77;
	   8'h03: c=8'h7b;
	   8'h04: c=8'hf2;
	   8'h05: c=8'h6b;
	   8'h06: c=8'h6f;
	   8'h07: c=8'hc5;
	   8'h08: c=8'h30;
	   8'h09: c=8'h01;
	   8'h0a: c=8'h67;
	   8'h0b: c=8'h2b;
	   8'h0c: c=8'hfe;
	   8'h0d: c=8'hd7;
	   8'h0e: c=8'hab;
	   8'h0f: c=8'h76;
	   8'h10: c=8'hca;
	   8'h11: c=8'h82;
	   8'h12: c=8'hc9;
	   8'h13: c=8'h7d;
	   8'h14: c=8'hfa;
	   8'h15: c=8'h59;
	   8'h16: c=8'h47;
	   8'h17: c=8'hf0;
	   8'h18: c=8'had;
	   8'h19: c=8'hd4;
	   8'h1a: c=8'ha2;
	   8'h1b: c=8'haf;
	   8'h1c: c=8'h9c;
	   8'h1d: c=8'ha4;
	   8'h1e: c=8'h72;
	   8'h1f: c=8'hc0;
	   8'h20: c=8'hb7;
	   8'h21: c=8'hfd;
	   8'h22: c=8'h93;
	   8'h23: c=8'h26;
	   8'h24: c=8'h36;
	   8'h25: c=8'h3f;
	   8'h26: c=8'hf7;
	   8'h27: c=8'hcc;
	   8'h28: c=8'h34;
	   8'h29: c=8'ha5;
	   8'h2a: c=8'he5;
	   8'h2b: c=8'hf1;
	   8'h2c: c=8'h71;
	   8'h2d: c=8'hd8;
	   8'h2e: c=8'h31;
	   8'h2f: c=8'h15;
	   8'h30: c=8'h04;
	   8'h31: c=8'hc7;
	   8'h32: c=8'h23;
	   8'h33: c=8'hc3;
	   8'h34: c=8'h18;
	   8'h35: c=8'h96;
	   8'h36: c=8'h05;
	   8'h37: c=8'h9a;
	   8'h38: c=8'h07;
	   8'h39: c=8'h12;
	   8'h3a: c=8'h80;
	   8'h3b: c=8'he2;
	   8'h3c: c=8'heb;
	   8'h3d: c=8'h27;
	   8'h3e: c=8'hb2;
	   8'h3f: c=8'h75;
	   8'h40: c=8'h09;
	   8'h41: c=8'h83;
	   8'h42: c=8'h2c;
	   8'h43: c=8'h1a;
	   8'h44: c=8'h1b;
	   8'h45: c=8'h6e;
	   8'h46: c=8'h5a;
	   8'h47: c=8'ha0;
	   8'h48: c=8'h52;
	   8'h49: c=8'h3b;
	   8'h4a: c=8'hd6;
	   8'h4b: c=8'hb3;
	   8'h4c: c=8'h29;
	   8'h4d: c=8'he3;
	   8'h4e: c=8'h2f;
	   8'h4f: c=8'h84;
	   8'h50: c=8'h53;
	   8'h51: c=8'hd1;
	   8'h52: c=8'h00;
	   8'h53: c=8'hed;
	   8'h54: c=8'h20;
	   8'h55: c=8'hfc;
	   8'h56: c=8'hb1;
	   8'h57: c=8'h5b;
	   8'h58: c=8'h6a;
	   8'h59: c=8'hcb;
	   8'h5a: c=8'hbe;
	   8'h5b: c=8'h39;
	   8'h5c: c=8'h4a;
	   8'h5d: c=8'h4c;
	   8'h5e: c=8'h58;
	   8'h5f: c=8'hcf;
	   8'h60: c=8'hd0;
	   8'h61: c=8'hef;
	   8'h62: c=8'haa;
	   8'h63: c=8'hfb;
	   8'h64: c=8'h43;
	   8'h65: c=8'h4d;
	   8'h66: c=8'h33;
	   8'h67: c=8'h85;
	   8'h68: c=8'h45;
	   8'h69: c=8'hf9;
	   8'h6a: c=8'h02;
	   8'h6b: c=8'h7f;
	   8'h6c: c=8'h50;
	   8'h6d: c=8'h3c;
	   8'h6e: c=8'h9f;
	   8'h6f: c=8'ha8;
	   8'h70: c=8'h51;
	   8'h71: c=8'ha3;
	   8'h72: c=8'h40;
	   8'h73: c=8'h8f;
	   8'h74: c=8'h92;
	   8'h75: c=8'h9d;
	   8'h76: c=8'h38;
	   8'h77: c=8'hf5;
	   8'h78: c=8'hbc;
	   8'h79: c=8'hb6;
	   8'h7a: c=8'hda;
	   8'h7b: c=8'h21;
	   8'h7c: c=8'h10;
	   8'h7d: c=8'hff;
	   8'h7e: c=8'hf3;
	   8'h7f: c=8'hd2;
	   8'h80: c=8'hcd;
	   8'h81: c=8'h0c;
	   8'h82: c=8'h13;
	   8'h83: c=8'hec;
	   8'h84: c=8'h5f;
	   8'h85: c=8'h97;
	   8'h86: c=8'h44;
	   8'h87: c=8'h17;
	   8'h88: c=8'hc4;
	   8'h89: c=8'ha7;
	   8'h8a: c=8'h7e;
	   8'h8b: c=8'h3d;
	   8'h8c: c=8'h64;
	   8'h8d: c=8'h5d;
	   8'h8e: c=8'h19;
	   8'h8f: c=8'h73;
	   8'h90: c=8'h60;
	   8'h91: c=8'h81;
	   8'h92: c=8'h4f;
	   8'h93: c=8'hdc;
	   8'h94: c=8'h22;
	   8'h95: c=8'h2a;
	   8'h96: c=8'h90;
	   8'h97: c=8'h88;
	   8'h98: c=8'h46;
	   8'h99: c=8'hee;
	   8'h9a: c=8'hb8;
	   8'h9b: c=8'h14;
	   8'h9c: c=8'hde;
	   8'h9d: c=8'h5e;
	   8'h9e: c=8'h0b;
	   8'h9f: c=8'hdb;
	   8'ha0: c=8'he0;
	   8'ha1: c=8'h32;
	   8'ha2: c=8'h3a;
	   8'ha3: c=8'h0a;
	   8'ha4: c=8'h49;
	   8'ha5: c=8'h06;
	   8'ha6: c=8'h24;
	   8'ha7: c=8'h5c;
	   8'ha8: c=8'hc2;
	   8'ha9: c=8'hd3;
	   8'haa: c=8'hac;
	   8'hab: c=8'h62;
	   8'hac: c=8'h91;
	   8'had: c=8'h95;
	   8'hae: c=8'he4;
	   8'haf: c=8'h79;
	   8'hb0: c=8'he7;
	   8'hb1: c=8'hc8;
	   8'hb2: c=8'h37;
	   8'hb3: c=8'h6d;
	   8'hb4: c=8'h8d;
	   8'hb5: c=8'hd5;
	   8'hb6: c=8'h4e;
	   8'hb7: c=8'ha9;
	   8'hb8: c=8'h6c;
	   8'hb9: c=8'h56;
	   8'hba: c=8'hf4;
	   8'hbb: c=8'hea;
	   8'hbc: c=8'h65;
	   8'hbd: c=8'h7a;
	   8'hbe: c=8'hae;
	   8'hbf: c=8'h08;
	   8'hc0: c=8'hba;
	   8'hc1: c=8'h78;
	   8'hc2: c=8'h25;
	   8'hc3: c=8'h2e;
	   8'hc4: c=8'h1c;
	   8'hc5: c=8'ha6;
	   8'hc6: c=8'hb4;
	   8'hc7: c=8'hc6;
	   8'hc8: c=8'he8;
	   8'hc9: c=8'hdd;
	   8'hca: c=8'h74;
	   8'hcb: c=8'h1f;
	   8'hcc: c=8'h4b;
	   8'hcd: c=8'hbd;
	   8'hce: c=8'h8b;
	   8'hcf: c=8'h8a;
	   8'hd0: c=8'h70;
	   8'hd1: c=8'h3e;
	   8'hd2: c=8'hb5;
	   8'hd3: c=8'h66;
	   8'hd4: c=8'h48;
	   8'hd5: c=8'h03;
	   8'hd6: c=8'hf6;
	   8'hd7: c=8'h0e;
	   8'hd8: c=8'h61;
	   8'hd9: c=8'h35;
	   8'hda: c=8'h57;
	   8'hdb: c=8'hb9;
	   8'hdc: c=8'h86;
	   8'hdd: c=8'hc1;
	   8'hde: c=8'h1d;
	   8'hdf: c=8'h9e;
	   8'he0: c=8'he1;
	   8'he1: c=8'hf8;
	   8'he2: c=8'h98;
	   8'he3: c=8'h11;
	   8'he4: c=8'h69;
	   8'he5: c=8'hd9;
	   8'he6: c=8'h8e;
	   8'he7: c=8'h94;
	   8'he8: c=8'h9b;
	   8'he9: c=8'h1e;
	   8'hea: c=8'h87;
	   8'heb: c=8'he9;
	   8'hec: c=8'hce;
	   8'hed: c=8'h55;
	   8'hee: c=8'h28;
	   8'hef: c=8'hdf;
	   8'hf0: c=8'h8c;
	   8'hf1: c=8'ha1;
	   8'hf2: c=8'h89;
	   8'hf3: c=8'h0d;
	   8'hf4: c=8'hbf;
	   8'hf5: c=8'he6;
	   8'hf6: c=8'h42;
	   8'hf7: c=8'h68;
	   8'hf8: c=8'h41;
	   8'hf9: c=8'h99;
	   8'hfa: c=8'h2d;
	   8'hfb: c=8'h0f;
	   8'hfc: c=8'hb0;
	   8'hfd: c=8'h54;
	   8'hfe: c=8'hbb;
	   8'hff: c=8'h16;
	endcase

endmodule

module shiftrow(sb,sr);

    input [127:0] sb;
    output [127:0] sr;

    assign         sr[127:120] = sb[127:120];  
    assign         sr[119:112] = sb[87:80];
    assign         sr[111:104] = sb[47:40];
    assign         sr[103:96] = sb[7:0];
   
    assign          sr[95:88] = sb[95:88];
    assign          sr[87:80] = sb[55:48];
    assign          sr[79:72] = sb[15:8];
    assign          sr[71:64] = sb[103:96];
   
    assign          sr[63:56] = sb[63:56];
    assign          sr[55:48] = sb[23:16];
    assign          sr[47:40] = sb[111:104];
    assign          sr[39:32] = sb[71:64];
   
    assign          sr[31:24] = sb[31:24];
    assign          sr[23:16] = sb[119:112];
    assign          sr[15:8] = sb[79:72];
    assign          sr[7:0] = sb[39:32]; 


endmodule

module subbytes(data,sb);

input [127:0] data;
output [127:0] sb;

     sbox q0( .a(data[127:120]),.c(sb[127:120]) );
     sbox q1( .a(data[119:112]),.c(sb[119:112]) );
     sbox q2( .a(data[111:104]),.c(sb[111:104]) );
     sbox q3( .a(data[103:96]),.c(sb[103:96]) );
     
     sbox q4( .a(data[95:88]),.c(sb[95:88]) );
     sbox q5( .a(data[87:80]),.c(sb[87:80]) );
     sbox q6( .a(data[79:72]),.c(sb[79:72]) );
     sbox q7( .a(data[71:64]),.c(sb[71:64]) );
     
     sbox q8( .a(data[63:56]),.c(sb[63:56]) );
     sbox q9( .a(data[55:48]),.c(sb[55:48]) );
     sbox q10(.a(data[47:40]),.c(sb[47:40]) );
     sbox q11(.a(data[39:32]),.c(sb[39:32]) );
     
     sbox q12(.a(data[31:24]),.c(sb[31:24]) );
     sbox q13(.a(data[23:16]),.c(sb[23:16]) );
     sbox q14(.a(data[15:8]),.c(sb[15:8]) );
     sbox q16(.a(data[7:0]),.c(sb[7:0]) );
	  
endmodule


