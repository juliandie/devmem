PHONY := _all
_all:

ifeq ($(BUILD_SRC),)
ifeq ("$(origin O)", "command line")
    objdir := $(O)
endif
$(CURDIR)/Makefile Makefile: ;

ifneq ($(words $(subst :, ,$(CURDIR))), 1)
    $(error main directory cannot contain spaced nor colons)
endif

ifneq ($(objdir),)
saved-obj:=$(objdir)
objdir:=$(shell mkdir -p $(objdir) && cd $(objdir) && pwd)
$(if $(objdir),, $(error failed to create output directory "$(saved-obj)"))

PHONY += $(MAKECMDGOALS) sub-make

$(filter-out _all sub-make $(CURDIR)/Makefile, $(MAKECMDGOALS)) _all: sub-make
	@:

sub-make:
	$(MAKE) -C $(objdir) BUILD_SRC=$(CURDIR) \
		-f $(CURDIR)/Makefile $(filter-out _all sub-make,$(MAKECMDGOALS))

skip-makefile := 1
endif # ifneq($(objdir),)
endif #	ifeq($(BUILD_SRC),)

ifeq ($(skip-makefile),)
ifeq ($(SYSROOT),)
    sysroot := /.
else
    sysroot := $(shell cd $(SYSROOT) && pwd)
endif

PREFIX ?= usr/bin

ifeq ($(BUILD_SRC),)
    srcdir := $(CURDIR)
else
    srcdir := $(BUILD_SRC)
endif

### CFLAGS
CFLAGS := -Wextra -Wall -O2 -g
CFLAGS += $(call cc-option,-fno-PIE)
### Extend CFLAGS
INCLUDES :=
DEFINES ?=
CFLAGS += $(INCLUDES:%=-I$(srcdir)/%)
CFLAGS += $(DEFINES:%=-D%)

### Extend LDFLAGS
LIBPATHS :=
LIBRARIES :=

LDFLAGS += $(LIBPATHS:%=-L%)
LDFLAGS += $(DEFINES:%=-D%)
LDFLAGS += -Wl,--start-group $(LIBRARIES:%=-l%) -Wl,--end-group
LLINK := $(LIBRARIES:%=-l%)

C_SRC := $(wildcard $(srcdir)/*.c)
C_OBJ := $(C_SRC:%.c=%.o)

PHONY += all
all: devmem

_all: all

devmem: $(C_OBJ)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ $(LLINK) -o $@
	
%.o: %.c %.h
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

PHONY += install
install:
	install -D -m=755 devmem $(SYSROOT)/$(PREFIX)/devmem

PHONY += deploy
deploy:
	@scp devmem dev.nexo2:

PHONY += clean
clean:
	$(RM) -Rf devmem $(C_OBJ)

PHONY += mrproper
mrproper: clean

PHONY += re
re: clean all

endif # skip-makefile

.PHONY: $(PHONY)

# vim: noet ts=8 sw=8
