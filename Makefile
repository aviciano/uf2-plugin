NAME=uf2_plugin
R2_PLUGIN_PATH=$(shell r2 -H R2_USER_PLUGINS)
LIBEXT=$(shell r2 -H LIBEXT)
# CFLAGS=-g -fPIC $(shell pkg-config --cflags r_core)
# LDFLAGS=-shared $(shell pkg-config --libs r_core)
CFLAGS=-g -fPIC -I$(shell r2 -H R2_INCDIR)
LDFLAGS=-shared -L$(shell r2 -H R2_LIBDIR) -lr_core
OBJS=$(NAME).o
LIB=$(NAME).$(LIBEXT)
CWD=$(shell pwd)
ELF_FILES=$(wildcard data/*.elf)

all: $(LIB) compile_flags.txt

clean:
	rm -f $(LIB) $(OBJS)
	rm -f compile_flags.txt

$(LIB): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $(LIB)

install: $(LIB)
	mkdir -p $(R2_PLUGIN_PATH)
	cp -f $(LIB) $(R2_PLUGIN_PATH)

install-symlink: $(LIB)
	mkdir -p $(R2_PLUGIN_PATH)
	ln -s $(CWD)/$(LIB) $(R2_PLUGIN_PATH)/$(LIB)

uninstall:
	rm -f $(R2_PLUGIN_PATH)/$(LIB)

compile_flags.txt:
	touch $@
	echo "-Wall" >> $@
	echo "-I$(shell r2 -H R2_INCDIR)/sdb" >> $@
	echo "-I$(shell r2 -H R2_INCDIR)" >> $@
	echo "-L$(shell r2 -H R2_LIBDIR)" >> $@
	echo "-lr_core" >> $@

test: test_load $(ELF_FILES)

test_load: $(LIB)
	@r2 -l ./$< -L | grep uf2

$(ELF_FILES): $(LIB)
	$(eval OFFSET := $(shell r2 -N -q -c 's main; s' $@))
	@printf "[i] main @ ${OFFSET} in $@ "
	$(eval ELF_MAIN := $(shell r2 -N -q -c 's ${OFFSET}; af; p8f' $@))
	$(eval UF2_MAIN := $(shell r2 -N -q -c 's ${OFFSET}; af; p8f' -l ./$(LIB) uf2://$(@:.elf=.uf2)))
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
