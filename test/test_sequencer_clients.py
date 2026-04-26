# sequencer_clients.py
#
# Pure-Python SequencerClient subclasses.
# No Cython required here — all heavy lifting is in _sequencer.pyx.

from fsynth.lib import SequencerClient
from fsynth.metronome import Metronome

# ---------------------------------------------------------------------------
# Arpeggio
# ---------------------------------------------------------------------------
class Arpeggio(SequencerClient):
    """
    An arpeggiator client.

    Steps through a list of MIDI notes in order (or in a chosen pattern)
    at a given rate.

    Parameters
    ----------
    sequencer : Sequencer
    notes : list[int]
        MIDI note numbers to arpeggiate.
    bpm : float
        Rate expressed as BPM (one note per beat).
    channel : int
        MIDI channel (0-based).
    velocity : int
    note_duration : int
        Duration in ticks (must be < ticks_per_beat to avoid overlap).
    pattern : str
        'up'       — left to right
        'down'     — right to left
        'up_down'  — up then down, no repeated endpoints
        'random'   — random choice each step
    """

    PATTERNS = ("up", "down", "up_down", "random")

    def __init__(
        self,
        sequencer,
        notes: list,
        bpm: float       = 120.0,
        channel: int     = 0,
        velocity: int    = 100,
        note_duration: int = 200,
        pattern: str     = "up",
    ):
        if pattern not in self.PATTERNS:
            raise ValueError(f"pattern must be one of {self.PATTERNS}")

        super().__init__(sequencer, name="arpeggio")
        self.notes         = list(notes)
        self.bpm           = bpm
        self.channel       = channel
        self.velocity      = velocity
        self.note_duration = note_duration
        self.pattern       = pattern

        self._step         = 0
        self._direction    = 1   # +1 up / -1 down (for up_down)
        self._sequence     = self._build_sequence()

    def _build_sequence(self) -> list:
        """Pre-build the note list for simple patterns."""
        if self.pattern == "up":
            return list(self.notes)
        if self.pattern == "down":
            return list(reversed(self.notes))
        if self.pattern == "up_down":
            # e.g. [60,64,67] → [60,64,67,64]  (no repeated endpoints)
            up = list(self.notes)
            down = list(reversed(self.notes[1:-1]))
            return up + down
        # "random" — no static sequence; handled in callback
        return list(self.notes)

    @property
    def ticks_per_beat(self) -> int:
        return self._sequencer.get_ticks_per_beat(self.bpm)

    def callback(self, time: int, sequencer) -> None:
        if not self.muted:
            note = self._pick_note()
            sequencer.send_note(
                time,
                self.channel,
                note,
                self.velocity,
                self.note_duration,
            )

        self._advance_step()
        self._reschedule(time + self.ticks_per_beat)

    def _pick_note(self) -> int:
        if self.pattern == "random":
            import random
            return random.choice(self.notes)
        return self._sequence[self._step % len(self._sequence)]

    def _advance_step(self):
        if self.pattern != "random":
            self._step = (self._step + 1) % len(self._sequence)

    def set_notes(self, notes: list):
        """Hot-swap the note list mid-playback."""
        self.notes     = list(notes)
        self._sequence = self._build_sequence()
        self._step     = 0

    def reset(self):
        self._step = 0


# ---------------------------------------------------------------------------
# Example usage
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import time
    import os
    # -- these come from your existing _fsynth module --
    from fsynth.lib import Settings, Synthesizer, AudioDriver, Sequencer

    # Find midi and soundfont files in Downloads folder
    path = os.path.join(os.path.expanduser('~'), 'Downloads')
    mfs, sfs = [], []
    for item in os.listdir(path):
        if item.lower().endswith('.sf2'):
            sfs.append(item)
        if item.lower().endswith('.mid'):
            mfs.append(item)

    # Setup
    settings = Settings()
    synth    = Synthesizer(settings)
    driver   = AudioDriver(settings, synth)

    sfid     = synth.sfload(os.path.join(path, sfs[16]))
    synth.pc(0, 24)   # ch 0  → piano
    synth.pc(1, 36)
    settings.set('synth.gain', 2.3)
    # channel 9 is GM drums — no program_select needed

    # Sequencer (1 tick == 1 ms)
    seq = Sequencer(synth, time_scale=1000.0)

    # --- Metronome on ch 9, 120 BPM ---
    metro = Metronome(seq, bpm=100, channel=9)

    # --- Arpeggio on ch 0, same BPM, Cmaj7 chord ---
    arp = Arpeggio(
        seq,
        notes=[35, 60, 61, 69, 39, 69, 60, 39],   # C4 E4 G4 B4
        bpm=100,                   # 16th-note feel at 120 BPM
        channel=9,
        velocity=90,
        note_duration=40,
        pattern="up",
    )

    arp2 = Arpeggio(
        seq,
        notes=[40, 42, 42, 42],
        bpm=100,
        channel=9,
        velocity=70,
        note_duration=40,
        pattern='random'
    )

    time.sleep(1)
    # Start both
    # metro.start()
    arp.start()
    arp2.start()
    print("Playing metro + arp  (4 s)...")
    # metro.mute()
    # arp2.mute()
    time.sleep(8)
    # Mute metronome, keep arp
    print("Muting metronome...")
    # metro.mute()
    time.sleep(2)

    # Mute arp, unmute metronome
    print("Swapping: metro on, arp off...")
    # arp.mute()
    # metro.unmute()
    time.sleep(2)

    # Hot-swap arp chord
    print("Unmuting arp with new chord (Am7)...")
    arp.set_notes([60, 64, 60, 60])  # A3 C4 E4 G4
    # arp.unmute()
    time.sleep(1)

    # Stop everything
    print("Stopping...")
    metro.stop()
    arp.stop()
    time.sleep(0.5)   # let last events drain

    print("Done.")
