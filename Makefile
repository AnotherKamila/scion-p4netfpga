# Top-level Makefile for the SCION-p4netfpga project.

include Makefile.inc

.PHONY: help clean

all: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

build: ## Compile the P4 code
	@echo " +++++++ Building for PLATFORM=$(PLATFORM), ARCH=$(ARCH) +++++++ "
	$(MAKE) -C platforms/$(PLATFORM) build ARCH=$(ARCH)

synth: ## Synthesise the something something TODO terminology
	@echo 'Not implemented yet'
	@/bin/false

test: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

sim: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

flash: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

clean: ## Remove generated files
	$(MAKE) -C platforms/$(PLATFORM) clean
