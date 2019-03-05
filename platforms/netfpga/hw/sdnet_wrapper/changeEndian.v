//-
// Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
//                          Junior University
// Copyright (C) 2010, 2011 Adam Covington
// Copyright (C) 2015 Noa Zilberman
// All rights reserved.
//
// This software was developed by
// Stanford University and the University of Cambridge Computer Laboratory
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
/*******************************************************************************
 *  File:
 *        changeEndian.v
 *
 *  Module:
 *        changeEndian.v
 *
 *  Author:
 *        Stephen Ibanez
 * 		
 *  Description:
 *        Change the endianness of a bus.
 *        NOTE: Currently the WIDTH must be a multiple of 8!! 
 *
 */

module changeEndian
#( 
    parameter WIDTH = 64
)
(
   input       [WIDTH-1:0]   in_bus,
   output      [WIDTH-1:0]   out_bus 
); 

localparam PAD_WIDTH = ((WIDTH % 8) == 0) ? 0 : 8-(WIDTH % 8);

// pad the input to make it an integer number of bytes
wire [WIDTH+PAD_WIDTH-1:0] padded_in_bus;
assign padded_in_bus = {{PAD_WIDTH{1'b0}}, in_bus};

reg [WIDTH+PAD_WIDTH-1:0] padded_out_bus;

integer ii;

always @ (*) begin
    // reverse the byte order
    for (ii = WIDTH + PAD_WIDTH; ii > 0; ii=ii-8) begin
        padded_out_bus[ii-1 -: 8] = padded_in_bus[(WIDTH+PAD_WIDTH)-ii+7 -: 8];
    end
end

assign out_bus = padded_out_bus[WIDTH-1:0];
  
endmodule
