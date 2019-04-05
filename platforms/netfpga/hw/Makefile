TOP=../../..
include $(TOP)/Makefile.inc

### Settings #################################################################
include ../Makefile.inc
include ../$(ARCH)/Makefile.inc

# path overrides
# this is a bit ugly, but... ¯\_(ツ)_/¯
HW           = .
SW           = ../sw
ARCH_HW      = ../$(ARCH)/hw
WORKDIR      = ../$(ARCH)/work

### User-facing targets ######################################################

.PHONY: help all build design clean

all: ## TODO

build: $(BITFILE) ## TODO Build everything needed for using the design

# project: hdl ## Create the design (Vivado project)
# 	make -C $(HW)/nf_sume project  # TODO some genius put the synth into this -- split this!
# 	# make -C $(HW)/nf_sume export_to_sdk
# 	# make -C ${SW} project
# 	# make -C ${SW} compile
# 	# make -C $(HW)/nf_sume load_elf

test: sim ## Alias for sim

# # synth: project ## Synth the design and generate the bitfile
# synth: $(ARCH)/config_writes.sh ## Synth the design and generate the bitfile
# 	# TODO move synth here
# 	# TODO actually bitfiles should probably be a separate step
# 	mkdir -p $(HW)/bitfiles
# 	# TODO when this has the bitfile as dependency, it could be move
# 	cp $(HW)/nf_sume/project/nf_sume.runs/impl_1/top.bit $(BITFILE)

design: scion_ip ## TODO Create the design for the NetFPGA board
	mkdir -p $(SW)/embedded/src/
	make -C nf_sume project SDNET_IP_DIR=../$(SCION_IP_DIR)
	# make -C nf_sume export_to_sdk
	# make -C nf_sume load_elf

spacetime:
	@echo "--- Utilisation report ---"
	@cat nf_sume/project/nf_sume.runs/impl_1/top_utilization_placed.rpt
	@echo "--- Timing report ---"
	@cat nf_sume/project/nf_sume.runs/impl_1/top_timing_summary_postroute_physopted.rpt

# TODO split the actual target that checks whether it's built
scion_ip: $(GENERATED_HDL_TOP) ## Create and package the SCION IP core
	cd $(SDNET_WRAPPER) && env                     \
		IP_DIR=../$(SCION_IP_DIR)                    \
		ARCH_WRAPPER=../$(ARCH_HW)/nf_sume_sdnet.v   \
		HDL_MODULE_NAME=$(HDL_MODULE_NAME)           \
		vivado -mode batch -source nf_sume_sdnet.tcl


# TODO config_writes won't be needed once we have a control plane :D
# unless we want to have a default route without control plane
flash: _env _root $(BITFILE) $(WORKDIR)/config_writes.sh ## Program the NetFPGA
	bash ../scripts/program_switch.sh $(BITFILE)
	bash $(WORKDIR)/config_writes.sh

### Targets that actually do stuff #############

# sume_sim: $(ARCH)/config_writes.py
# 	make -C $(TOP)/testdata all
# 	# cp $< $(ARCH)/test/sim_switch_default
# 	$(SUME_FOLDER)/tools/scripts/nf_test.py sim --src_test_dir $(ARCH)/test --major switch --minor default

# synth: project ## Synth the design and generate the bitfile
synth: $(ARCH)/config_writes.sh ## Synth the design and generate the bitfile
	# TODO move synth here
	# TODO actually bitfiles should probably be a separate step
	mkdir -p $(HW)/bitfiles
	# TODO when this has the bitfile as dependency, it could be move
	cp $(HW)/nf_sume/project/nf_sume.runs/impl_1/top.bit $(BITFILE)

$(BITFILE): design
	mkdir -p $(BITFILES_DIR)
	cp $(HW)/nf_sume/project/nf_sume.runs/impl_1/top.bit $(BITFILE)

$(GENERATED_HDL_TOP):
	make -C .. hdl

clean: clean-gitignore ## Remove generated files
	make -C nf_sume distclean
#	make -C ${SW} distclean
#	rm -rfv vivado*;\
