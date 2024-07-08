/* radare - LGPL - Copyright 2024 - aviciano */

#include <r_core.h>

RBinPlugin r_fs_plugin_uf2 = {
	.meta = {
		.name = "uf2",
		.desc = "uf2 fs plugin",
		.license = "LGPL3",
	},
	// TODO
};

#ifndef R2_PLUGIN_INCORE
R_API RLibStruct radare_plugin = {
	.type = R_LIB_TYPE_FS,
	.data = &r_fs_plugin_uf2,
	.version = R2_VERSION
};
#endif

