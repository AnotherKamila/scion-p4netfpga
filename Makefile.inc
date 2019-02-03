# Common Makefile included from the top-level and sub-directory Makefiles

### User settings ############################################################
PLATFORM=bmv2 ## Select the platform. Try make -C platforms ls
ARCH=v1model  ## Select the architecture

# Clean up whitespace (grr)
PLATFORM := $(strip $(PLATFORM))
ARCH     := $(strip $(ARCH))

### Project settings #########################################################
SRCDIR=src/
INCDIR=lib/

MAIN=main-$(ARCH).p4

### Environment -- shouldn't need to be changed ##############################

ALL_MAKEFILES=$(MAKEFILE_LIST) $(.MAKE.MAKEFILES)  # GNU and BSD make compatibility

### Internal things -- things will break if you change this ##################

# Detect whether we're running with GNU or BSD make
GNUMAKE=$(shell echo GNUMAKE)

### Common targets ###########################################################


# the auto-documenting target: should be the default
# based on marmelab.com/blog/2016/02/29/auto-documented-makefile.html
# but better! :D
help:  ## Show this help
	@echo Targets:
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo
	@echo Settings:
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+=.*?## .*$$' | awk 'BEGIN {FS = " ?## "}; {printf "  %-20s %s\n", $$1, $$2}' | sort -u -t= -k1,1
	@echo
	@echo 'To override the settings, run: make <target> <VARIABLE>=<value>'

gmake:
	@[ "$(GNUMAKE)" = "GNUMAKE" ] || { echo; echo 'GNU make required (run with gmake)'; exit 70; }

