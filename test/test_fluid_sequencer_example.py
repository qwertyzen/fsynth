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
seqe = SequencerExpt()

seqe.main(os.path.join(path, sfs[0]), 300)
input('Press Enter to end')
