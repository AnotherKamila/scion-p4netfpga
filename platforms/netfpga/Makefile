TOP=../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=netfpga ## Select the platform. Try make -C platforms ls
ARCH=xilinx_stream_switch ## Select the architecture
MODULE_NAME=Scion ## Name of the HDL module
include $(strip $(ARCH))/Makefile.inc

# Clean up whitespace (grr)
PLATFORM    := $(strip $(PLATFORM))
ARCH        := $(strip $(ARCH))
MODULE_NAME := $(strip $(MODULE_NAME))

# Settings that usually shouldn't be changed by the user
SDNET_MODULE_NAME=scion_sdnet_ip
SWITCHINFO=$(ARCH)/sdnet_switch.info
HW=$(ARCH)/hw
WORKDIR=$(ARCH)/work
SDNET_OUT_DIR=$(WORKDIR)/$(SDNET_MODULE_NAME)
IP_CORES_DIR=$(HW)/lib/cores
WRAPPER=$(HW)/wrapper
COMMON_HW=hw
BITFILES=$(HW)/bitfiles/
BITFILE=$(BITFILES)/$(MODULE_NAME).bit

# Important: With these flags, sdnet will complain unless you're using at least
# one table. It must be actually used, not just declared. Reason: if you aren't,
# it won't generate control ports and the -singlecontrolport flag makes it
# angry.
# Also: We need to -skipEval because eval is broken and doesn't link :D
SDNET_FLAGS=-busType axi -busWidth 256 -singlecontrolport -altVivadoScripts -skipEval

# paths determined by sdnet
SDNET_GENERATED=$(SDNET_OUT_DIR)/$(MODULE_NAME)
SDNET_GENERATED_VERILOG=$(SDNET_GENERATED)/$(MODULE_NAME).v

# TODO this makefile will need a *lot* of cleanup :D

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

build: synth hdl ## Build everything needed for using the design

hwtest: ## Test the real hardware
	make -C $(TOP)/test test

