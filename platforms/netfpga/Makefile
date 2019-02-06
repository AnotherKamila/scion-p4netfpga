TOP=../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=netfpga ## Select the platform. Try make -C platforms ls
ARCH=xilinx_stream_switch ## Select the architecture
# TOPLEVEL_NAME=scion ## Name of the TODO what exactly is it?
include $(strip $(ARCH))/Makefile.inc

# Clean up whitespace (grr)
PLATFORM := $(strip $(PLATFORM))
ARCH     := $(strip $(ARCH))
# TOPLEVEL_NAME := $(strip $(TOPLEVEL_NAME))

### User-facing targets ######################################################

ARCHS=$(shell find . -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

.PHONY: help all listarchs ls build sdnet clean find-all-target-supports

all: ## TODO

listarchs: ## List supported architectures
	@echo $(ARCHS)

ls: listarchs ## Shorthand for listarchs

build: sdnet ## TODO

test: build ## TODO

sdnet: $(basename $(MAIN)).sdnet ## Compile for SDNet

clean: ## Remove generated files
	rm -f *.sdnet *.tbl .sdnet_switch_info.dat

compiler-test: compiler-test-$(ARCH).sdnet ## Compile a test program to check support for P4 features

%.sdnet: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet -o $@ --sdnet_info .sdnet_switch_info-%.dat $(TARGET_DEFINES) -I$(TOP)/$(INCDIR) $<
	@echo $(MARK) "Compiled successfully. Today is your lucky day!" $(ENDMARK)

# TODO think about and enable when commands become useful
# commands:
# ${SUME_SDNET}/bin/p4_px_tables.py commands.txt .sdnet_switch_info.dat
