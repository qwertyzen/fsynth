#ifndef __CNUFS_H__
#define __CNUFS_H__

#include "fluidsynth.h"

int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions);
int fs_settings_get_names(fluid_settings_t *settings, char **pames);
char *fs_get_sf_info(fluid_synth_t *synth, int sfid);
int fast_file_write(const char *midi_file, const char *sf_file, const char *out_wav);

#endif  // __CNUFS_H__
