include ../common.mk


SOURCES := $(wildcard *.c)
HEADERS := $(wildcard *.h)


CFLAGS += -m32 -fPIC -shared -Wall -Wextra -ggdb
CFLAGS += -D_GNU_SOURCE

ifdef OPTIMIZE
  CFLAGS += -O2
endif
ifdef DEBUG
  CFLAGS += -DDEBUG=$(DEBUG)
endif

LDLIBS=-lGLEW -lGL


all: _out/zijper-client.so

OBJECTS = $(addprefix _out/,$(SOURCES:.c=.o))

_out/%.o: %.c $(HEADERS) | outdir
	$(call report,"compile")
	$(Q)$(CC) $(CFLAGS) -c -o $@ $<

_out/zijper-client.so: $(OBJECTS) | outdir
	$(call report,"link")
	$(Q)$(CC) $(CFLAGS) -o $@ $(OBJECTS) $(LDLIBS)
