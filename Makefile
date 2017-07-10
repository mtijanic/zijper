include common.mk

SUBTARGETS = mod hak tlk client server

all: $(SUBTARGETS)
.PHONY: $(SUBTARGETS)

$(SUBTARGETS):
	$(Q)$(MAKE) -C $@ $(filter-out $(SUBTARGETS),$(MAKECMDGOALS))
