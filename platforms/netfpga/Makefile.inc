### User Settings ##############################
PLATFORM=netfpga
ARCH=xilinx_stream_switch ## Select the architecture

# Clean up whitespace from self-documenting vars
ARCH := $(strip $(ARCH))

### Compilation settings #######################
# Do not change just for fun:
# other parts of the build process depend on them

HDL_MODULE_NAME=Scion
SCION_IP_NAME=nf_sume_sdnet_ip

HW=hw
SW=sw
ARCH_HW=$(ARCH)/hw
WORKDIR=$(ARCH)/work
EXTERNS=$(WORKDIR)/externs
BITFILES_DIR=$(HW)/bitfiles

SCION_IP_DIR=$(WORKDIR)/$(SCION_IP_NAME)
GENERATED_HDL=$(SCION_IP_DIR)/$(HDL_MODULE_NAME)
GENERATED_HDL_TOP=$(GENERATED_HDL)/$(HDL_MODULE_NAME).v
SDNET_WRAPPER=$(HW)/sdnet_wrapper
EXTERN_TEMPLATES=$(HW)/externs

SWITCHINFO=$(ARCH)/sdnet_switch.info
SDNET_TOP=$(ARCH)/$(HDL_MODULE_NAME).sdnet
BITFILE=$(BITFILES_DIR)/$(HDL_MODULE_NAME).bit