sim: hdl ## Verify the design and run simulations.
	make -C $(TOP)/test gen
	cp $(TOP)/test/*.txt $(SDNET_GENERATED)
	cp $(TOP)/test/*.axi $(SDNET_GENERATED)
	$(SUME_SDNET)/bin/p4_px_tables.py $(TOP)/test/commands.txt $(SWITCHINFO)
	cp *.tbl $(SDNET_GENERATED)
	# ${SUME_SDNET}/bin/gen_P4_SWITCH_externs.py $(SWITCHINFO) $(SDNET_GENERATED) ${SUME_SDNET}/templates/ $(TOP)/testdata/ $(ARCH)/sw/ --base_address ${P4_SWITCH_BASE_ADDR}
	# modify the P4_SWITCH_tb so that it writes the table config writes to a file
	$(SUME_SDNET)/bin/modify_P4_SWITCH_tb.py $(SDNET_GENERATED)/Testbench/$(MODULE_NAME)_tb.sv

	cd $(SDNET_OUT_DIR)/$(MODULE_NAME) && ./vivado_sim.bash

# TODO figure out how to handle this withour remaking
# $(SDNET_GENERATED)/config_writes.txt: vivado_sim

# $(ARCH)/config_writes.py: $(SDNET_GENERATED)/config_writes.txt
# 	${SUME_SDNET}/bin/gen_config_writes.py $< $(P4_SWITCH_BASE_ADDR) $(TOP)/testdata
# 	# mv $(TOP)/testdata/config_writes.py $@

# sume_sim: $(ARCH)/config_writes.py
# 	make -C $(TOP)/testdata all
# 	# cp $< $(ARCH)/test/sim_switch_default
# 	$(SUME_FOLDER)/tools/scripts/nf_test.py sim --src_test_dir $(ARCH)/test --major switch --minor default

$(ARCH)/config_writes.sh: $(SDNET_GENERATED)/config_writes.txt
	${SUME_SDNET}/bin/gen_config_writes.py $< $(P4_SWITCH_BASE_ADDR) $(TOP)/test
	cp $(TOP)/test/config_writes.sh $@

project: hdl ## Create the design (Vivado project)
	make -C $(HW)/nf_sume project  # TODO some genius put the synth into this -- split this!
	# make -C $(HW)/nf_sume export_to_sdk
	# make -C ${SW} project
	# make -C ${SW} compile
	# make -C $(HW)/nf_sume load_elf


# synth: project ## Synth the design and generate the bitfile
synth: $(ARCH)/config_writes.sh ## Synth the design and generate the bitfile
	# TODO move synth here
	# TODO actually bitfiles should probably be a separate step
	mkdir -p $(HW)/bitfiles
	# TODO when this has the bitfile as dependency, it could be move
	cp $(HW)/nf_sume/project/nf_sume.runs/impl_1/top.bit $(BITFILE)

# TODO config_writes won't be needed once we have a control plane :D
# unless we want to have a default route without control plane
flash: _env _root $(BITFILE) $(ARCH)/config_writes.sh ## Program the NetFPGA
	bash ./scripts/program_switch.sh $(BITFILE)
	bash $(ARCH)/config_writes.sh

# TODO move to top .inc
# TODO merge with gmake
_env:
	@which vivado || { echo "ERROR: Xilinx tools not in PATH, source something like /opt/Xilinx/Vivado/2018.2/settings64.sh"; exit 78; }

_root:
	@[ `id -u` = 0 ] || { echo "ERROR: You must be root to run this target. (Don't forget to setup the env!)"; exit 77; }

# TODO:
# clean:
# 	make -C ${HW} distclean
#   make -C ${SW} distclean
#   rm -rfv vivado*;\

sdnet: $(ARCH)/$(MODULE_NAME).sdnet ## Compile for SDNet

hdl: $(SDNET_GENERATED_VERILOG) ## Generate HDL

wrap_core: hdl ## Wrap the Scion module and create a Vivado library core
	mkdir -p $(IP_CORES_DIR)
	cp -r $(SDNET_GENERATED) $(IP_CORES_DIR)

TARGET=$(SUME_FOLDER)/lib/hw/contrib/cores
install_sdnet: hdl uninstall_sdnet ## TEMPORARY, should be replaced with wrap_core
	cp -r $(SDNET_OUT_DIR) $(TARGET)
	mkdir -p $(TARGET)/$(SDNET_MODULE_NAME)/wrapper
	cp $(HW)/wrapper/hdl/* $(TARGET)/$(SDNET_MODULE_NAME)/wrapper
	cp $(HW)/wrapper/tcl/* $(TARGET)/$(SDNET_MODULE_NAME)
	cp $(HW)/wrapper/Makefile $(TARGET)/$(SDNET_MODULE_NAME)
	$(MAKE) -C $(TARGET)/$(SDNET_MODULE_NAME)

uninstall_sdnet: ## TEMPORARY, should be replaced with um something
	rm -rf $(TARGET)/$(SDNET_MODULE_NAME)

compiler-test: compiler-test-$(ARCH).sdnet ## Compile a test program to check support for P4 features

$(ARCH)/$(MODULE_NAME).sdnet: $(basename $(MAIN)).sdnet
	cp $< $@

%.sdnet: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet --toplevel_name $(MODULE_NAME) -o $@ --sdnet_info $(SWITCHINFO) $(TARGET_DEFINES) -I$(TOP)/$(INCDIR) $<
	@echo $(MARK) "Compiled successfully. Today is your lucky day!" $(ENDMARK)




$(SDNET_GENERATED_VERILOG): $(ARCH)/$(MODULE_NAME).sdnet
	sdnet $< $(SDNET_FLAGS) -workDir $(SDNET_OUT_DIR)

	# SDNet is apparently incompatible with its own output :D
	sed -i 's/xsim\.dir\/xsc\/dpi\.so/dpi\.so/g' $(SDNET_GENERATED)/vivado_sim*.bash
	sed -i 's/glbl_sim/glbl/g' $(SDNET_GENERATED)/vivado_sim_waveform.bash
	sed -i 's/$(MODULE_NAME)_tb_sim#work.glbl/$(MODULE_NAME)_tb/g' $(SDNET_GENERATED)/vivado_sim_waveform.bash

	# fix for ubuntu
	# sed -i 's/vsim/vsim \-ldflags \"\-B\/usr\/lib\/x86\_64\-linux-gnu\"/g' $(SDNET_GENERATED)/questa.bash

	@echo $(MARK) "Generated HDL in $(SDNET_GENERATED)" $(ENDMARK)

# clean: ## Remove generated files
# 	rm -f *.sdnet $(ARCH)/*.sdnet *.tbl $(SWITCHINFO)
# 	rm -rf $(SDNET_OUT_DIR)
# 	make -C $(HW)/nf_sume clean
