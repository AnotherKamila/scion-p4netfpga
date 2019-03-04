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

TARGET_DEFINES=$(foreach F,$(TARGET_SUPPORTS),-DTARGET_SUPPORTS_$(F))

### Environment -- shouldn't need to be changed ##############################

ALL_MAKEFILES=$(MAKEFILE_LIST) $(.MAKE.MAKEFILES)  # GNU and BSD make compatibility

### Internal things -- things will break if you change this ##################

# Detect whether we're running with GNU or BSD make
GNUMAKE=$(shell echo GNUMAKE)

### Silly things that only exist because I like poking Makefiles #############

MARK='\n\033[1m-----'
ENDMARK='-----\033[0m\n'

### Common targets ###########################################################

###### The auto-documenting target (here be dragons) #########################

help: gmake ## Show this help
	@$(MAKE) -s _help | column -t -s'|'
	@echo
	@echo 'To override the settings, run: make <VARIABLE>=<value> <target>'

_help: gmake
	@echo Targets:
	@echo
	@$(MAKE) -s _show-targets | sed 's/^/  /'
	@echo Settings:
	@$(MAKE) -s _show-settings | sed 's/^/  /'

_show-targets:
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' | awk 'BEGIN {FS = ":.*?## "}; {printf "%s|%s\n", $$1, $$2}'

_show-setting: gmake
	@echo "$(SHOW_SETTING)=$($(SHOW_SETTING))|`cat $(ALL_MAKEFILES) | sed -n '/^$(SHOW_SETTING)=/s/[^#]*## *//p' | tail -n1`"

list-settings-vars: gmake
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+=.*?## .*$$' | cut -d= -f1 | awk '!x[$$0]++'

_show-settings:
	@$(foreach var,$(shell $(MAKE) -s list-settings-vars),$(MAKE) -s _show-setting SHOW_SETTING=$(var);)

gmake:
	@[ "$(GNUMAKE)" = "GNUMAKE" ] || { echo; echo 'GNU make required (run with gmake)'; exit 70; }

###### Helper targets for humans #############################################

find-all-target-supports:
	@find $(TOP) -name '*.p4' | xargs cat | grep -o -E 'TARGET_SUPPORTS_\w+' | sort -u | sed s/TARGET_SUPPORTS_//

target-supports: # TODO Does NOT work in the toplevel directory!
	@echo $(TARGET_SUPPORTS)

###### Common targets needed for actually doing stuff ########################

clean-gitignore: # Remove all files listed in ./.gitignore
	rm -rfv $$(cat ./.gitignore | grep -v '^#')