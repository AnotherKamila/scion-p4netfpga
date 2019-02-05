# TODO it might be worth it to just always have a 2-level hierarchy platforms/$(PLATFORM)/$(ARCH), this is annoying

TOP=../..
include $(TOP)/Makefile.inc

### Settings #################################################################
PLATFORM=bmv2 ## Select the platform. Try make -C platforms ls
ARCH=v1model  ## Select the architecture
TARGET_SUPPORTS=HEADER_UNIONS VERIFY

### User-facing targets ######################################################

.PHONY: help listarchs ls build clean

listarchs: ## List supported architectures
	@echo v1model

ls: listarchs ## Shorthand for listarchs

build: $(basename $(MAIN)).json ## Compile the P4 code

# compiler-test: compiler-test-$(ARCH).json ## Compile a simple test program to check whether important features work

clean: ## Removes generated files
	rm -f *.json *.p4i

### Targets that actually do stuff ###########################################

%.json: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c --target bmv2 --arch $(ARCH) --std p4-16 -I$(TOP)/$(INCDIR) $(TARGET_DEFINES) $<
