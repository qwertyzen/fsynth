from fsynth.lib import Sequencer, SequencerClient

class Metronome(SequencerClient):
    """
    A click-track client.

    Plays an accented note on beat 1 and an unaccented note on beats 2-N.

    Parameters
    ----------
    sequencer : Sequencer
    bpm : float
    beats_per_bar : int
        Time signature numerator.  Default 4.
    channel : int
        MIDI channel (0-based).  Default 9 (GM drums).
    accent_note : int
        MIDI note for beat 1.  Default 76 (High Wood Block).
    beat_note : int
        MIDI note for beats 2-N.  Default 77 (Low Wood Block).
    accent_velocity : int
    beat_velocity : int
    note_duration : int
        Duration in ticks.  Default 20 ms.
    """

    def __init__(
        self,
        sequencer: Sequencer,
        bpm: float           = 120.0,
        beats_per_bar: int   = 4,
        channel: int         = 9,
        accent_note: int     = 76,
        beat_note: int       = 77,
        accent_velocity: int = 127,
        beat_velocity: int   = 80,
        note_duration: int   = 20,
    ):
        super().__init__(sequencer, name="metronome")
        self.bpm              = bpm
        self.beats_per_bar    = beats_per_bar
        self.channel          = channel
        self.accent_note      = accent_note
        self.beat_note        = beat_note
        self.accent_velocity  = accent_velocity
        self.beat_velocity    = beat_velocity
        self.note_duration    = note_duration

        self._beat_index      = 0   # which beat within the bar we are on

        self.tick: int        = 0
        self.residue: float   = 0.0

    def start(self):
        super().start()
        self.tick = self._sequencer.tick + 20

    def callback(self, time: int, sequencer) -> None:
        # time calculation
        tpb = sequencer.get_ticks_per_beat(self.bpm)
        self.residue += tpb % 1
        tpb += self.residue // 1
        self.residue %= 1

        # --- schedule note (unless muted) ---
        if not self.muted:
            if self._beat_index == 0:
                note     = self.accent_note
                velocity = self.accent_velocity
            else:
                note     = self.beat_note
                velocity = self.beat_velocity

            sequencer.send_note(
                self.tick,
                self.channel,
                note,
                velocity,
                self.note_duration,
            )

        # --- advance beat counter ---
        self.tick += int(tpb)
        self._beat_index = (self._beat_index + 1) % self.beats_per_bar

        # --- reschedule ---
        self._reschedule(self.tick - 50)

    def reset(self):
        """Reset beat counter to beat 1."""
        self._beat_index = 0
