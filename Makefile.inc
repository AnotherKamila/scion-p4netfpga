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

MARK='\n\033[1m-----'
ENDMARK='-----\033[0m\n'

### Environment -- shouldn't need to be changed ##############################

ALL_MAKEFILES=$(MAKEFILE_LIST) $(.MAKE.MAKEFILES)  # GNU and BSD make compatibility

### Internal things -- things will break if you change this ##################

# Detect whether we're running with GNU or BSD make
GNUMAKE=$(shell echo GNUMAKE)

### Common targets ###########################################################


# the auto-documenting target: should be the default
# based on marmelab.com/blog/2016/02/29/auto-documented-makefile.html
# but better! :D
help: ## Show this help
	@echo Targets:
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %s: %s\n", $$1, $$2}' | column -t -s:
	@echo
	@echo Settings:
	@$(MAKE) -s show-settings | sed 's/^/  /' | column -t -s:
	@echo
	@echo 'To override the settings, run: make <target> <VARIABLE>=<value>'
	@[ "$(GNUMAKE)" = "GNUMAKE" ] || { echo; echo 'GNU make required (run with gmake)'; exit 70; }  # inline to have help first

gmake:
	@[ "$(GNUMAKE)" = "GNUMAKE" ] || { echo; echo 'GNU make required (run with gmake)'; exit 70; }

### Helper targets ###########################################################

show-targets:


show-setting:
	@cat $(ALL_MAKEFILES) | echo $(SHOW_SETTING)=$($(SHOW_SETTING)): `sed -n '/^$(SHOW_SETTING)=/s/[^#]*## *//p' | tail -n1`

list-settings-vars:
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+=.*?## .*$$' | cut -d= -f1 | awk '!x[$$0]++'

show-settings:
	@$(foreach var,$(shell $(MAKE) -s list-settings-vars),$(MAKE) -s show-setting SHOW_SETTING=$(var);)


find-all-target-supports:
	@find $(TOP) -name '*.p4' | xargs cat | grep -o -E 'TARGET_SUPPORTS_\w+' | sort -u | sed s/TARGET_SUPPORTS_//

### Common targets needed for actually doing stuff ###########################

target-supports: # Does NOT work in the toplevel directory!
	@echo $(TARGET_SUPPORTS)

target-supports-define-flags: # Does NOT work in the toplevel directory!
	@for d in $(TARGET_SUPPORTS); do echo -DTARGET_SUPPORTS_$$d ; done
