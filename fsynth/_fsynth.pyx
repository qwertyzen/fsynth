from libc.stdlib cimport free, malloc
from fsynth.fluidsynth cimport *

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
    def __cinit__(self, settings: Settings):
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

    def send_message(self, data: bytes | bytearray):
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

from cpython.ref cimport Py_INCREF, Py_DECREF


# ---------------------------------------------------------------------------
# C-level trampoline — this is the only function passed to the C library.
# `data` holds a borrowed reference to the SequencerClient Python object.
# ---------------------------------------------------------------------------
cdef void _client_callback(
    unsigned int       time,
    fluid_event_t     *event,
    fluid_sequencer_t *seq,
    void              *data
) noexcept nogil:
    with gil:
        client = <SequencerClient>data
        client._dispatch(time)


# ---------------------------------------------------------------------------
# Sequencer
# ---------------------------------------------------------------------------
cdef class Sequencer:
    """
    Wraps fluid_sequencer_t.

    One sequencer is attached to one Synthesizer.  Multiple
    SequencerClient objects register themselves against it.

    Parameters
    ----------
    synth : Synthesizer
        The synthesizer that will receive events.
    time_scale : float
        Ticks per second.  Default 1000 → 1 tick == 1 ms.
    use_system_timer : bool
        Pass True to use the system clock; False (default) uses the
        internal counter advanced by fluid_sequencer_get_tick().
    """
    cdef fluid_sequencer_t *_ptr
    cdef fluid_seq_id_t     _synth_id   # destination id for the synth
    cdef object             _synth_ref  # keep Synthesizer alive
    cdef list               _clients    # SequencerClient instances

    def __cinit__(self, synth: Synthesizer, double time_scale=1000.0,
                  bint use_system_timer=False):
        self._ptr = new_fluid_sequencer2(1 if use_system_timer else 0)
        if self._ptr is NULL:
            raise MemoryError("Could not create fluid_sequencer_t")

        fluid_sequencer_set_time_scale(self._ptr, time_scale)

        # Register the synth as a named destination
        self._synth_id  = fluid_sequencer_register_fluidsynth(
            self._ptr, synth.ptr   # accesses .ptr on your Synthesizer
        )
        self._synth_ref = synth
        self._clients   = []

    def __dealloc__(self):
        if self._ptr is not NULL:
            delete_fluid_sequencer(self._ptr)
            self._ptr = NULL

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------
    @property
    def tick(self):
        """Current sequencer tick (int)."""
        return fluid_sequencer_get_tick(self._ptr)

    @property
    def time_scale(self):
        """Ticks per second."""
        return fluid_sequencer_get_time_scale(self._ptr)

    @property
    def synth_id(self):
        return self._synth_id

    # ------------------------------------------------------------------
    # Internal — used by SequencerClient
    # ------------------------------------------------------------------
    cdef fluid_seq_id_t _register(self, SequencerClient client):
        """Register a client callback; returns its seq_id."""
        cdef bytes bname = client.name.encode("utf-8")
        # Increment ref-count so Python doesn't GC the client while C holds it
        Py_INCREF(client)
        cdef fluid_seq_id_t sid = fluid_sequencer_register_client(
            self._ptr,
            bname,
            _client_callback,
            <void *>client
        )
        self._clients.append(client)
        return sid

    cdef void _unregister(self, SequencerClient client):
        """Unregister a client and release its extra ref-count."""
        fluid_sequencer_unregister_client(self._ptr, client._seq_id)
        if client in self._clients:
            self._clients.remove(client)
        Py_DECREF(client)

    # ------------------------------------------------------------------
    # Scheduling helpers (called from Python-level client callbacks)
    # ------------------------------------------------------------------
    cpdef void send_note(self,
                         unsigned int  at_tick,
                         int           channel,
                         int           key,
                         int           velocity,
                         unsigned int  duration,
                         fluid_seq_id_t dest=-1):
        """Schedule a combined note-on + note-off event."""
        if dest < 0:
            dest = self._synth_id
        cdef fluid_event_t *evt = new_fluid_event()
        fluid_event_set_source(evt, -1)
        fluid_event_set_dest(evt, dest)
        fluid_event_note(evt, channel, <short>key, <short>velocity, duration)
        fluid_sequencer_send_at(self._ptr, evt, at_tick, 1)
        delete_fluid_event(evt)

    cpdef void send_noteon(self,
                           unsigned int  at_tick,
                           int           channel,
                           int           key,
                           int           velocity,
                           fluid_seq_id_t dest=-1):
        if dest < 0:
            dest = self._synth_id
        cdef fluid_event_t *evt = new_fluid_event()
        fluid_event_set_source(evt, -1)
        fluid_event_set_dest(evt, dest)
        fluid_event_noteon(evt, channel, <short>key, <short>velocity)
        fluid_sequencer_send_at(self._ptr, evt, at_tick, 1)
        delete_fluid_event(evt)

    cpdef void send_noteoff(self,
                            unsigned int  at_tick,
                            int           channel,
                            int           key,
                            fluid_seq_id_t dest=-1):
        if dest < 0:
            dest = self._synth_id
        cdef fluid_event_t *evt = new_fluid_event()
        fluid_event_set_source(evt, -1)
        fluid_event_set_dest(evt, dest)
        fluid_event_noteoff(evt, channel, <short>key)
        fluid_sequencer_send_at(self._ptr, evt, at_tick, 1)
        delete_fluid_event(evt)

    cpdef void send_program_change(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           program,
                                   fluid_seq_id_t dest=-1):
        if dest < 0:
            dest = self._synth_id
        cdef fluid_event_t *evt = new_fluid_event()
        fluid_event_set_source(evt, -1)
        fluid_event_set_dest(evt, dest)
        fluid_event_program_change(evt, channel, <short>program)
        fluid_sequencer_send_at(self._ptr, evt, at_tick, 1)
        delete_fluid_event(evt)

    cpdef void send_control_change(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           control,
                                   int           value,
                                   fluid_seq_id_t dest=-1):
        if dest < 0:
            dest = self._synth_id
        cdef fluid_event_t *evt = new_fluid_event()
        fluid_event_set_source(evt, -1)
        fluid_event_set_dest(evt, dest)
        fluid_event_control_change(evt, channel, <short>control, <short>value)
        fluid_sequencer_send_at(self._ptr, evt, at_tick, 1)
        delete_fluid_event(evt)

    cpdef void send_timer(self,
                          unsigned int   at_tick,
                          fluid_seq_id_t dest):
        """
        Schedule a no-op timer event that fires `dest`'s callback at
        `at_tick`.  Used by clients to reschedule themselves.
        """
        cdef fluid_event_t *evt = new_fluid_event()
        fluid_event_set_source(evt, -1)
        fluid_event_set_dest(evt, dest)
        fluid_event_timer(evt, NULL)
        fluid_sequencer_send_at(self._ptr, evt, at_tick, 1)
        delete_fluid_event(evt)


