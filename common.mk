export ZIJPER_DIR ?= /home/mtijanic/dev/zijper

export NWNDIR ?= /home/mtijanic/Apps/neverwinter-nights
export TOOLS ?= $(ZIJPER_DIR)/tools
export PERLLIB ?= $(TOOLS)/lib

Q ?=
MAKE = make --environment-overrides
ECHO = @echo
ifndef VERBOSE
  Q = @
  MAKE += --quiet
endif

.DEFAULT_GOAL = all

.PHONY: outdir
outdir:
	$(Q)-mkdir -p _out

clean:
	-$(Q)rm -rf _out
	$(ECHO) "Removed zijper/$(shell realpath --relative-to $(ZIJPER_DIR) _out)"

.PHONY: clean all install

# $1 - name of command
define report
	$(ECHO) "[ $1 ] $(notdir $@)"
endef

# $1 - file(s) to copy
define copy_up
	$(Q)-mkdir -p ../_out
	$(ECHO) "Copying $(notdir $1) to zijper/$(shell realpath --relative-to $(ZIJPER_DIR) ../_out)"
	$(Q)cp -f $1 ../_out/
endef

