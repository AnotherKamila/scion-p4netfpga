ARCH=v1model
CFLAGS=-Ithingsandstuff  # TODO :D
SRCDIR=../src
MAIN=main-$(ARCH).p4

.PHONY: help clean

help:  # stolen from marmelab.com/blog/2016/02/29/auto-documented-makefile.html
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-10s %s\n", $$1, $$2}'

build:  ## Compile the P4 code
	p4c --target bmv2 --arch $(ARCH) --std p4-16 $(SRCDIR)/$(MAIN)

clean: ## Removes generated files
	rm -f *.json *.p4i

