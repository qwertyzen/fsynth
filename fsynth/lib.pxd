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
