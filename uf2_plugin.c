/* radare - LGPL - Copyright 2023 - aviciano */

#include <r_core.h>
#include <r_io.h>
#include <r_lib.h>
#include <r_types.h>

#define UF2_MAGIC_START0 0x0A324655UL // "UF2\n"
#define UF2_MAGIC_START1 0x9E5D5157UL // Randomly selected
#define UF2_MAGIC_END 0x0AB16F30UL    // Ditto

// Little endian is used, as most microcontrollers are little endian.
// https://github.com/Microsoft/uf2
// https://github.com/raspberrypi/picotool/issues/8

enum UF2_Flags {
	NOT_MAIN_FLASH = 0x1 << 0,
	FILE_CONTAINER = 0x1 << 12,
	FAMILY_ID      = 0x1 << 13,
	MD5_CHECKSUM   = 0x1 << 14,
	EXTENSION_TAGS = 0x1 << 15,
};

typedef struct {
	// 32 byte header
	uint32_t magicStart0; // First magic number, 0x0A324655 ("UF2\n")
	uint32_t magicStart1; // Second magic number, 0x9E5D5157
	uint32_t flags;
	uint32_t targetAddr;  // Address in flash where the data should be written
	uint32_t payloadSize; // Number of bytes used in data (often 256)
	uint32_t blockNo;     // Sequential block number; starts at 0
	uint32_t numBlocks;   // Total number of blocks in file
	uint32_t fileSize;    // File size or board family ID or zero

	// raw data
	// uint8_t data[476];    // Data, padded with zeros
	uint8_t *data;        // Data, padded with zeros

	// store magic also at the end to limit damage from partial block reads
	uint32_t magicEnd;    // Final magic number, 0x0AB16F30
} UF2_Block;

typedef struct {
	int fd;
	RBuffer *rbuf;
} Ruf2;

static bool __check(RIO *io, const char *pathname, bool many) {
	return (!strncmp (pathname, "uf2://", 6));
}

static RIODesc *__open(RIO *io, const char *pathname, int rw, int mode);

static int __read(RIO *io, RIODesc *desc, ut8 *buf, int count) {
	if (!desc || !desc->data || (count <= 0)) {
		return -1;
	}
	Ruf2 *mal = desc->data;
	memset (buf, io->Oxff, count);
	int r = r_buf_read_at (mal->rbuf, io->off, buf, count);
	if (r >= 0) {
		r_buf_seek (mal->rbuf, r, R_BUF_CUR);
	}
	return r;
}

static bool __close(RIODesc *desc) {
	if (!desc || !desc->data) {
		return false;
	}
	Ruf2 *mal = desc->data;
	r_buf_free (mal->rbuf);
	free (mal);
	desc->data = NULL;
	return true;
}

static ut64 __lseek(RIO *io, RIODesc *desc, ut64 offset, int whence) {
	if (!desc || !desc->data) {
		return -1;
	}
	Ruf2 *mal = desc->data;
	io->off = r_buf_seek (mal->rbuf, offset, whence);
	return io->off;
}

static int __write(RIO *io, RIODesc *desc, const ut8 *buf, int count) {
	return -1;
}

