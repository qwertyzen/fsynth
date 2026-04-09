#include <stdlib.h>
#include <string.h>
#include "cfsynth.h"

typedef struct {
    int count;
    char *buf;
} IterVar;

static void settings_option_foreach_func(void *data, const char *name, const char *option)
{
    (void) name;
    IterVar *iter = data;
    strcat(iter->buf, option);
    strcat(iter->buf, "\n");
}

static void settings_foreach_func(void *data, const char *name, int type)
{
    IterVar *iter = data;
    strcat(iter->buf, name);
    strcat(iter->buf, "\n");
}

int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions)
{
    if (!settings) goto fn_fail;
    if (poptions == NULL || *poptions != NULL) goto fn_fail;
    int count = fluid_settings_option_count(settings, cname);
    size_t buffer_size = 256;
    IterVar iter = {
        .count = count,
        .buf = calloc(buffer_size, sizeof(char))
    };
    fluid_settings_foreach_option(settings, cname, &iter, settings_option_foreach_func);
    *poptions = iter.buf;
    return FLUID_OK;
fn_fail:
    return FLUID_FAILED;
}

int fs_settings_get_names(fluid_settings_t *settings, char **pnames)
{
    if (!settings) goto fn_fail;
    if (pnames == NULL || *pnames != NULL) goto fn_fail;
    IterVar iter = {
        .buf=calloc(1024*4, sizeof(char))
    };
    fluid_settings_foreach(settings, &iter, settings_foreach_func);
    *pnames = iter.buf;
    return FLUID_OK;
fn_fail:
    return FLUID_FAILED;
}

char *fs_get_sf_info(fluid_synth_t *synth, int sfid)
{
    fluid_sfont_t *sfont = fluid_synth_get_sfont_by_id(synth, sfid);
    if (sfont == NULL) {
        fprintf(stderr, "Failed to load soundfont.\n");
        return NULL;
    }

    fluid_preset_t* preset = NULL;

    size_t buffer_size = 256, used_size = 0;
    char* sf_info_str = calloc(buffer_size, sizeof(char));
    if (!sf_info_str) {
        return NULL;
    }

    const char *preset_name;
    int bank_num, preset_num;
    fluid_sfont_iteration_start(sfont);

    while ((preset = fluid_sfont_iteration_next(sfont)) != NULL) {
        if (preset == NULL) break;

        preset_name = fluid_preset_get_name(preset);
        bank_num = fluid_preset_get_banknum(preset);
        preset_num = fluid_preset_get_num(preset);

        size_t entry_length = snprintf(NULL, 0, "%d-%d: %s\n", bank_num, preset_num, preset_name) + 1;

        if (used_size + entry_length >= buffer_size) {
            buffer_size *= 2;
            char* temp = realloc(sf_info_str, buffer_size);
            if (!temp) {
                free(sf_info_str);
                return NULL;
            }
            sf_info_str = temp;
        }

        snprintf(sf_info_str + used_size, entry_length, "%d-%d: %s\n", bank_num, preset_num, preset_name);
        used_size += entry_length - 1;
    }
    return sf_info_str;
}

int fast_file_write(const char *midi_file, const char *sf_file, const char *out_wav)
{
    fluid_settings_t* settings;
    fluid_synth_t* synth;
    fluid_player_t* player;
    fluid_file_renderer_t* renderer;
    int id;

    if ( !( fluid_is_midifile(midi_file) && fluid_is_soundfont(sf_file) ) )
        return FLUID_FAILED;

    settings = new_fluid_settings();
    fluid_settings_setstr(settings, "audio.file.name", out_wav);
    fluid_settings_setstr(settings, "player.timing-source", "sample");
    fluid_settings_setint(settings, "synth.lock-memory", 0);

    synth = new_fluid_synth(settings);
    id = fluid_synth_sfload(synth, sf_file, 1);

    player = new_fluid_player(synth);
    fluid_player_add(player, midi_file);
    fluid_player_play(player);

    renderer = new_fluid_file_renderer (synth);

    while (fluid_player_get_status(player) == FLUID_PLAYER_PLAYING)
    {
        if (fluid_file_renderer_process_block(renderer) != FLUID_OK)
        {
            break;
        }
    }

    fluid_player_stop(player);
    fluid_player_join(player);

    fluid_synth_sfunload(synth, id, 0);
    delete_fluid_file_renderer(renderer);
    delete_fluid_player(player);
    delete_fluid_synth(synth);
    delete_fluid_settings(settings);
    return FLUID_OK;
}

#define _NOTE_OFF             0x80
#define _NOTE_ON              0x90
#define _CONTROL_CHANGE       0xb0
#define _PROGRAM_CHANGE       0xc0
#define _PITCH_BEND           0xe0
#define _POLY_TOUCH           0xa0
#define _AFTER_TOUCH          0xd0

int fs_send_channel_message(fluid_synth_t *synth, const unsigned char *data, int length)
{
    int err = FLUID_FAILED;
    int status = data[0] & 0xF0;
    int channel = data[0] & 0x0F;
    switch(status) {
        case _NOTE_OFF:
            err = fluid_synth_noteoff(synth, channel, data[1]);
            break;
        case _NOTE_ON:
            err = fluid_synth_noteon(synth, channel, data[1], data[2]);
            break;
        case _CONTROL_CHANGE:
            err = fluid_synth_cc(synth, channel, data[1], data[2]);
            break;
        case _PROGRAM_CHANGE:
            err = fluid_synth_program_change(synth, channel, data[1]);
            break;
        case _POLY_TOUCH:
            err = fluid_synth_key_pressure(synth, channel, data[1], data[2]);
            break;
        case _AFTER_TOUCH:
            err = fluid_synth_channel_pressure(synth, channel, data[1]);
            break;
    }
    return err;
}
