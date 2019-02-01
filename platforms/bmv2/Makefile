TOP=../..
include $(TOP)/Makefile.inc


.PHONY: help listarchs ls build clean

listarchs: ## List supported architectures
	@echo v1model

ls: listarchs ## Shorthand for listarchs

build: $(basename $(MAIN)).json ## Compile the P4 code

%.json: $(TOP)/$(SRCDIR)/%.p4 $(shell find $(TOP)/$(INCDIR) -name '*.p4')
	p4c --target bmv2 --arch $(ARCH) --std p4-16 -I$(TOP)/$(INCDIR) $<

clean: ## Removes generated files
	rm -f *.json *.p4i
