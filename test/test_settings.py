from qzfsynth.newfs import *
from pprint import pprint

s = Settings()

pprint(s.get_all())

s.set('audio.periods', 32)

s.set_dict({
    'synth.gain'            : 2.0,
    'audio.coreaudio.device': 'External Headphones',
})

pprint(s.get_all())

pprint(s.get_all_defaults())
