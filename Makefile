# Top-level Makefile for the SCION-p4netfpga project.

TOP=.
include $(TOP)/Makefile.inc
include $(TOP)/platforms/$(PLATFORM)/Makefile.inc

.PHONY: help all build sim synth test flash graph clean

##### User-visible targets

all: build graph ## TODO

compiler-test: ## Compile a test program to check support for P4 features
	@echo $(MARK) "Compiling for PLATFORM=$(PLATFORM), ARCH=$(ARCH)" $(ENDMARK)
	$(MAKE) -C platforms/$(PLATFORM) compiler-test ARCH=$(ARCH) || $(MAKE) compiler-test-failed

compiler-test-failed: # TODO
	@echo $(MARK) "Compiler test FAILED!" $(ENDMARK)
	@echo TODO point to documentation about -DTARGET_SUPPORTS_* and stuff

build: ## Build everything needed for using the design
	@echo $(MARK) "Building for PLATFORM=$(PLATFORM), ARCH=$(ARCH)" $(ENDMARK)
	$(MAKE) -C platforms/$(PLATFORM) build ARCH=$(ARCH)

for-all-archs: # Hello, I am a hack!
	@set -e;                                                          \
	for p in `$(MAKE) -s -C platforms list-platforms-only`; do        \
		for a in `$(MAKE) -s -C platforms/$$p listarchs` ; do           \
			$(MAKE) $(WHAT) --no-print-directory PLATFORM=$$p ARCH=$$a ;  \
		done ;                                                          \
	done

# synth: ## Synthesise the something something TODO terminology
# 	@echo 'Not implemented yet'
# 	@/bin/false

flash: ## TODO
	@echo 'Not implemented yet'
	@/bin/false

graph: graphs ## Visualise the control flow of the P4 program

sim: ## Verify the design and run simulations.
	@echo $(MARK) "Testing for PLATFORM=$(PLATFORM), ARCH=$(ARCH)" $(ENDMARK)
	$(MAKE) -C platforms/$(PLATFORM) test ARCH=$(ARCH)

test: sim ## Alias for sim

# TODO hwtest

clean: ## Remove generated files
	$(MAKE) -C platforms/$(PLATFORM) clean
	$(MAKE) -C test clean
	rm -rf graphs/

test-all: sim-all ## Alias for sim-all

sim-all: ## Build and test for all platforms and architectures.
	@$(MAKE) --no-print-directory for-all-archs WHAT=sim
	@echo $(MARK) "Nothing broke! Yay!" $(ENDMARK)

clean-all: ## Remove generated files for all platforms and architectures
	@$(MAKE) -s for-all-archs WHAT=clean

##### Targets that actually do things

graphs: $(SRCDIR)/$(MAIN) $(shell find $(INCDIR) -name '*.p4')
# checking GNUMAKE inline to avoid always rebuilding
	@[ "$(GNUMAKE)" = "GNUMAKE" ] || { echo; echo 'GNU make required (run with gmake)'; exit 70; }
	mkdir -p graphs
	p4c-graphs --std p4-16 -I$(INCDIR) $(SRCDIR)/$(MAIN) --graphs-dir ./graphs
	cd graphs; for f in *.dot; do dot $$f -T png -x -o $$f.png; done
	cd graphs; for f in *.dot; do dot $$f -T svg -x -o $$f.svg; done
	touch graphs
	@echo $(MARK) "Graphs saved in the graphs/ directory." $(ENDMARK)
