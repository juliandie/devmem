PHONY := _all
_all:

# o Do not use make's built-in rules and variables
#   (this increases performance and avoids hard-to-debug behaviour);
# o Look for make include files relative to root of kernel src
MAKEFLAGS += -rR --include-dir=$(CURDIR)

# Avoid funny character set dependencies
unexport LC_ALL
LC_COLLATE=C
LC_NUMERIC=C
export LC_COLLATE LC_NUMERIC

# Avoid interference with shell env settings
unexport GREP_OPTIONS

# build supports saving output files in a separate directory.
# To locate output files in a separate directory two syntaxes are supported.
# In both cases the working directory must be the root of the kernel src.
# 1) O=
# Use "make O=dir/to/store/output/files/"
#
# 2) Set BUILD_OUTPUT
# Set the environment variable BUILD_OUTPUT to point to the directory
# where the output files shall be placed.
# export BUILD_OUTPUT=dir/to/store/output/files/
# make
#
# The O= assignment takes precedence over the BUILD_OUTPUT environment
# variable.

# BUILD_SRC is not intended to be used by the regular user (for now),
# it is set on invocation of make with BUILD_OUTPUT or O= specified.
ifeq ($(BUILD_SRC),)

# OK, Make called in directory where kernel src resides
# Do we want to locate output files in a separate directory?
ifeq ("$(origin O)", "command line")
  BUILD_OUTPUT := $(O)
endif

# Cancel implicit rules on top Makefile
$(CURDIR)/Makefile Makefile: ;

ifneq ($(words $(subst :, ,$(CURDIR))), 1)
  $(error main directory cannot contain spaces nor colons)
endif

ifneq ($(BUILD_OUTPUT),)
# check that the output directory actually exists
saved-output := $(BUILD_OUTPUT)
BUILD_OUTPUT := $(shell mkdir -p $(BUILD_OUTPUT) && cd $(BUILD_OUTPUT) && pwd)
$(if $(BUILD_OUTPUT),, \
     $(error failed to create output directory "$(saved-output)"))
	 
PHONY += $(MAKECMDGOALS) sub-make

$(filter-out _all sub-make $(CURDIR)/Makefile, $(MAKECMDGOALS)) _all: sub-make
	@:

# Invoke a second make in the output directory, passing relevant variables
sub-make:
	$(MAKE) -C $(BUILD_OUTPUT) BUILD_SRC=$(CURDIR) \
		-f $(CURDIR)/Makefile $(filter-out _all sub-make,$(MAKECMDGOALS))

# Leave processing to above invocation of make
skip-makefile := 1
endif # ifneq ($(BUILD_OUTPUT),)
endif # ifeq ($(BUILD_SRC),)

ifeq ($(skip-makefile),)

ifeq ($(SYSROOT),)
	sysroot := /.
else
	sysroot := $(shell cd $(SYSROOT) && pwd)
endif
PREFIX ?= usr/bin

ifeq ($(BUILD_SRC),)
	srcdir := .
else
	srcdir := $(shell cd src && pwd)
endif

CC := $(CROSS_COMPILE)gcc

INCLUDES := 
DEFINES :=
LIBPATHS :=
LIBRARIES := 

FILES := $(wildcard $(srcdir)/*.c)
SRC := $(FILES:$(srcdir)/%=%)
OBJ := $(SRC:%.c=%.o)
TARGET := devmem

CFLAGS := -Wextra -Werror -Wall -Wmissing-prototypes -W -O2 -g
CFLAGS += $(call cc-option,-fno-PIE)
CFLAGS += $(INCLUDES:%=-I$(SRC_DIR)/%)
CFLAGS += $(DEFINES:%=-D%)

LDFLAGS += $(LIBPATHS:%=-L%)
LDFLAGS += $(DEFINES:%=-D%)
LDFLAGS += -Wl,--start-group $(LIBRARIES:%=-l%) -Wl,--end-group
LLINK := $(LIBRARIES:%=-l%)

PHONY += all
all: $(TARGET)

_all: all

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ $(LLINK) -o $@

%.o: $(srcdir)/%.c $(srcdir)/%.h
	$(CC) $(CFLAGS) -c $< -o $@
	
%.o: $(srcdir)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

dump:
	@echo $(CC)

PHONY += clean
clean:
	rm -f *.o $(TARGET)

PHONY += mrproper
mrproper: clean
	rm -f tags TAGS

PHONY += distclean
distclean: mrproper
	rm -f .*~ .*.swp

PHONY += re
re: clean all

PHONY += tags
tags:
	rm -f tags
	find $(srcdir)/ -name '*.[ch]' | xargs ctags --extra=+f --c-kinds=+px

PHONY += install
install:
	install -D -m=755 $(TARGET) $(sysroot)/$(PREFIX)/$(TARGET)

endif # skip-makefile

.PHONY: $(PHONY)

# vim: noet ts=8 sw=8
