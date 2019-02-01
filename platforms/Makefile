TOP=..
include $(TOP)/Makefile.inc

.PHONY: listplatforms ls help clean

listplatforms: ## List the available platforms.
	@for p in `find . -mindepth 1 -maxdepth 1 -type d`; do basename $$p; echo "  `$(MAKE) -C $$p --no-print-directory ls`"; done

ls: listplatforms ## Shorthand for listplatforms

