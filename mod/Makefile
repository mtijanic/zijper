include ../common.mk

RESOURCE_SUBDIRS := area dlg utm utp uts utt utw utc utd ute uti itp ssf mod
SUBTARGETS := resources scripts $(RESOURCE_SUBDIRS)

ALL_RESOURCES := $(wildcard $(addsuffix /_out/*,$(RESOURCE_SUBDIRS)))

resources: $(RESOURCE_SUBDIRS)

$(RESOURCE_SUBDIRS):
	$(Q)$(MAKE) --directory=$@ --makefile=../resource.mk $(filter-out $(SUBTARGETS),$(MAKECMDGOALS))


ALL_SCRIPTS := $(wildcard nss/_out/*.ncs nss/_out/*.nss)
scripts:
	$(Q)$(MAKE) --directory=nss $(filter-out $(SUBTARGETS),$(MAKECMDGOALS))


.PHONY: scripts resources $(RESOURCE_SUBDIRS)

_out/zijper.mod: resources scripts | outdir
	$(call report,"erfpack")
	$(Q)$(TOOLS)/erfpack.pl -m -o $@ $(ALL_RESOURCES) $(ALL_SCRIPTS)

all: _out/zijper.mod
	$(call copy_up,$^)

install: _out/zijper.mod
	$(ECHO) Copying $< to $(NWNDIR)/modules
	$(Q)cp $< $(NWNDIR)/modules
