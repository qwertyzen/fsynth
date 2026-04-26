#ifndef __CFSYNTH_H__
#define __CFSYNTH_H__

#include "fluidsynth.h"

int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions);
int fs_settings_get_names(fluid_settings_t *settings, char **pames);
char *fs_get_sf_info(fluid_synth_t *synth, int sfid);
int fast_file_write(const char *midi_file, const char *sf_file, const char *out_wav);
int fs_send_channel_message(fluid_synth_t *synth, const unsigned char *data, int length);
int fs_send_message_list(fluid_synth_t *synth, const unsigned char **data, int *msg_lens, int len);

#endif  // __CFSYNTH_H__
