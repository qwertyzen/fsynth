import os

this_path = os.path.dirname(__file__)

def libfluidsynth_get_inc_path():
    return os.path.join(this_path, 'include')

def libfluidsynth_get_lib_path():
    return os.path.join(this_path, 'lib')
