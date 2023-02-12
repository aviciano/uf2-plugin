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

all: $(LIB) uf2families.sdb compile_flags.txt

clean:
	rm -f $(LIB) $(OBJS)
	rm -f compile_flags.txt
	rm -f uf2families.sdb
	rm -f uf2families.sdb.txt

$(LIB): $(OBJS) uf2families.sdb
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $(LIB)

install: $(LIB)
	mkdir -p $(R2_PLUGIN_PATH)
	cp -f $(LIB) $(R2_PLUGIN_PATH)

install-symlink: $(LIB)
	mkdir -p $(R2_PLUGIN_PATH)
	ln -s $(CWD)/$(LIB) $(R2_PLUGIN_PATH)/$(LIB)

uninstall:
	rm -f $(R2_PLUGIN_PATH)/$(LIB)

test: $(LIB)
	@radare2 -l uf2_plugin.so -L | grep uf2
	@radare2 -N -q \
		-a arm -b 16 -m cortex \
		-e asm.emu=true \
		-c 's main; s' \
		data/blink.elf
	@echo "elf" && radare2 -N -q \
		-a arm -b 16 -m cortex \
		-e asm.emu=true \
		-c 's 0x1000035c; af; pxf' \
		data/blink.elf
	@echo "uf2" && radare2 -N -q -l uf2_plugin.so \
		-a arm -b 16 -m cortex \
		-e asm.emu=true \
		-c 's 0x1000035c; af; pxf' \
		uf2://data/blink.uf2

uf2families.sdb.txt: uf2families.json
	@python3 uf2families_to_sdb.py > $@

uf2families.sdb: uf2families.sdb.txt
	@sdb $@ = < $?

compile_flags.txt:
	touch $@
	echo "-Wall" >> $@
	echo "-I$(shell r2 -H R2_INCDIR)/sdb" >> $@
	echo "-I$(shell r2 -H R2_INCDIR)" >> $@
	echo "-L$(shell r2 -H R2_LIBDIR)" >> $@
	echo "-lr_anal" >> $@

.PHONY: all clean install install-symlink uninstall test
