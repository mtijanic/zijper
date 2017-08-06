include ../../common.mk

yml := $(wildcard *.yml)
res := $(basename $(yml))


all: $(addprefix _out/,$(res)) cleanup

_out/% : %.yml | outdir
	$(call report,"nwn-gff")
	$(Q)nwn-gff -ly -i $< -kg -o $@


# Remove stale resources in _out if the .yml file was removed.
.PHONY: cleanup
cleanup:
	-$(Q)rm -f $(addprefix _out/,$(filter-out $(res),$(notdir $(wildcard _out/*))))
