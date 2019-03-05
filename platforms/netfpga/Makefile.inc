### User Settings ##############################
PLATFORM=netfpga
ARCH=xilinx_stream_switch ## Select the architecture

# Clean up whitespace from self-documenting vars
ARCH := $(strip $(ARCH))

### Compilation settings #######################
# Do not change just for fun:
# other parts of the build process depend on them

HDL_MODULE_NAME=Scion

HW=hw
ARCH_HW=$(ARCH)/hw
WORKDIR=$(ARCH)/work
BITFILES_DIR=$(HW)/bitfiles

SWITCHINFO=$(ARCH)/sdnet_switch.info
SDNET_TOP=$(HDL_MODULE_NAME).sdnet

GENERATED_HDL=$(WORKDIR)/$(HDL_MODULE_NAME)
GENERATED_HDL_TOP=$(GENERATED_HDL)/$(HDL_MODULE_NAME).v
BITFILE=$(BITFILES_DIR)/$(HDL_MODULE_NAME).bit
