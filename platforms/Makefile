TOP=..
include $(TOP)/Makefile.inc
include $(TOP)/platforms/$(PLATFORM)/Makefile.inc

PLATFORMS=$(shell find . -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
list-platforms-only: ## List only the supported platforms (not architectures)
	@echo $(PLATFORMS)

listplatforms: ## List the available platforms.
	@for p in $(PLATFORMS); do echo $$p; echo "  `$(MAKE) --no-print-directory -C $$p ls`"; done

ls: listplatforms ## Shorthand for listplatforms
