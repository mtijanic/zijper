include ../common.mk

all: _out/dialog.tlk
	$(call copy_up,$^)

# Explicit list ordering as later entries will overwrite earlier ones
TLK_SOURCES := dialog.tlk-source \
               zijper-ruleset.tlk-source

_out/merged.tlk-source: $(TLK_SOURCES) | outdir
	$(Q)cat $(TLK_SOURCES) > $@

_out/dialog.tlk: _out/merged.tlk-source | outdir
	$(call report,"tlkencode")
	$(Q)$(TOOLS)/tlkencode.pl -o $@ $<

install: _out/dialog.tlk
	$(ECHO) Copying $< to $(NWNDIR)
	$(Q)cp $< $(NWNDIR)

