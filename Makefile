NAME=uf2_plugin
R2_PLUGIN_PATH=$(shell r2 -H R2_USER_PLUGINS)
LIBEXT=$(shell r2 -H LIBEXT)
# CFLAGS=-g -fPIC $(shell pkg-config --cflags r_anal)
# LDFLAGS=-shared $(shell pkg-config --libs r_anal)
CFLAGS=-g -fPIC -I$(shell r2 -H R2_INCDIR) -I$(shell r2 -H R2_INCDIR)/sdb/
LDFLAGS=-shared -L$(shell r2 -H R2_LIBDIR) -lr_anal
OBJS=$(NAME).o
LIB=$(NAME).$(LIBEXT)
CWD=$(shell pwd)

all: $(LIB)

clean:
	rm -f $(LIB) $(OBJS)

$(LIB): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $(LIB)

install: $(LIB)
	mkdir -p $(R2_PLUGIN_PATH)
	cp -f $(LIB) $(R2_PLUGIN_PATH)

install-symlink:
	mkdir -p $(R2_PLUGIN_PATH)
	ln -s $(CWD)/$(LIB) $(R2_PLUGIN_PATH)/$(LIB)

uninstall:
	rm -f $(R2_PLUGIN_PATH)/$(LIB)

test:
	@echo "TODO test"


.PHONY: all clean install install-symlink uninstall test
