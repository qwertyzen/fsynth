import os

from ._libfluidsynth import *
this_path = os.path.dirname(__file__)

def get_fsynth_include_paths():
    return [
        os.path.join(this_path),
        libfluidsynth_get_inc_path()
    ]

def get_fsynth_lib_paths():
    return [
        libfluidsynth_get_lib_path()
    ]

def get_fsynth_c_sources():
    return [os.path.join(this_path, c) for c in os.listdir(this_path) if c.endswith('.c')]
