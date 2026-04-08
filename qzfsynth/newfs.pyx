from libc.stdlib cimport free, malloc

cdef extern from "fluidsynth.h":
    cdef void fluid_version(int *major, int *minor, int *micro)
    cdef int FLUID_OK
    cdef int FLUID_FAILED
    cdef int FLUID_NO_TYPE
    cdef int FLUID_NUM_TYPE
    cdef int FLUID_INT_TYPE
    cdef int FLUID_STR_TYPE
    cdef int FLUID_SET_TYPE
    struct fluid_settings_s
    ctypedef fluid_settings_s fluid_settings_t
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

cdef extern from "cnufs.h":
    cdef int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions)
    cdef int fs_settings_get_names(fluid_settings_t *settings, char **pames)

cdef class Settings:
    cdef fluid_settings_t *ptr
    cdef str _setting_names

    def __cinit__(self):
        self.ptr = new_fluid_settings()
        if not self.ptr:
            raise RuntimeError
        self._get_names()

    def __dealloc__(self):
        if self.ptr:
            delete_fluid_settings(self.ptr)
            self.ptr = NULL

    cdef _get_names(self):
        cdef int err
        cdef char *c_names = NULL
        err = fs_settings_get_names(self.ptr, &c_names)
        if err != FLUID_OK:
            raise Exception
        cdef bytes b_names = c_names
        self._setting_names = b_names.decode('utf-8').strip()
        free(c_names)

    @property
    def names(self) -> list[str]:
        return self._setting_names.split('\n')

    def get(self, name: str) -> str | int | float:
        cdef bytes bname = name.encode('utf-8')

        cdef int err
        cdef char[256] cvalue
        cdef str strval
        cdef int intval
        cdef double floatval
        cdef int setting_type = fluid_settings_get_type(self.ptr, bname)
        if setting_type == FLUID_INT_TYPE:
            err = fluid_settings_getint(self.ptr, bname, &intval)
            if err != FLUID_OK:
                raise ValueError
            return intval
        elif setting_type == FLUID_NUM_TYPE:
            err = fluid_settings_getnum(self.ptr, bname, &floatval)
            if err != FLUID_OK:
                raise ValueError
            return floatval
        elif setting_type == FLUID_STR_TYPE:
            err = fluid_settings_copystr(self.ptr, bname, cvalue, 256)
            strval = cvalue.decode('utf-8')
            return strval
        else:
            print('Error', name, 'type', setting_type)
        raise TypeError

    def set(self, name: str, value: str | int | float):
        cdef bytes bname = name.encode('utf-8')
        cdef const char *cname = bname

        cdef bytes csetval
        if type(value) is int:
            err = fluid_settings_setint(self.ptr, cname, value)
        elif type(value) is float:
            err = fluid_settings_setnum(self.ptr, cname, value)
        elif type(value) is str:
            csetval = value.encode('utf-8')
            err = fluid_settings_setstr(self.ptr, cname, csetval)
        else:
            raise TypeError
        if err != FLUID_OK:
            raise ValueError

    def set_dict(self, dict data):
        for key, val in data.items():
            self.set(key, val)

    def get_all(self) -> dict:
        se = {}
        for item in self.names:
            val = self.get(item)
            se[item] = val
        return se

    def get_default(self, name: str) -> str | int | float:
        cdef bytes bname = name.encode('utf-8')

        cdef int err
        cdef char *cvalue
        cdef str strval
        cdef int intval
        cdef double floatval
        cdef int setting_type = fluid_settings_get_type(self.ptr, bname)
        if setting_type == FLUID_INT_TYPE:
            err = fluid_settings_getint_default(self.ptr, bname, &intval)
            if err != FLUID_OK:
                raise ValueError
            return intval
        elif setting_type == FLUID_NUM_TYPE:
            err = fluid_settings_getnum_default(self.ptr, bname, &floatval)
            if err != FLUID_OK:
                raise ValueError
            return floatval
        elif setting_type == FLUID_STR_TYPE:
            err = fluid_settings_getstr_default(self.ptr, bname, &cvalue)
            strval = cvalue.decode('utf-8')
            return strval
        raise TypeError

    def get_all_defaults(self) -> dict:
        d = {}
        for item in self.names:
            d[item] = self.get_default(item)
        return d

    def get_range(self, name: str) -> tuple[int, int] | tuple[float, float]:
        cdef bytes bname = name.encode('utf-8')

        cdef int err
        cdef int imax, imin
        cdef double fmax, fmin
        cdef int setting_type = fluid_settings_get_type(self.ptr, bname)
        if setting_type == FLUID_INT_TYPE:
            err = fluid_settings_getint_range(self.ptr, bname, &imin, &imax)
            if err != FLUID_OK:
                raise ValueError
            return imin, imax
        elif setting_type == FLUID_NUM_TYPE:
            err = fluid_settings_getnum_range(self.ptr, bname, &fmin, &fmax)
            if err != FLUID_OK:
                raise ValueError
            return fmin, fmax
        else:
            raise TypeError

    def get_options(self, name: str) -> list[str]:
        cdef int err
        cdef bytes bname = name.encode('utf-8')
        cdef char *copts = NULL

        err = fs_settings_get_options(self.ptr, bname, &copts)
        if err != FLUID_OK:
            raise Exception
        cdef bytes bopts = copts
        cdef str opts = bopts.decode('utf-8').strip()
        free(copts)
        return opts.split('\n')

    def is_realtime(self, name: str) -> int:
        cdef int isrt
        cdef bytes bname = name.encode('utf-8')
        print(self.get(name))
        isrt = fluid_settings_is_realtime(self.ptr, bname)
        return isrt

