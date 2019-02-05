TOP=../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=netfpga ## Select the platform. Try make -C platforms ls
ARCH=simple_sume_switch ## Select the architecture
# TOPLEVEL_NAME=scion ## Name of the TODO what exactly is it?

# Clean up whitespace (grr)
PLATFORM := $(strip $(PLATFORM))
ARCH     := $(strip $(ARCH))
# TOPLEVEL_NAME := $(strip $(TOPLEVEL_NAME))

### User-facing targets ######################################################

.PHONY: help all listarchs ls build sdnet clean find-all-target-supports

all: ## TODO

listarchs: ## List supported architectures
	@for p in `find . -mindepth 1 -maxdepth 1 -type d`; do basename $$p; done

ls: listarchs ## Shorthand for listarchs

build: sdnet ## TODO

sdnet: (basename $(MAIN)).sdnet ## Compile for SDNet

clean: ## Remove generated files
	rm -f *.sdnet *.tbl .sdnet_switch_info.dat

compiler-test: compiler-test-$(ARCH).sdnet ## Compile a test program to check support for P4 features
	@echo $(MARK) "Compiled successfully. Today is your lucky day!" $(ENDMARK)

### Targets that actually do stuff ###########################################

%.sdnet: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet -o $@ --sdnet_info .sdnet_switch_info-%.dat -I$(TOP)/$(INCDIR) $<

# TODO think about and enable when commands become useful
# commands:
# ${SUME_SDNET}/bin/p4_px_tables.py commands.txt .sdnet_switch_info.dat
