# TODO make this Makefile less implicit and tightly coupled with gendata and other Makefiles and everything
TOP=..
include $(TOP)/Makefile.inc

all: gen ## Generate test data

gen: Packet_in.axi Packet_expect.axi ## Generate test data

send: gen ## Send packets to network interfaces and capture the responses
	./apply_and_capture.sh

check: ## Check that the actual packets match the expected ones
	./check_captured.sh

test: send check ## Send, capture and diff packets

%.pcap: $(shell find . -name '*.py')
	./gen_testdata.py

Packet_%.axi: %.pcap
	$(SUME_SDNET)/bin/pcap2axi --output $@ --bus_width 256 $<

clean: clean-gitignore ## Remove generated files
