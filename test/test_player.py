from qzfsynth.newfs import *
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
settings = Settings()
synth = Synthesizer(settings)
au = AudioDriver(settings, synth)
player = Player(synth)

synth.sfload(os.path.join(path, sfs[0]))
player.add(os.path.join(path, mfs[0]))

# Player Loop. Press Ctrl + C to stop
player.play()

try:
    while player.is_playing():
        time.sleep(0.5)
        print(f'Current tick: {player.get_current_tick()}/{player.get_total_ticks()}',
            'CPU: ', synth.get_cpu_load())
except KeyboardInterrupt:
    print('Stop.')
