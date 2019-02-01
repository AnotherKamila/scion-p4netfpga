TOP=../..
include $(TOP)/Makefile.inc

.PHONY: help clean listarchs ls

listarchs: ## List supported architectures
	@for p in `find . -mindepth 1 -maxdepth 1 -type d`; do basename $$p; done

ls: listarchs ## Shorthand for listarchs


# Makefile to convert the P4 into PX and P4 commands into SDNet tables

MAIN=./main.p4
SDNET_NAME=scion

.PHONY: help clean

all: ## Compile for SDNet
	p4c-sdnet -o $(SDNET_NAME).sdnet --sdnet_info .sdnet_switch_info.dat $(MAIN)
	${SUME_SDNET}/bin/p4_px_tables.py commands.txt .sdnet_switch_info.dat

clean: ## Remove generated files
	rm -f *.sdnet *.tbl .sdnet_switch_info.dat

