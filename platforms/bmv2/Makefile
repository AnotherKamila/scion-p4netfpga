TOP=../..
include $(TOP)/Makefile.inc


.PHONY: help clean listarchs ls

listarchs: ## List supported architectures
	@echo v1model

ls: listarchs ## Shorthand for listarchs

build:  ## Compile the P4 code
	p4c --target bmv2 --arch $(ARCH) --std p4-16 -I$(TOP)/$(INCDIR) $(TOP)/$(SRCDIR)/$(MAIN)

clean: ## Removes generated files
	rm -f *.json *.p4i

