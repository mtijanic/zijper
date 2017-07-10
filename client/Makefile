include ../common.mk


#SOURCES := $(foreach dir,$(shell find . -type d),$(wildcard $(dir)/*.c))
#HEADERS := $(foreach dir,$(shell find . -type d),$(wildcard $(dir)/*.h))
SOURCES := $(wildcard *.c)
HEADERS := $(wildcard *.h)


CFLAGS += -m32 -fPIC -shared
CFLAGS += -D_GNU_SOURCE

ifdef OPTIMIZE
  CFLAGS += -O2
endif

LDLIBS=-lglut -lGLEW -lGL -lm


all: _out/zijper-client.so

OBJECTS = $(addprefix _out/,$(SOURCES:.c=.o))

_out/%.o: %.c $(HEADERS) | outdir
	$(call report,"compile")
	$(Q)$(CC) $(CFLAGS) -c -o $@ $<

_out/zijper-client.so: $(OBJECTS) | outdir
	$(call report,"link")
	$(Q)$(CC) $(CFLAGS) -o $@ $(OBJECTS) $(LDLIBS)
