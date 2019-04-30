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

.PHONY: help all listarchs ls build sdnet spacetime bigbang clean find-all-target-supports sim simgui

all: build test ## TODO: Prepare and verify everything needed for programming the NetFPGA

compiler-test: compiler-test-$(ARCH).sdnet ## Compile a test program to check support for P4 features

build: ## TODO: Build everything needed for using the design
	make -C $(HW) build
	@echo $(MARK) "Utilisation and timing summary:" $(ENDMARK)
	@$(MAKE) --no-print-directory spacetime

sdnet: $(SDNET_TOP) ## Compile for SDNet

hdl: $(GENERATED_HDL_TOP) ## Generate SCION HDL module

sim: $(GENERATED_HDL)/.sim-built ## Run a behavioural simulation for the SCION module
	cd $(GENERATED_HDL) && ./vivado_sim.bash

simgui: $(GENERATED_HDL)/.sim-built ## Open the Vivado GUI with a behavioural simulation for the SCION module
	cd $(GENERATED_HDL) && ./vivado_sim_waveform.bash

test: sim ## Alias for sim

hwtest: ## Test the real hardware (TODO maybe shouldn't be here?)
	$(MAKE) -C $(TOP)/test test

spacetime: ## Check the area utilisation and timing of the built design.
	@$(MAKE) --no-print-directory _spacetime | column -t -s'|'
	@echo 'Run `make -C $(HW) spacetime` to see the full report.'

bigbang: spacetime # O:-)

listarchs: ## List supported architectures
	@echo $(ARCHS)

ls: listarchs ## Shorthand for listarchs

clean: clean-gitignore ## Remove generated files
	$(MAKE) -C $(HW) clean
#	$(MAKE) -C $(SW) clean

### Targets that actually do stuff #############

$(SDNET_TOP): $(basename $(MAIN)).sdnet
	cp $< $@

%.sdnet: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c-sdnet --toplevel_name $(HDL_MODULE_NAME) -o $@ --sdnet_info $(SWITCHINFO) $(TARGET_DEFINES) $(EXTRA_DEFINES) -I$(TOP)/$(INCDIR) $<
	@echo $(MARK) "Compiled successfully. Today is your lucky day!" $(ENDMARK)

SIM_ADD_VHDL=find -name PKG_*.vhd | { xargs -I % ${XILINX_VIVADO}/bin/xvhdl % ; }\nfind -name *.vhd | { xargs -I % ${XILINX_VIVADO}/bin/xvhdl % ; }
$(GENERATED_HDL_TOP): $(SDNET_TOP) $(EXTERNS)/.built
	sdnet $< $(SDNET_FLAGS) -workDir $(SCION_IP_DIR)
	# SDNet is apparently incompatible with its own output :D
	sed -i 's/xsim\.dir\/xsc\/dpi\.so/dpi\.so/g' $(GENERATED_HDL)/vivado_sim*.bash
	sed -i 's/glbl_sim/glbl/g' $(GENERATED_HDL)/vivado_sim_waveform.bash
	sed -i 's/$(HDL_MODULE_NAME)_tb_sim#work.glbl/$(HDL_MODULE_NAME)_tb/g' $(GENERATED_HDL)/vivado_sim_waveform.bash
	# fix for ubuntu
	# sed -i 's/vsim/vsim \-ldflags \"\-B\/usr\/lib\/x86\_64\-linux-gnu\"/g' $(GENERATED_HDL)/questa.bash
	# also enable VHDL files
	awk '/xvlog/ { print; print "$(SIM_ADD_VHDL)"; next }1' < $(GENERATED_HDL)/vivado_sim.bash > $(GENERATED_HDL)/vivado_sim.bash.tmp
	awk '/xvlog/ { print; print "$(SIM_ADD_VHDL)"; next }1' < $(GENERATED_HDL)/vivado_sim_waveform.bash > $(GENERATED_HDL)/vivado_sim_waveform.bash.tmp
	mv $(GENERATED_HDL)/vivado_sim.bash.tmp $(GENERATED_HDL)/vivado_sim.bash
	mv $(GENERATED_HDL)/vivado_sim_waveform.bash.tmp $(GENERATED_HDL)/vivado_sim_waveform.bash
	chmod a+x $(GENERATED_HDL)/vivado_sim*.bash
	$(SUME_SDNET)/bin/gen_P4_SWITCH_externs.py $(SWITCHINFO) $(GENERATED_HDL) $(SUME_SDNET)/templates $(TOP)/test/ $(ARCH)/sw/ --base_address $(P4_SWITCH_BASE_ADDR)
	@echo $(MARK) "Generated HDL in $(GENERATED_HDL)" $(ENDMARK)

