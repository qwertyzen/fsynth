from fsynth.lib import *
import os

path = os.path.join(os.path.expanduser('~'), 'Downloads')
mfs, sfs = [], []
for item in os.listdir(path):
    if item.lower().endswith('.sf2'):
        sfs.append(item)
    if item.lower().endswith('.mid'):
        mfs.append(item)

print(f'Midi files:\n{mfs}')
print(f'SFont files:\n{sfs}')

file_writer = FileWriter(soundfont=os.path.join(path, sfs[0]))
file_writer.render_midi_file(os.path.join(path, mfs[0]), 'out.mp3')