def enumerate_audio_devices(audio_driver: str = None) -> list[str]:
    settings = Settings()
    if not audio_driver:
        audio_driver = settings.get('audio.driver')
    adriver = f'audio.{audio_driver}.device'
    devices = settings.get_options(adriver)
    return devices

cdef extern from 'fluidsynth.h':
    struct fluid_synth_s
    ctypedef fluid_synth_s fluid_synth_t
    cdef fluid_synth_t *new_fluid_synth (fluid_settings_t *settings)
    cdef void delete_fluid_synth (fluid_synth_t *synth)
    struct fluid_sfont_s
    ctypedef fluid_sfont_s fluid_sfont_t
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

cdef extern from "cnufs.h":
    cdef char *fs_get_sf_info(fluid_synth_t *synth, int sfid)

cdef class Synthesizer:
    cdef fluid_synth_t *ptr
    cdef Settings settings
    cdef int sfid
    cdef fluid_sfont_t *sfont
    cdef str sf_info_str

    def __cinit__(self, settings):
        self.settings = settings
        self.ptr = new_fluid_synth(self.settings.ptr)
        self.sfid = FLUID_FAILED
        if not self.ptr:
            raise RuntimeError

    def __dealloc__(self):
        if self.ptr:
            delete_fluid_synth(self.ptr)

    def sfload(self, filename: str) -> None:
        if self.sfid != FLUID_FAILED:
            self.sfunload()
        cdef bytes path = filename.encode('utf-8')
        self.sfid = fluid_synth_sfload(self.ptr, path, 1)
        if self.sfid == FLUID_FAILED:
            raise RuntimeError
        self.sfont = fluid_synth_get_sfont_by_id(self.ptr, self.sfid)
        if not self.sfont:
            raise RuntimeError
        cdef char *csf_info = fs_get_sf_info(self.ptr, self.sfid)
        if not csf_info:
            raise RuntimeError
        cdef bytes bsf_info = csf_info
        self.sf_info_str = bsf_info.decode('utf-8')

    @property
    def sf_info(self) -> list[str] | None:
        if self.sfid:
            return self.sf_info_str.split('\n')

    def sfunload(self):
        cdef int err = FLUID_OK
        if self.sfid != FLUID_FAILED:
            err = fluid_synth_sfunload(self.ptr, self.sfid, 1)
        self.sfid = FLUID_FAILED
        self.sfont = NULL
        self.sf_info_str = None
        if err == FLUID_FAILED:
            raise RuntimeError

    def noteon(self, int chan, int key, int vel):
        cdef int err = fluid_synth_noteon(self.ptr, chan, key, vel)
        if err == FLUID_FAILED:
            raise RuntimeError

    def noteoff(self, int chan, int key):
        cdef int err = fluid_synth_noteoff(self.ptr, chan, key)
        if err == FLUID_FAILED:
            raise RuntimeError

    def cc(self, int chan, int ctrl, int val):
        cdef int err = fluid_synth_cc(self.ptr, chan, ctrl, val)

    def pc(self, int chan, int prog):
        cdef int err = fluid_synth_program_change(self.ptr, chan, prog)

    def pitch_bend(self, int chan, int val):
        cdef int err = fluid_synth_pitch_bend(self.ptr, chan, val)

    def channel_pressure(self, int chan, int val):
        cdef int err = fluid_synth_channel_pressure(self.ptr, chan, val)

    def key_pressure(self, int chan, int key, int val):
        cdef int err = fluid_synth_key_pressure(self.ptr, chan, key, val)

    def pitch_wheel_sens(self, int chan, int val):
        cdef int err = fluid_synth_pitch_wheel_sens(self.ptr, chan, val)

    def get_cc(self, int chan, int ctrl) -> int:
        cdef int val
        cdef int err = fluid_synth_get_cc(self.ptr, chan, ctrl, &val)
        if err == FLUID_FAILED:
            raise RuntimeError
        return val

    def get_pitch_bend(self, int chan) -> int:
        cdef int pbend
        cdef int err = fluid_synth_get_pitch_bend(self.ptr, chan, &pbend)

        return pbend

    def get_pitch_wheel_sens(self, int chan) -> int:
        cdef int pws
        cdef int err = fluid_synth_get_pitch_wheel_sens(self.ptr, chan, &pws)

        return pws

    def system_reset(self):
        cdef int err = fluid_synth_system_reset(self.ptr)

    def get_cpu_load(self) -> float:
        return fluid_synth_get_cpu_load(self.ptr)

    # def add_sfont_other(self, synth: Synthesizer):
    #     self.sfunload()
    #     cdef int err = fluid_synth_add_sfont(self.ptr, synth.sfont)
    #     if err == FLUID_FAILED:
    #         raise RuntimeError