$(EXTERNS)/.built: $(shell find $(EXTERN_TEMPLATES))
	mkdir -p $(EXTERNS)
	# TODO this is really terrible, but I'd need to fix their gen_P4_externs.py
	# script to not use hard-coded paths to make it less terrible.
	# Also: note that I still need to define the externs in their script, too.
	for e in `ls -1 $(EXTERN_TEMPLATES)`; do                             \
		rm -rf $(SUME_SDNET)/templates/externs/$$e;                        \
		cp -r $(EXTERN_TEMPLATES)/$$e $(SUME_SDNET)/templates/externs/$$e; \
  done
	touch $@

$(GENERATED_HDL)/.sim-built: $(GENERATED_HDL_TOP)
	make -C $(TOP)/test gen
	cp $(TOP)/test/*.txt $(GENERATED_HDL)
	cp $(TOP)/test/*.axi $(GENERATED_HDL)

	[ -f $(TOP)/test/commands.txt ] && $(MAKE) commandstxt || $(MAKE) notblfiles

	touch $@

########################################################

commandstxt: hdl
	$(SUME_SDNET)/bin/p4_px_tables.py $(TOP)/test/commands.txt $(SWITCHINFO)
	cp *.tbl $(GENERATED_HDL) || true
	# modify the P4_SWITCH_tb so that it writes the table config writes to a file
	$(SUME_SDNET)/bin/modify_P4_SWITCH_tb.py $(GENERATED_HDL)/Testbench/$(HDL_MODULE_NAME)_tb.sv

notblfiles: hdl
	sed -i 's,\(update_[^(]*("[^.]*.tbl");\),// \1,g' $(GENERATED_HDL)/Testbench/$(HDL_MODULE_NAME)_tb.sv

# TODO figure out how to handle this withour remaking
# $(GENERATED_HDL)/config_writes.txt: vivado_sim

# $(ARCH)/config_writes.py: $(GENERATED_HDL)/config_writes.txt
# 	${SUME_SDNET}/bin/gen_config_writes.py $< $(P4_SWITCH_BASE_ADDR) $(TOP)/testdata
# 	# mv $(TOP)/testdata/config_writes.py $@

$(WORKDIR)/config_writes.sh: $(GENERATED_HDL)/config_writes.txt
	$(SUME_SDNET)/bin/gen_config_writes.py $< $(P4_SWITCH_BASE_ADDR) $(TOP)/test
	cp $(TOP)/test/config_writes.sh $@

SPACE_GET_UTIL_PERCENT=cut -d'|' -f2,6 | sed 's/  */ /g' | sed 's/| /|/' | sed 's/ $$/%/'
_space:
	@$(MAKE) -C $(HW) --no-print-directory spacetime | grep '^| Slice LUTs'      | $(SPACE_GET_UTIL_PERCENT)
	@$(MAKE) -C $(HW) --no-print-directory spacetime | grep '^| Slice Registers' | $(SPACE_GET_UTIL_PERCENT)
	@$(MAKE) -C $(HW) --no-print-directory spacetime | grep '^| Block RAM Tile'  | $(SPACE_GET_UTIL_PERCENT)

TIME_GET_COLUMN=$(MAKE) -C $(HW) --no-print-directory spacetime | grep -A10 '^| Design Timing Summary' | \
		grep -v '^$$' | grep -A2 'Failing Endpoints' | sed 's/   */|/g' | cut -d'|' -f  
_time:
	@for i in 4 8 12; do \
		$(TIME_GET_COLUMN) $$i | grep -v -- '---' | tr '\n' '|' ; \
		echo ; \
	done

_spacetime:
	@echo 'Area utilisation summary:'
	@$(MAKE) --no-print-directory _space
	@echo 'Timing summary:'
	@$(MAKE) --no-print-directory _time | sed 's/^/ /'
