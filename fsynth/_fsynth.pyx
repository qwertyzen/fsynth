from libc.stdlib cimport free, malloc
from fsynth.fluidsynth cimport *

cdef extern from "fluidsynth.h":
    ctypedef void(* fluid_log_function_t) (int level, const char *message, void *data)
    cdef fluid_log_function_t fluid_set_log_function(int level, fluid_log_function_t fun, void *data)
    cdef int FLUID_PANIC
    cdef int FLUID_ERR
    cdef int FLUID_DBG
    cdef int FLUID_INFO

cdef void log_func(int level, const char *msg, void *data) noexcept:
    cdef bytes bm = msg
    if level == FLUID_PANIC:
        t = 'FLUID_PANIC'
    elif level == FLUID_ERR:
        t = 'FLUID_ERR'
    else:
        t = 'OTHER'
    print(f'Log-{t}: {bm}')

fluid_set_log_function(FLUID_PANIC, &log_func, NULL)
fluid_set_log_function(FLUID_ERR, &log_func, NULL)
fluid_set_log_function(FLUID_INFO, &log_func, NULL)

cdef extern from "cfsynth.h":
    cdef int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions)
    cdef int fs_settings_get_names(fluid_settings_t *settings, char **pames)

cdef class Settings:

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

    def set_dict(self, data: dict):
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


cdef extern from "cfsynth.h":
    cdef char *fs_get_sf_info(fluid_synth_t *synth, int sfid)
    cdef int fs_send_channel_message(fluid_synth_t *synth, const unsigned char *, int length)

cdef class Synthesizer:
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

    def noteon(self, chan: int, key: int, vel: int):
        cdef int err = fluid_synth_noteon(self.ptr, chan, key, vel)
        if err == FLUID_FAILED:
            raise RuntimeError

    def noteoff(self, chan: int, key: int):
        cdef int err = fluid_synth_noteoff(self.ptr, chan, key)
        if err == FLUID_FAILED:
            raise RuntimeError

    def cc(self, chan: int, ctrl: int, val: int):
        cdef int err = fluid_synth_cc(self.ptr, chan, ctrl, val)

    def pc(self, chan: int, prog: int):
        cdef int err = fluid_synth_program_change(self.ptr, chan, prog)

    def pitch_bend(self, chan: int, val: int):
        cdef int err = fluid_synth_pitch_bend(self.ptr, chan, val)

    def channel_pressure(self, chan: int, val: int):
        cdef int err = fluid_synth_channel_pressure(self.ptr, chan, val)

    def key_pressure(self, chan: int, key: int, val: int):
        cdef int err = fluid_synth_key_pressure(self.ptr, chan, key, val)

    def pitch_wheel_sens(self, chan: int, val: int):
        cdef int err = fluid_synth_pitch_wheel_sens(self.ptr, chan, val)

    def send_message(self, data: bytes):
        cdef const unsigned char* cmsg = data
        fs_send_channel_message(self.ptr, cmsg, len(data))

    def get_cc(self, chan: int, ctrl: int) -> int:
        cdef int val
        cdef int err = fluid_synth_get_cc(self.ptr, chan, ctrl, &val)
        if err == FLUID_FAILED:
            raise RuntimeError
        return val

    def get_pitch_bend(self, chan: int) -> int:
        cdef int pbend
        cdef int err = fluid_synth_get_pitch_bend(self.ptr, chan, &pbend)

        return pbend

    def get_pitch_wheel_sens(self, chan: int) -> int:
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

cdef class AudioDriver:

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


cdef class Player:

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

    def add_mem(self, bmidi: bytes):
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

    def set_loop(self, count: int):
        cdef int err = fluid_player_set_loop(self.ptr, count)
        if err == FLUID_FAILED:
            raise RuntimeError

    def set_tempo(self, bpm: float):
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

    def seek(self, ticks: int):
        cdef int err = fluid_player_seek(self.ptr, ticks)
        if err == FLUID_FAILED:
            raise RuntimeError

cdef class SynthTuner:

    def __cinit__(self, synth: Synthesizer):
        self.ptr = synth.ptr

    def __dealloc__(self):
        self.ptr = NULL

    def activate_key_tuning(self, bank: int, prog: int, name: str, pitch: list[float]):
        assert len(pitch) == 128
        cdef double[128] cpitch
        cdef int i
        for i in range(128):
            cpitch[i] = pitch[i]
        cdef bytes bname = name.encode('utf-8')
        cdef int err = fluid_synth_activate_key_tuning(self.ptr, bank, prog, bname, cpitch, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def activate_octave_tuning(self, bank: int, prog: int, name: str, pitch: list[float]):
        assert len(pitch) == 12
        cdef double[12] cpitch
        cdef int i
        for i in range(12):
            cpitch[i] = pitch[i]
        cdef bytes bname = name.encode('utf-8')
        cdef int err = fluid_synth_activate_octave_tuning(self.ptr, bank, prog, bname, cpitch, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def activate_tuning(self, chan: int, bank: int, prog: int):
        cdef int err = fluid_synth_activate_tuning(self.ptr, chan, bank, prog, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def deactivate_tuning(self, chan: int):
        cdef int err = fluid_synth_deactivate_tuning(self.ptr, chan, 1)
        if err == FLUID_FAILED:
            raise RuntimeError

    def tune_notes(self, bank: int, prog: int, list[int] key, pitch: list[float]):
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

    def tuning_dump(self, bank: int, prog: int, name: str) -> list[float]:
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

cdef extern from "cfsynth.h":
    cdef int fast_file_write(const char *midi_file, const char *sf_file, const char *out_wav)

def synthesize_midifile(midi_file: str, sf_file: str, out_wav: str):
    cdef bytes bmidi = midi_file.encode('utf-8')
    cdef bytes bsff = sf_file.encode('utf-8')
    cdef bytes bow = out_wav.encode('utf-8')
    cdef int err = fast_file_write(bmidi, bsff, bow)
    if err == FLUID_FAILED:
        raise OSError('Error in Midi or SF file')
