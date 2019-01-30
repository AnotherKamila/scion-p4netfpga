# Top-level Makefile for the SCION-p4netfpga project.

# TODO make these variables auto-documenting
PLATFORM=p4c ## Select the platform to compile for. See platforms/ directory.
ARCH=simple_switch ## Select the architecture


.PHONY: help clean

help:  # stolen from marmelab.com/blog/2016/02/29/auto-documented-makefile.html
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-10s %s\n", $$1, $$2}'

all: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

build: ## Compile the P4 code
	@echo "Building for platform: $(PLATFORM)"
	# ... or just enforce 2-level deep things always and -C $PLATFORM/$ARCH? TODO
	make -C "platforms/$(PLATFORM)" build ARCH=$(ARCH)

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

clean: ## Removes generated files
	make -C "platforms/$(PLATFORM)" clean
