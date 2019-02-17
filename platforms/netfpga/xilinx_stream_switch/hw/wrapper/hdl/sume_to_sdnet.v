`timescale 1ns / 1ps

//
// Copyright (c) 2017 Stephen Ibanez
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


//////////////////////////////////////////////////////////////////////////////////
// Affiliation: Stanford University
// Author: Stephen Ibanez
// 
// Create Date: 03/23/2017
// Module Name: sume_to_sdnet
//////////////////////////////////////////////////////////////////////////////////

module sume_to_sdnet (

// clk/rst input
input                               axis_aclk,
input                               axis_resetn,

// input SUME axis signals
input                               SUME_axis_tvalid,
input                               SUME_axis_tlast,
input                               SUME_axis_tready,

// output SDNet signals
output reg                          SDNet_tuple_VALID,
output                              SDNet_axis_TLAST

);

reg [1:0]   state;
reg [1:0]   state_next;

wire [1:0] state_debug = state;

// states
localparam FIRST = 0;
localparam WAIT = 1; 

always @(*) begin
   // defaults
   state_next = state;
   SDNet_tuple_VALID = 0;

   case(state)
     /* wait to complete first cycle of packet */
     FIRST: begin
         if (SUME_axis_tvalid & SUME_axis_tready) begin
             SDNet_tuple_VALID = 1;
             state_next = WAIT;
         end
     end

     /* wait until last cycle of packet */
     WAIT: begin
         if (SUME_axis_tvalid & SUME_axis_tlast & SUME_axis_tready) begin
             state_next = FIRST;
         end
     end // case: WAIT

   endcase // case(state)
end // always @ (*)


always @(posedge axis_aclk) begin
   if(~axis_resetn) begin
      state <= FIRST;
   end
   else begin
      state <= state_next;
   end
end


// the SDNet_TLAST signal should only go high when TVALID is high
assign SDNet_axis_TLAST = SUME_axis_tvalid & SUME_axis_tlast;

endmodule // sume_to_sdnet

