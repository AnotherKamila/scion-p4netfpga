# Common Makefile included from the top-level and sub-directory Makefiles

### User settings ############################################################
PLATFORM=netfpga          ## Select the platform. Try make -C platforms ls
DEBUG=0                   ## Compile with debugging enabled

# Clean up whitespace (grr)
PLATFORM := $(strip $(PLATFORM))
ARCH     := $(strip $(ARCH))
DEBUG    := $(strip $(DEBUG))

### Project settings #########################################################
SRCDIR=src
INCDIR=lib

MAIN=main-$(ARCH).p4

TARGET_DEFINES=$(foreach F,$(TARGET_SUPPORTS),-DTARGET_SUPPORTS_$(F))
EXTRA_DEFINES=

ifneq ($(DEBUG),0)
EXTRA_DEFINES += -DEBUG
endif

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

help: ## Show this help
	@$(MAKE) -s _help | column -t -s'|'
	@echo
	@echo 'To override the settings, run: make <VARIABLE>=<value> <task>'

_help: _gmake
	@echo Frequently used tasks:
	@echo
	@$(MAKE) -s _show-targets | sed 's/^/  /'
	@echo Settings:
	@$(MAKE) -s _show-settings | sed 's/^/  /'

_show-targets:
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' | awk 'BEGIN {FS = ":.*?## "}; {printf "%s|%s\n", $$1, $$2}'

_show-setting: _gmake
	@echo "$(SHOW_SETTING)=$($(SHOW_SETTING))|`cat $(ALL_MAKEFILES) | sed -n '/^$(SHOW_SETTING)=/s/[^#]*## *//p' | tail -n1`"

list-settings-vars: _gmake
	@cat $(ALL_MAKEFILES) | grep -E '^[a-zA-Z0-9_-]+=.*?## .*$$' | cut -d= -f1 | awk '!x[$$0]++'

_show-settings: _gmake
	@$(foreach var,$(shell $(MAKE) -s list-settings-vars),$(MAKE) -s _show-setting SHOW_SETTING=$(var);)

###### Targets that complain if the environment smells wrong ###############

_gmake:
	@[ "$(GNUMAKE)" = "GNUMAKE" ] || { echo; echo 'ERROR: GNU make required'; exit 70; }

_env: _gmake
	@which vivado || { echo "ERROR: Xilinx tools not in PATH, source something like /opt/Xilinx/Vivado/2018.2/settings64.sh"; exit 78; }

_root:
	@[ `id -u` = 0 ] || { echo "ERROR: You must be root to run this target. (Don't forget to setup the env!)"; exit 77; }

###### Helper targets for humans #############################################

find-all-target-supports: ## Prints all TARGET_SUPORTS_* features used by the project's code
	@find $(TOP) -name '*.p4' | xargs cat | grep -o -E 'TARGET_SUPPORTS_\w+' | sort -u | sed s/TARGET_SUPPORTS_//

target-supports: ## Shows what features are supported by the selected target (i.e. PLATFORM/ARCH)
	@[ -n "$(TARGET_SUPPORTS)" ] && echo $(TARGET_SUPPORTS) || $(MAKE) --no-print-directory -C $(TOP)/platforms/$(PLATFORM) target-supports

###### Common targets needed for actually doing stuff ########################

# Note that this does not try to cover all possible cases of .gitignore syntax!
# If using this, check that it does what you need!
clean-gitignore: # Remove all files listed in ./.gitignore
	for pat in `cat .gitignore | grep -v '^#' | grep -v /`; do find . -name $$pat | xargs rm -rfv; done
	for pat in `cat .gitignore | grep -v '^#' | grep /`; do rm -rfv $$pat; done
