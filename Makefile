R2_PLUGIN_PATH=$(shell r2 -H R2_USER_PLUGINS)
LIBEXT=$(shell r2 -H LIBEXT)

# CFLAGS=-g -fPIC $(shell pkg-config --cflags r_core)
# LDFLAGS=-shared $(shell pkg-config --libs r_core)
CFLAGS=-g -fPIC -I$(shell r2 -H R2_INCDIR)
LDFLAGS=-shared -L$(shell r2 -H R2_LIBDIR) -lr_core

SRCS_IO=io_uf2.c
SRCS_FS=fs_uf2.c
SRCS_BIN=bin_uf2.c

OBJS_IO=$(SRCS_IO:%.c=%.o)
OBJS_FS=$(SRCS_FS:%.c=%.o)
OBJS_BIN=$(SRCS_BIN:%.c=%.o)

TARGET_IO=io_uf2.$(LIBEXT)
TARGET_FS=fs_uf2.$(LIBEXT)
TARGET_BIN=bin_uf2.$(LIBEXT)

TARGETS=$(TARGET_IO) $(TARGET_FS) $(TARGET_BIN)

CWD=$(shell pwd)
ELF_FILES=$(wildcard data/*.elf)

all: $(TARGETS) compile_flags.txt

clean:
	rm -f *.o *.$(LIBEXT)
	rm -f compile_flags.txt

$(TARGET_IO): $(OBJS_IO)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS_IO) -o $(TARGET_IO)

$(TARGET_FS): $(OBJS_FS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS_FS) -o $(TARGET_FS)

$(TARGET_BIN): $(OBJS_BIN)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS_BIN) -o $(TARGET_BIN)

install: $(TARGETS)
	mkdir -p $(R2_PLUGIN_PATH)
	cp -f $(TARGET_IO) $(R2_PLUGIN_PATH)
	cp -f $(TARGET_FS) $(R2_PLUGIN_PATH)
	cp -f $(TARGET_BIN) $(R2_PLUGIN_PATH)

install-symlink: $(TARGET_IO)
	mkdir -p $(R2_PLUGIN_PATH)
	ln -s $(CWD)/$(TARGET_IO) $(R2_PLUGIN_PATH)/$(TARGET_IO)
	ln -s $(CWD)/$(TARGET_FS) $(R2_PLUGIN_PATH)/$(TARGET_FS)
	ln -s $(CWD)/$(TARGET_BIN) $(R2_PLUGIN_PATH)/$(TARGET_BIN)

uninstall:
	rm -f $(R2_PLUGIN_PATH)/$(TARGET_IO)
	rm -f $(R2_PLUGIN_PATH)/$(TARGET_FS)
	rm -f $(R2_PLUGIN_PATH)/$(TARGET_BIN)

compile_flags.txt:
	touch $@
	echo "-Wall" >> $@
	echo "-I$(shell r2 -H R2_INCDIR)/sdb" >> $@
	echo "-I$(shell r2 -H R2_INCDIR)" >> $@
	echo "-L$(shell r2 -H R2_LIBDIR)" >> $@
	echo "-lr_core" >> $@

test: test_io test_fs test_bin
test_io: test_load_io $(ELF_FILES)
test_fs: test_load_fs
test_bin: test_load_bin

test_load_io: $(TARGET_IO)
	@r2 -N -q -c 'Lo' -l ./$(TARGET_IO) -- | grep uf2

test_load_fs: $(TARGET_FS)
	@r2 -N -q -c 'Lm' -l ./$(TARGET_FS) -- | grep uf2

test_load_bin: $(TARGET_BIN)
	@r2 -N -q -c 'Lb' -l ./$(TARGET_BIN) -- | grep uf2

$(ELF_FILES): $(TARGET_IO)
	$(eval OFFSET := $(shell r2 -N -q -c 's main; s' $@))
	@printf "[i] main @ ${OFFSET} in $@ "
	$(eval ELF_MAIN := $(shell r2 -N -q -c 's ${OFFSET}; af; p8f' $@))
	$(eval UF2_MAIN := $(shell r2 -N -q -c 's ${OFFSET}; af; p8f' -l ./$(TARGET_IO) uf2://$(@:.elf=.uf2)))
	@if [ "${ELF_MAIN}" = "${UF2_MAIN}" ]; then\
		echo "Ok";\
	else\
		printf "\r[E] main @ ${OFFSET} in $@ ";\
		echo "ERROR";\
		echo "elf ${ELF_MAIN}";\
		echo "uf2 ${UF2_MAIN}";\
		echo;\
	fi

.PHONY: all clean install install-symlink uninstall test \
	test_io test_load_io $(ELF_FILES) \
	test_fs test_load_fs \
	test_bin test_load_bin