#if 0
static void dump(UF2_Block *block) {
	// Family ID https://github.com/microsoft/uf2/blob/master/utils/uf2families.json
	eprintf ("===========[BLOCK]===========\n");
	eprintf ("- magicStart0 : 0x%08x\n", block->magicStart0); // First magic number, 0x0A324655 ("UF2\n")
	eprintf ("- magicStart1 : 0x%08x\n", block->magicStart1); // Second magic number, 0x9E5D5157
	eprintf ("- flags       : 0x%08x (", block->flags);
	eprintf ("%s", (block->flags & NOT_MAIN_FLASH) == 0 ? "" : " NOT_MAIN_FLASH");
	eprintf ("%s", (block->flags & FILE_CONTAINER) == 0 ? "" : " FILE_CONTAINER");
	eprintf ("%s", (block->flags & FAMILY_ID     ) == 0 ? "" : " FAMILY_ID");
	eprintf ("%s", (block->flags & MD5_CHECKSUM  ) == 0 ? "" : " MD5_CHECKSUM");
	eprintf ("%s", (block->flags & EXTENSION_TAGS) == 0 ? "" : " EXTENSION_TAGS");
	eprintf (" )\n");
	eprintf ("- targetAddr  : 0x%08x\n", block->targetAddr);  // Address in flash where the data should be written
	eprintf ("- payloadSize : %u\n", block->payloadSize); // Number of bytes used in data (often 256)
	eprintf ("- blockNo     : %u\n", block->blockNo);     // Sequential block number; starts at 0
	eprintf ("- numBlocks   : %u\n", block->numBlocks);   // Total number of blocks in file
	if ((block->flags & FAMILY_ID) == 0) {
		eprintf ("- fileSize    : %u\n", block->fileSize);    // File size or board family ID or zero
	} else {
		eprintf ("- familyID    : 0x%08x\n", block->fileSize);    // File size or board family ID or zero
	}
	eprintf ("- data        : \n");        // Raw Data, padded with zeros 476
	int i = 0;
	while (i < block->payloadSize) {
		eprintf ("%02x ", block->data[i++] & 0xff);
		if (i % 16 == 0) eprintf("\n");
	}
	if (i % 16 != 0) eprintf("\n");
	eprintf ("- magicEnd    : 0x%08x\n", block->magicEnd);    // Final magic number, 0x0AB16F30
	eprintf ("\n");
}
#endif

static void process_family_id (RCore *core, uint32_t family_id) {
	Sdb *sdb = sdb_new0 ();
	if (sdb_open (sdb, "uf2families.sdb") < 0) {
		R_LOG_ERROR ("uf2: uf2families.sdb not fund");
	} else {
		const char *id = r_str_newf ("0x%08x", family_id);
		const char *name = sdb_array_get (sdb, id, 0, NULL);
		const char *desc = sdb_array_get (sdb, id, 1, NULL);
		const char *arch = sdb_array_get (sdb, id, 2, NULL);
		const char *bits = sdb_array_get (sdb, id, 3, NULL);
		const char *cpu = sdb_array_get (sdb, id, 4, NULL);
		R_LOG_DEBUG ("uf2: Family ID %s => { name:%s, desc:%s, arch:%s, bits:%s, cpu:%s }",
				id, name, desc, arch, bits, cpu);
		if (arch && arch[0] != '\0') r_core_cmdf (core, "e asm.arch=%s", arch);
		if (bits && bits[0] != '\0') r_core_cmdf (core, "e asm.bits=%s", bits);
		if (cpu && cpu[0] != '\0') r_core_cmdf (core, "e asm.cpu=%s", cpu);
	}
	sdb_free (sdb);
}

