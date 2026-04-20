# https://www.fluidsynth.org/api/Sequencer.html

from fsynth.lib import *
import os
import time

# Find midi and soundfont files in Downloads folder
path = os.path.join(os.path.expanduser('~'), 'Downloads')
sfs = []
for item in os.listdir(path):
    if item.lower().endswith('.sf2'):
        sfs.append(item)

print(f'SFont files:\n{sfs}')

# schedule_next_sequence()
class DocSequence(SequencerClient):
    def __init__(self, sequencer, notes):
        super().__init__(sequencer)
        self.now = 0
        self.beat = 480
        self.notes = notes
        self.seqduration = len(notes) * self.beat

    def callback(self, time: int, sequencer):
        for i, note in enumerate(self.notes):
            if not self.muted:
                sequencer.send_note(
                    self.now + i * self.beat, 0, note, 100 if i else 120, self.beat
                )
        self._reschedule(self.now + self.seqduration // 2)
        self.now += self.seqduration

# createsynth()
class UsingMidiSeq:
    def __init__(self):
        self.se = Settings()
        self.se.set("synth.reverb.active", 0)
        self.se.set("synth.chorus.active", 0)
        self.sy = Synthesizer(self.se)
        self.au = AudioDriver(self.se, self.sy)
        self.seq = Sequencer(self.sy, time_scale=960.0)


if __name__ == '__main__':

    app = UsingMidiSeq()
    sfid = app.sy.sfload(os.path.join(path, sfs[5]))
    arp = DocSequence(app.seq, notes=[60, 60, 45, 50, 55])
    app.sy.pc(0, 24)
    arp.start()
    # time.sleep(8)

    input('Press Enter to end')
    arp.stop()
