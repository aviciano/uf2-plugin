/* radare - LGPL - Copyright 2024 - aviciano */

#include <r_core.h>

static RBinInfo *info(RBinFile *bf) {
	r_return_val_if_fail (bf && bf->bo, NULL);
	RBinInfo *ret = R_NEW0 (RBinInfo);
	if (!ret) {
		return NULL;
	}
	ret->file = strdup (bf->file);
	ret->big_endian = false;
	ret->type = strdup ("uf2");
	return ret;

}

// TODO DRY extract uf2.h
#define UF2_MAGIC_START0 0x0A324655UL // "UF2\n


static bool check(RBinFile *bf, RBuffer *b) {
	r_return_val_if_fail (b, false);
	return r_buf_read_le32_at (b, 0) == UF2_MAGIC_START0;
}


static bool load(RBinFile *bf, RBuffer *buf, ut64 loadaddr) {
	return true;
}

static void destroy(RBinFile *bf) {
	r_return_if_fail (bf && bf->bo);
	r_buf_free (bf->bo->bin_obj);
}

RBinPlugin r_bin_plugin_uf2 = {
	.meta = {
		.name = "uf2",
		.desc = "uf2 bin plugin",
		.license = "LGPL3",
	},
	// TODO
	.load = load,
	.destroy = destroy,
	.check = check,
	.info = info,
};

#ifndef R2_PLUGIN_INCORE
R_API RLibStruct radare_plugin = {
	.type = R_LIB_TYPE_BIN,
	.data = &r_bin_plugin_uf2,
	.version = R2_VERSION
};
#endif