static bool uf2_parse(RIO *io, RBuffer* rbuf, char *str) {

	bool has_debug = r_sys_getenv_asbool ("R2_DEBUG");
	uint32_t family_id = 0;
	RCore *core = io->coreb.core;

	UF2_Block block;
	do {
		block.magicStart0 = *(uint32_t*)(str + 0x00); // First magic number, 0x0A324655 ("UF2\n")
		block.magicStart1 = *(uint32_t*)(str + 0x04); // Second magic number, 0x9E5D5157
		block.flags       = *(uint32_t*)(str + 0x08);
		block.targetAddr  = *(uint32_t*)(str + 0x0c); // Address in flash where the data should be written
		block.payloadSize = *(uint32_t*)(str + 0x10); // Number of bytes used in data (often 256)
		block.blockNo     = *(uint32_t*)(str + 0x14); // Sequential block number; starts at 0
		block.numBlocks   = *(uint32_t*)(str + 0x18); // Total number of blocks in file
		block.fileSize    = *(uint32_t*)(str + 0x1c); // File size or board family ID or zero
		block.data        = (str + 0x20); // Raw Data, padded with zeros [476]
		block.magicEnd    = *(uint32_t*)(str + 0x1fc); // Final magic number, 0x0AB16F30
		str += 512;

		// dump (&block);

		if (block.magicStart0 != UF2_MAGIC_START0) {
			R_LOG_ERROR ("uf2: Invalid magic start 0 @ block %d", block.blockNo);
			return false;
		}

		if (block.magicStart1 != UF2_MAGIC_START1) {
			R_LOG_ERROR ("uf2: Invalid magic start 1 @ block %d", block.blockNo);
			return false;
		}

		if (block.magicEnd != UF2_MAGIC_END) {
			R_LOG_ERROR ("uf2: Invalid magic end @ block %d", block.blockNo);
			return false;
		}

		if ((block.flags & NOT_MAIN_FLASH) != 0) {
			R_LOG_WARN ("uf2: Found NOT_MAIN_FLASH flag @ block #%d, skiping", block.blockNo);
			continue;
		}

		if ((block.flags & FAMILY_ID) != 0) {
			// R_LOG_DEBUG ("uf2: Found FAMILY_ID flag @ block #%d", block.blockNo);
			bool new_family_id = family_id != block.fileSize;
			if (new_family_id) {
				if (family_id != 0) {
					R_LOG_WARN ("uf2: Family ID 0x%08x changed", block.fileSize);
				}
				process_family_id (core, block.fileSize);
				family_id =  block.fileSize;
			}
		}

		if ((block.flags & MD5_CHECKSUM) != 0) {
			R_LOG_WARN ("uf2: Found MD5_CHECKSUM flag @ block #%d, TODO", block.blockNo);
		}

		if ((block.flags & EXTENSION_TAGS) != 0) {
			R_LOG_WARN ("uf2: Found EXTENSION_TAGS flag @ block #%d, TODO", block.blockNo);
			// uint32_t tagsOffset = 32 + block.payloadSize;
		}

		if (r_buf_write_at (rbuf, block.targetAddr, block.data, block.payloadSize) != block.payloadSize) {
			R_LOG_ERROR ("uf2: Sparse buffer problem, giving up");
			return false;
		} else if (has_debug) {
			R_LOG_DEBUG ("uf2: Block #%02d (%d bytes @ 0x%08x)", block.blockNo, block.payloadSize, block.targetAddr);
		}

	} while (block.blockNo < block.numBlocks - 1);

	return true;
}

static bool __resize(RIO *io, RIODesc *desc, ut64 size) {
	if (!desc) {
		return false;
	}
	Ruf2 *mal = desc->data;
	if (!mal) {
		return false;
	}
	return r_buf_resize (mal->rbuf, size);
}

RIOPlugin r_io_plugin_uf2 = {
	.name = "uf2",
	.desc = "uf2 io plugin",
	.uris = "uf2://",
	.license = "LGPL3",
	.open = __open,
	.close = __close,
	.read = __read,
	.check = __check,
	.seek = __lseek,
	// .write = __write,
	.resize = __resize,
};

#ifndef R2_PLUGIN_INCORE
R_API RLibStruct radare_plugin = {
	.type = R_LIB_TYPE_IO,
	.data = &r_io_plugin_uf2,
	.version = R2_VERSION
};
#endif

static RIODesc *__open(RIO *io, const char *pathname, int rw, int mode) {
	if (!__check(io, pathname, false)) {
		return NULL;
	}

	char *str = r_file_slurp (pathname + 6, NULL);
	if (!str) {
		return NULL;
	}

	Ruf2 *mal = R_NEW0 (Ruf2);
	if (!mal) {
		free (str);
		return NULL;
	}

	mal->rbuf = r_buf_new_sparse (io->Oxff);
	if (!mal->rbuf) {
		free (str);
		free (mal);
		return NULL;
	}

	if (!uf2_parse (io, mal->rbuf, str)) {
		R_LOG_ERROR ("uf2: Failed to parse UF2 file");
		free (str);
		r_buf_free (mal->rbuf);
		free (mal);
		return NULL;
	}

	free (str);
	return r_io_desc_new (io, &r_io_plugin_uf2, pathname, rw, mode, mal);
}

