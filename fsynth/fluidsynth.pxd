cdef extern from "fluidsynth.h":
    cdef void fluid_version(int *major, int *minor, int *micro)
    cdef int FLUID_OK
    cdef int FLUID_FAILED
    cdef int FLUID_NO_TYPE
    cdef int FLUID_NUM_TYPE
    cdef int FLUID_INT_TYPE
    cdef int FLUID_STR_TYPE
    cdef int FLUID_SET_TYPE
    ctypedef struct fluid_settings_t
    cdef fluid_settings_t *new_fluid_settings()
    cdef void delete_fluid_settings(fluid_settings_t *settings)

    cdef int fluid_settings_get_type(fluid_settings_t *settings, const char *name)
    cdef int fluid_settings_get_hints(fluid_settings_t *settings, const char *name, int *val)
    cdef int fluid_settings_is_realtime(fluid_settings_t *settings, const char *name)
    cdef int fluid_settings_setstr(fluid_settings_t *settings, const char *name, const char *str)
    cdef int fluid_settings_copystr(fluid_settings_t *settings, const char *name, char *str, int len)
    cdef int fluid_settings_dupstr(fluid_settings_t *settings, const char *name, char **str)
    cdef int fluid_settings_getstr_default(fluid_settings_t *settings, const char *name, char **default)
    cdef int fluid_settings_str_equal(fluid_settings_t *settings, const char *name, const char *value)
    cdef int fluid_settings_setnum(fluid_settings_t *settings, const char *name, double val)
    cdef int fluid_settings_getnum(fluid_settings_t *settings, const char *name, double *val)
    cdef int fluid_settings_getnum_default(fluid_settings_t *settings, const char *name, double *val)
    cdef int fluid_settings_getnum_range(fluid_settings_t *settings, const char *namem,
                                double *min, double *max)
    cdef int fluid_settings_setint(fluid_settings_t *settings, const char *name, int val)
    cdef int fluid_settings_getint(fluid_settings_t *settings, const char *name, int *val)
    cdef int fluid_settings_getint_default(fluid_settings_t *settings, const char *name, int *val)
    cdef int fluid_settings_getint_range(fluid_settings_t *settings, const char *name, int *min, int *max)

    ctypedef void (*fluid_settings_foreach_option_t)(void *data, const char *name, const char *option);


    cdef void fluid_settings_foreach_option(fluid_settings_t *settings,
                                   const char *name, void *data,
                                   fluid_settings_foreach_option_t func);

    cdef int fluid_settings_option_count(fluid_settings_t *settings, const char *name);
    cdef char *fluid_settings_option_concat(fluid_settings_t *settings,
        const char *name,
        const char *separator);

    ctypedef void (*fluid_settings_foreach_t)(void *data, const char *name, int type);

    cdef void fluid_settings_foreach(fluid_settings_t *settings, void *data,
                            fluid_settings_foreach_t func);

cdef extern from 'fluidsynth.h':
    ctypedef struct fluid_synth_t
    cdef fluid_synth_t *new_fluid_synth (fluid_settings_t *settings)
    cdef void delete_fluid_synth (fluid_synth_t *synth)
    ctypedef struct fluid_sfont_t
    cdef int fluid_synth_sfload(fluid_synth_t *synth, const char *filename, int reset_presets)
    cdef int fluid_synth_sfunload(fluid_synth_t *synth, int id, int reset_presets)
    cdef fluid_sfont_t *fluid_synth_get_sfont_by_id (fluid_synth_t *synth, int id)
    cdef int fluid_synth_add_sfont (fluid_synth_t *synth, fluid_sfont_t *sfont)
    cdef int fluid_synth_get_bank_offset (fluid_synth_t *synth, int sfont_id)
    cdef int fluid_synth_sfcount(fluid_synth_t *synth)

    cdef int fluid_synth_noteon(fluid_synth_t *synth, int chan, int key, int vel)
    cdef int fluid_synth_noteoff(fluid_synth_t *synth, int chan, int key)
    cdef int fluid_synth_cc(fluid_synth_t *synth, int chan, int ctrl, int val)
    cdef int fluid_synth_get_cc(fluid_synth_t *synth, int chan, int ctrl, int *pval)
    cdef int fluid_synth_sysex(fluid_synth_t *synth, const char *data, int len,
                                     char *response, int *response_len, int *handled, int dryrun)
    cdef int fluid_synth_pitch_bend(fluid_synth_t *synth, int chan, int val)
    cdef int fluid_synth_get_pitch_bend(fluid_synth_t *synth, int chan, int *ppitch_bend)
    cdef int fluid_synth_pitch_wheel_sens(fluid_synth_t *synth, int chan, int val)
    cdef int fluid_synth_get_pitch_wheel_sens(fluid_synth_t *synth, int chan, int *pval)
    cdef int fluid_synth_program_change(fluid_synth_t *synth, int chan, int program)
    cdef int fluid_synth_channel_pressure(fluid_synth_t *synth, int chan, int val)
    cdef int fluid_synth_key_pressure(fluid_synth_t *synth, int chan, int key, int val)
    cdef int fluid_synth_bank_select(fluid_synth_t *synth, int chan, int bank)
    cdef int fluid_synth_sfont_select(fluid_synth_t *synth, int chan, int sfont_id)

    cdef int fluid_synth_program_select(fluid_synth_t *synth, int chan, int sfont_id,
                               int bank_num, int preset_num)
    cdef int fluid_synth_program_select_by_sfont_name(fluid_synth_t *synth, int chan,
        const char *sfont_name, int bank_num,
        int preset_num)

    cdef int fluid_synth_get_program(fluid_synth_t *synth, int chan, int *sfont_id,
                            int *bank_num, int *preset_num);
    cdef int fluid_synth_unset_program(fluid_synth_t *synth, int chan);
    cdef int fluid_synth_program_reset(fluid_synth_t *synth);
    cdef int fluid_synth_system_reset(fluid_synth_t *synth);

    cdef int fluid_synth_all_notes_off(fluid_synth_t *synth, int chan);
    cdef int fluid_synth_all_sounds_off(fluid_synth_t *synth, int chan);

    cdef int fluid_synth_set_gen(fluid_synth_t *synth, int chan,
                                       int param, float value);
    cdef float fluid_synth_get_gen(fluid_synth_t *synth, int chan, int param);
    cdef double fluid_synth_get_cpu_load(fluid_synth_t *synth)

