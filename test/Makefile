TOP=..
include $(TOP)/Makefile.inc

all: gen ## Generate test data

gen: Packet_in.axi Packet_expect.axi ## Generate test data

send: gen ## Send packets to network interfaces and capture the responses
	./apply_and_capture.sh

check: ## Check that the actual packets match the expected ones
	./check_captured.sh

test: send check ## Send, capture and diff packets

%.pcap: ./gen_testdata.py
	./gen_testdata.py

Packet_%.axi: %.pcap
	$(SUME_SDNET)/bin/pcap2axi --output $@ --bus_width 256 $<
