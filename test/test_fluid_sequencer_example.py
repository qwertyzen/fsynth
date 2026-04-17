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

seqdur = 1920
beat = 480
seqe = SequencerExpt(sy, seqdur)
sy.sfload(os.path.join(path, sfs[0]))
seqe.set_bpm(240)

def schedule_next_sequence():
    global seqe
    seqe.advance(seqdur)
    seqe.sendnoteon(0, 60, seqe.now )
    seqe.sendnoteon(0, 60, seqe.now + beat)
    seqe.sendnoteon(1, 67, seqe.now + beat * 2)
    seqe.sendnoteon(1, 59, seqe.now + beat * 3)
    # seqe.sendnoteon(1, 59, seqe.now + 8*seqdur/10)
    seqe.schedule_next_callback()

seqe.start(schedule_next_sequence)
input('Press Enter to end')
