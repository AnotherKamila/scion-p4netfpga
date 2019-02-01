# Top-level Makefile for the SCION-p4netfpga project.

include Makefile.inc

.PHONY: help all build sim synth test flash graph clean

##### User-visible targets

all: build graph ## TODO

build: ## Compile the P4 code
	@echo " +++++++ Building for PLATFORM=$(PLATFORM), ARCH=$(ARCH) +++++++ "
	$(MAKE) -C platforms/$(PLATFORM) build ARCH=$(ARCH)

sim: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

synth: ## Synthesise the something something TODO terminology
	@echo 'Not implemented yet'
	@/bin/false

test: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

flash: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

graph: graphs ## Visualise the control flow of the P4 program

clean: ## Remove generated files
	$(MAKE) -C platforms/$(PLATFORM) clean
	rm -rf graphs/

##### Targets that actually do things

graphs: $(SRCDIR)/$(MAIN) $(shell find $(INCDIR) -name '*.p4')
# checking GNUMAKE inline to avoid always rebuilding
	@[ "$(GNUMAKE)" = "GNUMAKE" ] || { echo; echo 'GNU make required (run with gmake)'; exit 70; }
	mkdir -p graphs
	p4c-graphs --std p4-16 -I$(INCDIR) $(SRCDIR)/$(MAIN) --graphs-dir ./graphs
	cd graphs; for f in *.dot; do dot $$f -T png -x -o $$f.png; done
	cd graphs; for f in *.dot; do dot $$f -T svg -x -o $$f.svg; done
	touch graphs
	@echo " ++++++ Graphs saved in the graphs/ directory. ++++++ "