# ---------------------------------------------------------------------------
# SequencerClient  (base class — subclass in pure Python)
# ---------------------------------------------------------------------------
cdef class SequencerClient:
    """
    Base class for a sequencer client.

    Subclass this in pure Python and override ``callback(time, sequencer)``.
    The callback is responsible for:
      1. Scheduling its own MIDI events via ``sequencer.send_note(...)`` etc.
      2. Computing ``next_tick`` and calling ``self._reschedule(next_tick)``
         so the loop continues.

    Parameters
    ----------
    sequencer : Sequencer
    name : str
        Human-readable name registered with FluidSynth.
    """
    cdef public fluid_seq_id_t _seq_id
    cdef public bint            _running
    cdef public bint            muted
    cdef public str             name
    cdef public object          _sequencer   # Sequencer reference

    def __cinit__(self, sequencer, *args, **kw):
        self._seq_id    = -1
        self._running   = False
        self.muted      = False
        self.name       = kw.get('name', 'Client')
        self._sequencer = sequencer

    def __init__(self, sequencer, *args, **kw):
        pass

    # ------------------------------------------------------------------
    # Public control
    # ------------------------------------------------------------------
    def start(self, unsigned int at_tick=0):
        """Register with the sequencer and fire the first callback."""
        if self._running:
            return
        cdef Sequencer seq = <Sequencer>self._sequencer
        self._seq_id  = seq._register(self)
        self._running = True
        # Schedule the very first timer tick
        cdef unsigned int tick = at_tick if at_tick > 0 else seq.tick
        seq.send_timer(tick, self._seq_id)

    def stop(self):
        """Unregister from the sequencer; no more callbacks will fire."""
        if not self._running:
            return
        self._running = False
        cdef Sequencer seq = <Sequencer>self._sequencer
        seq._unregister(self)
        self._seq_id = -1

    def mute(self):
        """Silence this client (callback loop keeps running)."""
        self.muted = True

    def unmute(self):
        """Resume note output."""
        self.muted = False

    def toggle_mute(self):
        self.muted = not self.muted

    # ------------------------------------------------------------------
    # Called from the C trampoline — do not override
    # ------------------------------------------------------------------
    cdef void _dispatch(self, unsigned int time):
        if not self._running:
            return
        try:
            self.callback(time, self._sequencer)
        except Exception as exc:
            # Swallow exceptions — we are inside a C callback.
            # Override _on_error() to handle them your way.
            self._on_error(exc)

    # ------------------------------------------------------------------
    # Override in subclasses
    # ------------------------------------------------------------------
    def callback(self, unsigned int time, sequencer):
        """
        Override this method.

        Parameters
        ----------
        time : int
            The tick at which this callback was triggered.
        sequencer : Sequencer
            The sequencer; use its send_* helpers to schedule events.

        You MUST call self._reschedule(next_tick) before returning,
        otherwise the client goes silent.
        """
        raise NotImplementedError

    def _on_error(self, exc):
        """Called when callback() raises.  Override to log or re-raise."""
        import traceback
        traceback.print_exc()

    # ------------------------------------------------------------------
    # Helper for subclasses
    # ------------------------------------------------------------------
    cpdef void _reschedule(self, unsigned int next_tick):
        """Schedule the next timer callback for this client."""
        if not self._running:
            return
        (<Sequencer>self._sequencer).send_timer(next_tick, self._seq_id)
