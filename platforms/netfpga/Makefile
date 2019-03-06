# TODO this makefile will need a *lot* of cleanup :D

TOP=../..
include $(TOP)/Makefile.inc

### Settings ###################################

include Makefile.inc
include $(ARCH)/Makefile.inc

# Important: With these flags, sdnet will complain unless you're using at least
# one table. It must be actually used, not just declared. Reason: if you aren't,
# it won't generate control ports and the -singlecontrolport flag makes it
# angry.
# Also: We need to -skipEval because eval is broken and doesn't link :D
SDNET_FLAGS=-busType axi -busWidth 256 -singlecontrolport -altVivadoScripts -skipEval


### User-facing targets ########################

# TEMPORARY, TODO put me back
#ARCHS=$(shell find . -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
ARCHS=xilinx_stream_switch
# TODO if I make it a habit to define ARCHS, I can move the listarchs target into $(TOP)/Makefile.inc

.PHONY: help all listarchs ls build sdnet clean find-all-target-supports

all: build test ## TODO: Prepare and verify everything needed for programming the NetFPGA

listarchs: ## List supported architectures
	@echo $(ARCHS)

ls: listarchs ## Shorthand for listarchs

build: ## TODO: Build everything needed for using the design
	make -C $(HW) build

compiler-test: compiler-test-$(ARCH).sdnet ## Compile a test program to check support for P4 features

sdnet: $(SDNET_TOP) ## Compile for SDNet

hdl: $(GENERATED_HDL_TOP) ## Generate SCION HDL module

test: sim ## Alias for sim

hwtest: ## Test the real hardware (TODO maybe shouldn't be here?)
	$(MAKE) -C $(TOP)/test test

### Targets that actually do stuff #############

$(SDNET_TOP): $(basename $(MAIN)).sdnet
	cp $< $@

%.sdnet: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet --toplevel_name $(HDL_MODULE_NAME) -o $@ --sdnet_info $(SWITCHINFO) $(TARGET_DEFINES) -I$(TOP)/$(INCDIR) $<
	@echo $(MARK) "Compiled successfully. Today is your lucky day!" $(ENDMARK)

$(GENERATED_HDL_TOP): $(SDNET_TOP)
	sdnet $< $(SDNET_FLAGS) -workDir $(SCION_IP_DIR)
	# SDNet is apparently incompatible with its own output :D
	sed -i 's/xsim\.dir\/xsc\/dpi\.so/dpi\.so/g' $(GENERATED_HDL)/vivado_sim*.bash
	sed -i 's/glbl_sim/glbl/g' $(GENERATED_HDL)/vivado_sim_waveform.bash
	sed -i 's/$(HDL_MODULE_NAME)_tb_sim#work.glbl/$(HDL_MODULE_NAME)_tb/g' $(GENERATED_HDL)/vivado_sim_waveform.bash
	# fix for ubuntu
	# sed -i 's/vsim/vsim \-ldflags \"\-B\/usr\/lib\/x86\_64\-linux-gnu\"/g' $(GENERATED_HDL)/questa.bash
	@echo $(MARK) "Generated HDL in $(GENERATED_HDL)" $(ENDMARK)

sim: hdl _env ## Run a behavioural simulation for the SCION module
	make -C $(TOP)/test gen
	cp $(TOP)/test/*.txt $(GENERATED_HDL)
	cp $(TOP)/test/*.axi $(GENERATED_HDL)
	$(SUME_SDNET)/bin/p4_px_tables.py $(TOP)/test/commands.txt $(SWITCHINFO)
	cp *.tbl $(GENERATED_HDL)
	# ${SUME_SDNET}/bin/gen_P4_SWITCH_externs.py $(SWITCHINFO) $(GENERATED_HDL) ${SUME_SDNET}/templates/ $(TOP)/testdata/ $(ARCH)/sw/ --base_address ${P4_SWITCH_BASE_ADDR}
	# modify the P4_SWITCH_tb so that it writes the table config writes to a file
	$(SUME_SDNET)/bin/modify_P4_SWITCH_tb.py $(GENERATED_HDL)/Testbench/$(HDL_MODULE_NAME)_tb.sv
	cd $(GENERATED_HDL) && ./vivado_sim.bash

# TODO figure out how to handle this withour remaking
# $(GENERATED_HDL)/config_writes.txt: vivado_sim

# $(ARCH)/config_writes.py: $(GENERATED_HDL)/config_writes.txt
# 	${SUME_SDNET}/bin/gen_config_writes.py $< $(P4_SWITCH_BASE_ADDR) $(TOP)/testdata
# 	# mv $(TOP)/testdata/config_writes.py $@

$(WORKDIR)/config_writes.sh: $(SDNET_GENERATED)/config_writes.txt
	${SUME_SDNET}/bin/gen_config_writes.py $< $(P4_SWITCH_BASE_ADDR) $(TOP)/test
	cp $(TOP)/test/config_writes.sh $@

clean: clean-gitignore ## Remove generated files
	$(MAKE) -C $(HW) clean
#	$(MAKE) -C $(SW) clean
