TOP=../../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=netfpga ## Select the platform. Try make -C platforms ls
ARCH=xilinx_stream_switch ## Select the architecture
TARGET_SUPPORTS=PACKET_MOD
# TOPLEVEL_NAME=scion ## Name of the TODO what exactly is it?


# Clean up whitespace (grr)
PLATFORM := $(strip $(PLATFORM))
ARCH     := $(strip $(ARCH))
# TOPLEVEL_NAME := $(strip $(TOPLEVEL_NAME))

HW = hw
SW = sw/embedded/
TEST = test

### User-facing targets ######################################################

all: ## TODO

build: ## TODO

clean: ## Remove generated files
	make -C ${HW} distclean
	make -C ${SW} distclean
	rm -rfv vivado*

### Targets that actually do stuff ###########################################
