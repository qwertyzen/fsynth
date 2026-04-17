from fsynth.lib import *
import os
import time

# Find midi and soundfont files in Downloads folder
path = os.path.join(os.path.expanduser('~'), 'Downloads')
mfs, sfs = [], []
for item in os.listdir(path):
    if item.lower().endswith('.sf2'):
        sfs.append(item)
    if item.lower().endswith('.mid'):
        mfs.append(item)

print(f'Midi files:\n{mfs}')
print(f'SFont files:\n{sfs}')

# Init Fluidsynth and load files
se = Settings()
sy = Synthesizer(se)
au = AudioDriver(se, sy)

seqe = SequencerExpt(sy)
sy.sfload(os.path.join(path, sfs[0]))
seqe.set_bpm(300)
seqe.start()
input('Press Enter to end')