cdef extern from "fluidsynth.h":
    struct fluid_audio_driver_s
    ctypedef fluid_audio_driver_s fluid_audio_driver_t
    cdef fluid_audio_driver_t *new_fluid_audio_driver(fluid_settings_t *settings,
        fluid_synth_t *synth)
    cdef void delete_fluid_audio_driver	(	fluid_audio_driver_t * 	driver	)

cdef class AudioDriver:
    cdef fluid_audio_driver_t *ptr
    cdef Settings settings
    cdef Synthesizer synth

    def __cinit__(self, settings: Settings, synth: Synthesizer):
        self.settings = settings
        self.synth = synth
        self.ptr = new_fluid_audio_driver(self.settings.ptr, self.synth.ptr)
        if not self.ptr:
            raise RuntimeError

    def __dealloc__(self):
        if self.ptr:
            delete_fluid_audio_driver(self.ptr)
            self.ptr = NULL

cdef extern from "fluidsynth.h":
    struct fluid_player_s
    ctypedef fluid_player_s fluid_player_t
    cdef fluid_player_t *new_fluid_player(fluid_synth_t *synth)
    cdef void delete_fluid_player(fluid_player_t *player)
    cdef int fluid_player_add(fluid_player_t *player, const char *midifile)
    cdef int fluid_player_add_mem(fluid_player_t *player, const void *buffer, size_t len)
    cdef int fluid_player_play(fluid_player_t *player)
    cdef int fluid_player_stop(fluid_player_t *player)
    cdef int fluid_player_join(fluid_player_t *player)
    cdef int fluid_player_set_loop(fluid_player_t *player, int loop)
    cdef int fluid_player_set_tempo(fluid_player_t *player, int tempo_type, double tempo)
    struct fluid_midi_event_s
    ctypedef fluid_midi_event_s fluid_midi_event_t
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

cdef class Player:
    cdef fluid_player_t *ptr
    cdef Synthesizer synth

    def __cinit__(self, synth: Synthesizer):
        self.synth = synth
        self.ptr = new_fluid_player(synth.ptr)
        if not self.ptr:
            raise RuntimeError

    def __dealloc__(self):
        if self.ptr:
            delete_fluid_player(self.ptr)
            self.ptr = NULL

    def add(self, midi_file: str):
        cdef bytes bfile = midi_file.encode('utf-8')
        cdef int err = fluid_player_add(self.ptr, bfile)
        if err == FLUID_FAILED:
            raise RuntimeError

    def add_mem(self, bytes bmidi):
        cdef const void *cmidi = <void *> bmidi
        cdef int err = fluid_player_add_mem(self.ptr, cmidi, len(bmidi))
        if err == FLUID_FAILED:
            raise RuntimeError

    def play(self):
        cdef int err = fluid_player_play(self.ptr)
        if err == FLUID_FAILED:
            raise RuntimeError

    def stop(self):
        cdef int err = fluid_player_stop(self.ptr)
        if err == FLUID_FAILED:
            raise RuntimeError

    def join(self):
        cdef int err = fluid_player_join(self.ptr)
        if err == FLUID_FAILED:
            raise RuntimeError

    def set_loop(self, int count):
        cdef int err = fluid_player_set_loop(self.ptr, count)
        if err == FLUID_FAILED:
            raise RuntimeError

    def set_tempo(self, float bpm):
        cdef int err = fluid_player_set_tempo(self.ptr, FLUID_PLAYER_TEMPO_EXTERNAL_BPM, bpm)
        if err == FLUID_FAILED:
            raise RuntimeError

    def get_current_tick(self) -> int:
        cdef int err = fluid_player_get_current_tick(self.ptr)
        if err == FLUID_FAILED:
            raise RuntimeError
        return err

    def get_total_ticks(self) -> int:
        cdef int err = fluid_player_get_total_ticks(self.ptr)
        if err == FLUID_FAILED:
            raise RuntimeError
        return err

    def is_playing(self) -> bool:
        cdef int sta = fluid_player_get_status(self.ptr)
        if sta == FLUID_PLAYER_PLAYING:
            return True
        return False

    def get_bpm(self):
        cdef int err = fluid_player_get_bpm(self.ptr)
        if err == FLUID_FAILED:
            raise RuntimeError

    def seek(self, int ticks):
        cdef int err = fluid_player_seek(self.ptr, ticks)
        if err == FLUID_FAILED:
            raise RuntimeError

