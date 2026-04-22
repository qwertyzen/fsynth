from fsynth.fluidsynth cimport *

cdef class Settings:
    cdef fluid_settings_t *ptr
    cdef str _setting_names

    cdef _get_names(self)

cdef class Synthesizer:
    cdef fluid_synth_t *ptr
    cdef Settings settings
    cdef int sfid
    cdef fluid_sfont_t *sfont
    cdef str sf_info_str

cdef class AudioDriver:
    cdef fluid_audio_driver_t *ptr
    cdef Settings settings
    cdef Synthesizer synth

cdef class Player:
    cdef fluid_player_t *ptr
    cdef Synthesizer synth

cdef class SynthTuner:
    cdef fluid_synth_t *ptr

cdef class SequencerClient:
    cdef public fluid_seq_id_t _seq_id
    cdef public bint            _running
    cdef public bint            muted
    cdef public str             name
    cdef public object          _sequencer   # Sequencer reference
    cdef void _dispatch(self, unsigned int time)
    cpdef void _reschedule(self, unsigned int next_tick)

cdef class Sequencer:
    cdef fluid_sequencer_t *_ptr
    cdef fluid_seq_id_t     _synth_id   # destination id for the synth
    cdef object             _synth_ref  # keep Synthesizer alive
    cdef list               _clients    # SequencerClient instances
    cdef fluid_seq_id_t _register(self, SequencerClient client)
    cdef void _unregister(self, SequencerClient client)
    cpdef void send_note(self,
                         unsigned int  at_tick,
                         int           channel,
                         int           key,
                         int           velocity,
                         unsigned int  duration,
                         fluid_seq_id_t dest=*)
    cpdef void send_noteon(self,
                           unsigned int  at_tick,
                           int           channel,
                           int           key,
                           int           velocity,
                           fluid_seq_id_t dest=*)
    cpdef void send_noteoff(self,
                            unsigned int  at_tick,
                            int           channel,
                            int           key,
                            fluid_seq_id_t dest=*)
    cpdef void send_program_change(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           program,
                                   fluid_seq_id_t dest=*)
    cpdef void send_control_change(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           control,
                                   int           value,
                                   fluid_seq_id_t dest=*)
    cpdef void send_timer(self,
                          unsigned int   at_tick,
                          fluid_seq_id_t dest)

    cpdef void send_tempo_change(self,
                          unsigned int   at_tick,
                          double tempo,
                          fluid_seq_id_t dest=*)
    cpdef void send_key_pressure(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           key,
                                   int           value,
                                   fluid_seq_id_t dest=*)
    cpdef void send_pitch_bend(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           pitch,
                                   fluid_seq_id_t dest=*)
    cpdef void send_pitch_wheelsens(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           value,
                                   fluid_seq_id_t dest=*)
    cpdef void send_program_select(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   unsigned int  sfont_id,
                                   int           bank_num,
                                   int           preset_num,
                                   fluid_seq_id_t dest=*)
    cpdef void send_system_reset(self,
                                   unsigned int  at_tick,
                                   fluid_seq_id_t dest=*)
    cpdef void send_volume(self,
                                   unsigned int  at_tick,
                                   int           channel,
                                   int           value,
                                   fluid_seq_id_t dest=*)
