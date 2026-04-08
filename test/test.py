from qzfsynth.newfs import *
import time

s = Settings()
sy = Synthesizer(s)
au = AudioDriver(s, sy)
sy.sfload('/Users/anustuv/Downloads/QZ_SF1.sf2')

print(sy.sf_info)

sy.noteon(0, 60, 80)
time.sleep(1)
