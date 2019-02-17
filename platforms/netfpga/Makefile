TOP=../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=netfpga ## Select the platform. Try make -C platforms ls
ARCH=xilinx_stream_switch ## Select the architecture
MODULE_NAME=Scion ## Name of the HDL module
P4_SWITCH_BASE_ADDR=0x44020000
include $(strip $(ARCH))/Makefile.inc

# Clean up whitespace (grr)
PLATFORM    := $(strip $(PLATFORM))
ARCH        := $(strip $(ARCH))
MODULE_NAME := $(strip $(MODULE_NAME))

# Settings that usually shouldn't be changed by the user
SWITCHINFO=$(ARCH)/sdnet_switch.info
HW=$(ARCH)/hw
SDNET_OUT_DIR=$(HW)/scion_module
IP_CORES_DIR=$(HW)/lib/cores
WRAPPER=$(HW)/wrapper

# Important: With these flags, sdnet will complain unless you're using at least
# one table. It must be actually used, not just declared. Reason: if you aren't,
# it won't generate control ports and the -singlecontrolport flag makes it
# angry.
# Also: We need to -skipEval because eval is broken and doesn't link :D
SDNET_FLAGS=-busType axi -busWidth 256 -singlecontrolport -altVivadoScripts -skipEval

# paths determined by sdnet
SDNET_GENERATED=$(SDNET_OUT_DIR)/$(MODULE_NAME)
SDNET_GENERATED_VERILOG=$(SDNET_GENERATED)/$(MODULE_NAME).v

### User-facing targets ######################################################

# TEMPORARY, TODO put me back
#ARCHS=$(shell find . -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
ARCHS=xilinx_stream_switch
# TODO if I make it a habit to define ARCHS, I can move the listarchs target into $(TOP)/Makefile.inc

.PHONY: help all listarchs ls build sdnet clean find-all-target-supports

all: test wrap_core ## Prepare and verify everything needed for programming the NetFPGA

listarchs: ## List supported architectures
	@echo $(ARCHS)

ls: listarchs ## Shorthand for listarchs

build: hdl ## Build everything needed for using the design

test: build ## Verify the design and run simulations.
	make -C $(TOP)/testdata all
	cp $(TOP)/testdata/*.txt $(SDNET_GENERATED)
	cp $(TOP)/testdata/*.axi $(SDNET_GENERATED)
	$(SUME_SDNET)/bin/p4_px_tables.py $(TOP)/testdata/commands.txt $(SWITCHINFO)
	cp *.tbl $(SDNET_GENERATED)
	# ${SUME_SDNET}/bin/gen_P4_SWITCH_externs.py $(SWITCHINFO) $(SDNET_GENERATED) ${SUME_SDNET}/templates/ $(TOP)/testdata/ $(ARCH)/sw/ --base_address ${P4_SWITCH_BASE_ADDR}

	cd $(SDNET_OUT_DIR)/$(MODULE_NAME) && ./vivado_sim.bash

sdnet: $(ARCH)/$(MODULE_NAME).sdnet ## Compile for SDNet

hdl: $(SDNET_GENERATED_VERILOG) ## Generate HDL

wrap_core: hdl ## Wrap the Scion module and create a Vivado library core
	mkdir -p $(IP_CORES_DIR)
	cp -r $(SDNET_GENERATED) $(IP_CORES_DIR)

TARGET=$(SUME_FOLDER)/lib/hw/contrib/cores
install_sdnet: hdl ## TEMPORARY, should be replaced with wrap_core
	cp -r $(SDNET_OUT_DIR) $(TARGET)
	mkdir -p $(TARGET)/scion_module/wrapper
	cp $(HW)/wrapper/hdl/* $(TARGET)/scion_module/wrapper
	cp $(HW)/wrapper/tcl/* $(TARGET)/scion_module
	cp $(HW)/wrapper/Makefile $(TARGET)/scion_module
	make -C $(TARGET)/scion_module

clean: ## Remove generated files
	rm -f *.sdnet $(ARCH)/*.sdnet *.tbl $(SWITCHINFO)
	rm -rf $(SDNET_OUT_DIR)

compiler-test: compiler-test-$(ARCH).sdnet ## Compile a test program to check support for P4 features

$(ARCH)/$(MODULE_NAME).sdnet: $(basename $(MAIN)).sdnet
	cp $< $@

%.sdnet: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet --toplevel_name $(MODULE_NAME) -o $@ --sdnet_info $(SWITCHINFO) $(TARGET_DEFINES) -I$(TOP)/$(INCDIR) $<
	@echo $(MARK) "Compiled successfully. Today is your lucky day!" $(ENDMARK)

# TODO what's this?
config_writes:
	${SUME_SDNET}/bin/gen_config_writes.py $(SDNET_GENERATED)/config_writes.txt $(P4_SWITCH_BASE_ADDR) $(TOP)/testdata



$(SDNET_GENERATED_VERILOG): $(ARCH)/$(MODULE_NAME).sdnet
	sdnet $< $(SDNET_FLAGS) -workDir $(SDNET_OUT_DIR)

	# SDNet is apparently incompatible with its own output :D
	sed -i 's/xsim\.dir\/xsc\/dpi\.so/dpi\.so/g' $(SDNET_GENERATED)/vivado_sim*.bash
	sed -i 's/glbl_sim/glbl/g' $(SDNET_GENERATED)/vivado_sim_waveform.bash
	sed -i 's/$(MODULE_NAME)_tb_sim#work.glbl/$(MODULE_NAME)_tb/g' $(SDNET_GENERATED)/vivado_sim_waveform.bash

	# fix for ubuntu
	# sed -i 's/vsim/vsim \-ldflags \"\-B\/usr\/lib\/x86\_64\-linux-gnu\"/g' $(SDNET_GENERATED)/questa.bash

	@echo $(MARK) "Generated HDL in $(SDNET_GENERATED)" $(ENDMARK)

