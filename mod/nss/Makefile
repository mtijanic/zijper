include ../../common.mk

NCC = $(TOOLS)/nwnnsscomp
NCCFLAGS += -c -e -q
ifdef DEBUG
  CPPFLAGS += -DDEBUG=$(DEBUG)
else
  NCCFLAGS +=  -g -o
endif

CPPFLAGS +=  -P -x c -CC -undef -nostdinc -include nwscript-defs.h

include_dirs = exports
NCCFLAGS += $(addprefix -i ,_out/)
CPPFLAGS += $(addprefix -I,$(include_dirs))

subdirs := $(shell find . -type d)

headers := $(foreach d,$(subdirs),$(wildcard $(d)/*.nsh))
scripts := $(foreach d,$(subdirs),$(wildcard $(d)/*.nss))

all: $(addprefix _out/,$(notdir $(scripts) $(scripts:.nss=.ncs)))

_out/%.nss: | outdir
	$(Q)$(CPP) $(CPPFLAGS) -MD -MT $@ -MF $@.d $(filter %$(notdir $@),$(scripts)) > $@

_out/%.ncs: _out/%.nss | outdir
	$(call report,"nwnnsscomp")
	$(Q)cd _out; $(NCC) $(NCCFLAGS) $(NWNDIR) $(notdir $^)

.PHONY: all clean

-include $(wildcard _out/*.d)
