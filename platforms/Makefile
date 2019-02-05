TOP=..
include $(TOP)/Makefile.inc

listplatforms: ## List the available platforms.
	@for p in `find . -mindepth 1 -maxdepth 1 -type d`; do basename $$p; echo "  `$(MAKE) -s -C $$p ls`"; done

ls: listplatforms ## Shorthand for listplatforms

