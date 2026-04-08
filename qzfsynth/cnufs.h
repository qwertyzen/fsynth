#ifndef __CNUFS_H__
#define __CNUFS_H__

#include "fluidsynth.h"

int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions);
int fs_settings_get_names(fluid_settings_t *settings, char **pames);
char *fs_get_sf_info(fluid_synth_t *synth, int sfid);

#endif  // __CNUFS_H__
