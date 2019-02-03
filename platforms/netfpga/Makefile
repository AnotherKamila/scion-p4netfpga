TOP=../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=netfpga ## Select the platform. Try make -C platforms ls
ARCH=simple_sume_switch ## Select the architecture
SDNET_NAME=scion ## Name of the TODO what exactly is it?

# Clean up whitespace (grr)
PLATFORM := $(strip $(PLATFORM))
ARCH     := $(strip $(ARCH))
SDNET_NAME := $(strip $(SDNET_NAME))

### User-facing targets ######################################################

.PHONY: help all listarchs ls build sdnet clean

all: ## TODO

listarchs: ## List supported architectures
	@for p in `find . -mindepth 1 -maxdepth 1 -type d`; do basename $$p; done

ls: listarchs ## Shorthand for listarchs

build: sdnet ## TODO

sdnet: $(SDNET_NAME).sdnet ## Compile for SDNet

compilertest: compilertest.sdnet ## Compile a simple test program to check whether important features work

clean: ## Remove generated files
	rm -f *.sdnet *.tbl .sdnet_switch_info.dat

### Targets that actually do stuff ###########################################

$(SDNET_NAME).sdnet: $(TOP)/$(SRCDIR)/$(MAIN) $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet -o $(SDNET_NAME).sdnet --sdnet_info .sdnet_switch_info.dat -I$(TOP)/$(INCDIR) $<
	# TODO think about and enable when commands become useful
	# ${SUME_SDNET}/bin/p4_px_tables.py commands.txt .sdnet_switch_info.dat

# TODO merge with previous rule
compilertest.sdnet: $(TOP)/$(INCDIR)/compat/sdnet-compiler-test.p4
	p4c-sdnet -o $@ --sdnet_info .sdnet_switch_info.dat -I$(TOP)/$(INCDIR) $<
