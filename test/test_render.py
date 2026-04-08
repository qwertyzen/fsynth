from qzfsynth.newfs import synthesize_midifile
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

synthesize_midifile(
    midi_file=os.path.join(path, mfs[0]),
    sf_file=os.path.join(path, sfs[0]),
    out_wav='out.wav')
