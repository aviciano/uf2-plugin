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
ELF_FILES=$(wildcard data/*.elf)

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

test: $(LIB) test_load $(ELF_FILES)

test_load:
	@r2 -l uf2_plugin.so -L | grep uf2

$(ELF_FILES):
	$(eval OFFSET := $(shell r2 -N -q -c 's main; s' $@))
	@printf "[i] main @ ${OFFSET} in $@ "
	$(eval ELF_MAIN := $(shell r2 -N -q -c 's ${OFFSET}; af; p8f' $@))
	$(eval UF2_MAIN := $(shell r2 -N -q -c 's ${OFFSET}; af; p8f' -l uf2_plugin.so uf2://$(@:.elf=.uf2)))
	@if [ "${ELF_MAIN}" = "${UF2_MAIN}" ]; then\
		echo "Ok";\
	else\
		printf "\r[E] main @ ${OFFSET} in $@ ";\
		echo "ERROR";\
		echo "elf ${ELF_MAIN}";\
		echo "uf2 ${UF2_MAIN}";\
		echo;\
	fi

.PHONY: all clean install install-symlink uninstall test test_load $(ELF_FILES)
