TOP=../../..
include $(TOP)/Makefile.inc

### Settings #################################################################
include Makefile.inc

# Clean up whitespace (grr)
PLATFORM := $(strip $(PLATFORM))
ARCH     := $(strip $(ARCH))
# TOPLEVEL_NAME := $(strip $(TOPLEVEL_NAME))

### User-facing targets ######################################################

all: ## TODO

build: ## TODO

clean: ## Remove generated files
	make -C ${HW} distclean
	make -C ${SW} distclean
	rm -rfv vivado*

### Targets that actually do stuff ###########################################

