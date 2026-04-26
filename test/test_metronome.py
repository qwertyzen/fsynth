from fsynth.lib import *
from fsynth.metronome import *
import time


se = Settings()
sy = Synthesizer(se)
au = AudioDriver(se, sy)
seq = Sequencer(sy)
se.set('synth.gain', 2.0)

tempo = 180.0
poly_ratio = 4/3
t2 = tempo / poly_ratio
metro1 = Metronome(seq, tempo, 4)
metro2 = Metronome(seq, t2, 3, 0)

sy.sfload('/Users/anustuv/Downloads/QZ_SF1.sf2')
metro1.start()
metro2.start()
time.sleep(60)