cdef extern from "fluidsynth.h":
    ctypedef struct fluid_audio_driver_t
    cdef fluid_audio_driver_t *new_fluid_audio_driver(fluid_settings_t *settings,
        fluid_synth_t *synth)
    cdef void delete_fluid_audio_driver	(	fluid_audio_driver_t * 	driver	)

cdef extern from "fluidsynth.h":
    ctypedef struct fluid_player_t
    cdef fluid_player_t *new_fluid_player(fluid_synth_t *synth)
    cdef void delete_fluid_player(fluid_player_t *player)
    cdef int fluid_player_add(fluid_player_t *player, const char *midifile)
    cdef int fluid_player_add_mem(fluid_player_t *player, const void *buffer, size_t len)
    cdef int fluid_player_play(fluid_player_t *player)
    cdef int fluid_player_stop(fluid_player_t *player)
    cdef int fluid_player_join(fluid_player_t *player)
    cdef int fluid_player_set_loop(fluid_player_t *player, int loop)
    cdef int fluid_player_set_tempo(fluid_player_t *player, int tempo_type, double tempo)
    ctypedef struct fluid_midi_event_t
    ctypedef int (*handle_midi_event_func_t)(void *data, fluid_midi_event_t *event);
    ctypedef int (*handle_midi_tick_func_t)(void *data, int tick)
    cdef int fluid_player_set_playback_callback(fluid_player_t *player, handle_midi_event_func_t handler, void *handler_data)
    cdef int fluid_player_set_tick_callback(fluid_player_t *player, handle_midi_tick_func_t handler, void *handler_data)
    cdef int fluid_player_get_status(fluid_player_t *player)
    cdef int fluid_player_get_current_tick(fluid_player_t *player)
    cdef int fluid_player_get_total_ticks(fluid_player_t *player)
    cdef int fluid_player_get_bpm(fluid_player_t *player)
    cdef int fluid_player_get_division(fluid_player_t *player)
    cdef int fluid_player_get_midi_tempo(fluid_player_t *player)
    cdef int fluid_player_seek(fluid_player_t *player, int ticks)
    cdef int FLUID_PLAYER_TEMPO_EXTERNAL_BPM
    cdef int FLUID_PLAYER_PLAYING

cdef extern from "fluidsynth.h":

    cdef int fluid_synth_activate_key_tuning(fluid_synth_t *synth, int bank, int prog, const char *name, const double *pitch, int apply)
    cdef int fluid_synth_activate_octave_tuning(fluid_synth_t *synth, int bank, int prog, const char *name, const double *pitch, int apply)
    cdef int fluid_synth_tune_notes(fluid_synth_t *synth, int bank, int prog, int len, const int *keys, const double *pitch, int apply)
    cdef int fluid_synth_activate_tuning(fluid_synth_t *synth, int chan, int bank, int prog, int apply)
    cdef int fluid_synth_deactivate_tuning(fluid_synth_t *synth, int chan, int apply)
    cdef void fluid_synth_tuning_iteration_start(fluid_synth_t *synth)
    cdef int fluid_synth_tuning_iteration_next(fluid_synth_t *synth, int *bank, int *prog)
    cdef int fluid_synth_tuning_dump(fluid_synth_t *synth, int bank, int prog, char *name, int len, double *pitch)

