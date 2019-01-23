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


# Makefile to convert the P4 into PX and P4 commands into SDNet tables

MAIN=./main.p4
MAIN_V1MODEL=./main-v1model.p4
SDNET_NAME=scion

.PHONY: help clean

help:  # stolen from marmelab.com/blog/2016/02/29/auto-documented-makefile.html
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-10s %s\n", $$1, $$2}'

all: ## Compile for SDNet
	p4c-sdnet -o $(SDNET_NAME).sdnet --sdnet_info .sdnet_switch_info.dat $(MAIN)
	${SUME_SDNET}/bin/p4_px_tables.py commands.txt .sdnet_switch_info.dat

v1model: ## Compile with the P4 reference model (outputs a switch-emulating executable)
	p4c --target bmv2 --arch v1model --std p4-16 $(MAIN_V1MODEL)

clean: ## Removes generated files
	rm -f *.sdnet *.tbl .sdnet_switch_info.dat
	rm -f *.json *.p4i