cdef extern from "fluidsynth.h":

    cdef int fluid_synth_activate_key_tuning(fluid_synth_t *synth, int bank, int prog, const char *name, const double *pitch, int apply)
    cdef int fluid_synth_activate_octave_tuning(fluid_synth_t *synth, int bank, int prog, const char *name, const double *pitch, int apply)
    cdef int fluid_synth_tune_notes(fluid_synth_t *synth, int bank, int prog, int len, const int *keys, const double *pitch, int apply)
    cdef int fluid_synth_activate_tuning(fluid_synth_t *synth, int chan, int bank, int prog, int apply)
    cdef int fluid_synth_deactivate_tuning(fluid_synth_t *synth, int chan, int apply)
    cdef void fluid_synth_tuning_iteration_start(fluid_synth_t *synth)
    cdef int fluid_synth_tuning_iteration_next(fluid_synth_t *synth, int *bank, int *prog)
    cdef int fluid_synth_tuning_dump(fluid_synth_t *synth, int bank, int prog, char *name, int len, double *pitch)

cdef class SynthTuner:
    cdef fluid_synth_t *ptr

    def __cinit__(self, synth: Synthesizer):
        self.ptr = synth.ptr

    def __dealloc__(self):
        self.ptr = NULL

    def activate_key_tuning(self, int bank, int prog, str name, list[float] pitch):
        assert len(pitch) == 128
        cdef double[128] cpitch
        cdef int i
        for i in range(128):
            cpitch[i] = pitch[i]
        cdef bytes bname = name.encode('utf-8')
        cdef int err = fluid_synth_activate_key_tuning(self.ptr, bank, prog, bname, cpitch, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def activate_octave_tuning(self, int bank, int prog, str name, list[float] pitch):
        assert len(pitch) == 12
        cdef double[12] cpitch
        cdef int i
        for i in range(12):
            cpitch[i] = pitch[i]
        cdef bytes bname = name.encode('utf-8')
        cdef int err = fluid_synth_activate_octave_tuning(self.ptr, bank, prog, bname, cpitch, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def activate_tuning(self, int chan, int bank, int prog):
        cdef int err = fluid_synth_activate_tuning(self.ptr, chan, bank, prog, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def deactivate_tuning(self, int chan):
        cdef int err = fluid_synth_deactivate_tuning(self.ptr, chan, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def tune_notes(self, int bank, int prog, list[int] key, list[float] pitch):
        l = len(key)
        assert l == len(pitch)
        cdef int i
        cdef int *ckey = <int *> malloc(l * sizeof(int))
        cdef double *cpitch = <double *> malloc(l * sizeof(double))
        for i in range(l):
            ckey[i] = key[i]
            cpitch[i] = pitch[i]
        cdef int err = fluid_synth_tune_notes(self.ptr, bank, prog, l, ckey, cpitch, 1)
        if err == FLUID_FAILED:
            raise RuntimeError
        free(cpitch)
        free(ckey)

    def tuning_dump(self, int bank, int prog, str name) -> list[float]:
        cdef bytes bname = name.encode('utf-8')
        cdef double[128] cpitch
        cdef int err = fluid_synth_tuning_dump(self.ptr, bank, prog, bname, len(bname), cpitch)
        if err == FLUID_FAILED:
            raise RuntimeError
        return [p for p in cpitch]

    def get_tuning_banks(self) -> list[tuple[int, int]]:
        ls = list()
        fluid_synth_tuning_iteration_start(self.ptr)
        cdef int bank = -1
        cdef int prog = -1
        cdef int state
        while True:
            state = fluid_synth_tuning_iteration_next(self.ptr, &bank, &prog)
            if state != 1:
                break
            ls.append((bank, prog))
        return ls

cdef extern from "cnufs.h":
    cdef int fast_file_write(const char *midi_file, const char *sf_file, const char *out_wav)

def synthesize_midifile(midi_file: str, sf_file: str, out_wav: str):
    cdef bytes bmidi = midi_file.encode('utf-8')
    cdef bytes bsff = sf_file.encode('utf-8')
    cdef bytes bow = out_wav.encode('utf-8')
    cdef int err = fast_file_write(bmidi, bsff, bow)
    if err == FLUID_FAILED:
        raise OSError('Error in Midi or SF file')
