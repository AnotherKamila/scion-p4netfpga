TOP=../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=netfpga ## Select the platform. Try make -C platforms ls
ARCH=xilinx_stream_switch ## Select the architecture
SYSTEM_NAME=Scion ## Name of the HDL module
include $(strip $(ARCH))/Makefile.inc

# Clean up whitespace (grr)
PLATFORM    := $(strip $(PLATFORM))
ARCH        := $(strip $(ARCH))
SYSTEM_NAME := $(strip $(SYSTEM_NAME))

# Settings that usually shouldn't be changed by the user
SDNET_OUT_DIR=$(ARCH)/scion_module
SWITCHINFO=$(ARCH)/sdnet_switch.info

SDNET_FLAGS=-busType axi -busWidth 256 -altVivadoScripts -skipEval

# paths determined by sdnet
SDNET_GENERATED=$(SDNET_OUT_DIR)/$(SYSTEM_NAME)
SDNET_GENERATED_VERILOG=$(SDNET_GENERATED)/$(SYSTEM_NAME).v

### User-facing targets ######################################################

# TEMPORARY, TODO put me back
#ARCHS=$(shell find . -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
ARCHS=xilinx_stream_switch
# TODO if I make it a habit to define ARCHS, I can move the listarchs target into $(TOP)/Makefile.inc

.PHONY: help all listarchs ls build sdnet clean find-all-target-supports

all: ## TODO

listarchs: ## List supported architectures
	@echo $(ARCHS)

ls: listarchs ## Shorthand for listarchs

build: hdl ## Build everything needed for using the design

test: build ## Verify the design and run simulations.
	cd $(SDNET_OUT_DIR)/$(SYSTEM_NAME) && ./vivado_sim.bash

sdnet: $(ARCH)/$(SYSTEM_NAME).sdnet ## Compile for SDNet

hdl: $(SDNET_GENERATED_VERILOG) ## Generate HDL

clean: ## Remove generated files
	rm -f *.sdnet $(ARCH)/*.sdnet *.tbl $(SWITCHINFO)
	rm -rf $(SDNET_OUT_DIR)

compiler-test: compiler-test-$(ARCH).sdnet ## Compile a test program to check support for P4 features

$(ARCH)/$(SYSTEM_NAME).sdnet: $(basename $(MAIN)).sdnet
	cp $< $@

%.sdnet: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet --toplevel_name $(SYSTEM_NAME) -o $@ --sdnet_info $(SWITCHINFO) $(TARGET_DEFINES) -I$(TOP)/$(INCDIR) $<
	@echo $(MARK) "Compiled successfully. Today is your lucky day!" $(ENDMARK)

# TODO think about and enable when commands become useful
# commands:
# ${SUME_SDNET}/bin/p4_px_tables.py commands.txt .sdnet_switch_info.dat

$(SDNET_GENERATED_VERILOG): $(ARCH)/$(SYSTEM_NAME).sdnet
	sdnet $< $(SDNET_FLAGS) -workDir $(SDNET_OUT_DIR)
	sed -i 's/xsim\.dir\/xsc\/dpi\.so/dpi\.so/g' $(SDNET_GENERATED)/vivado_sim*.bash  # SDNet is apparently incompatible with its own output :D
	@echo $(MARK) "Generated HDL in $(SDNET_GENERATED)" $(ENDMARK)

