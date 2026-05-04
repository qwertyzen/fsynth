def enumerate_audio_devices(audio_driver: str = None) -> list[str]: pass
def synthesize_midifile(midi_file: str, sf_file: str, out_wav: str): pass

class Settings:
    def _get_names(self): pass
    @property
    def names(self) -> str: pass
    def get(self, name: str) -> str | int | float: pass
    def set(self, name: str, value: str | int | float): pass
    def set_dict(self, data: dict): pass
    def get_default(self, name: str) -> str | int | float: pass
    def get_range(self, name: str) -> tuple[int, int] | tuple[float, float]: pass
    def get_options(self, name: str) -> list[str]: pass
    def get_all(self) -> dict: pass
    def get_all_defaults(self) -> dict: pass
    def is_realtime(self, name: str) -> int: pass

class Synthesizer:
    def __init__(self, settings: Settings): pass
    def sfload(self, filename: str) -> None: pass
    @property
    def sf_info(self) -> list[str] | None: pass
    def sfunload(self): pass
    def noteon(self, chan: int, key: int, vel: int): pass
    def noteoff(self, chan: int, key: int): pass
    def cc(self, chan: int, ctrl: int, val: int): pass
    def pc(self, chan: int, prog: int): pass
    def pitch_bend(self, chan: int, val: int): pass
    def channel_pressure(self, chan: int, val: int): pass
    def key_pressure(self, chan: int, key: int, val: int): pass
    def pitch_wheel_sens(self, chan: int, val: int): pass
    def send_message(self, data: bytes): pass
    def get_cc(self, chan: int, ctrl: int) -> int: pass
    def get_pitch_bend(self, chan: int) -> int: pass
    def get_pitch_wheel_sens(self, chan: int) -> int: pass
    def system_reset(self): pass
    def get_cpu_load(self) -> float: pass

class AudioDriver:
    def __init__(self, settings: Settings, synth: Synthesizer): pass

class Player:
    def __init__(self, synth: Synthesizer): pass
    def add(self, midi_file: str): pass
    def add_mem(self, bmidi: bytes): pass
    def play(self): pass
    def stop(self): pass
    def join(self): pass
    def set_loop(self, count: int): pass
    def set_tempo(self, bpm: float): pass
    def get_current_tick(self) -> int: pass
    def is_playing(self) -> bool: pass
    def get_total_ticks(self): pass
    def get_bpm(self): pass
    def seek(self, ticks: int): pass

class SynthTuner:
    def __init__(self, synth: Synthesizer): pass

    def activate_key_tuning(self, bank: int, prog: int, name: str, pitch: list[float]): pass
    def activate_octave_tuning(self, bank: int, prog: int, name: str, pitch: list[float]): pass
    def activate_tuning(self, chan: int, bank: int, prog: int): pass
    def deactivate_tuning(self, chan: int): pass
    def tune_notes(self, bank: int, prog: int, list[int] key, pitch: list[float]): pass
    def tuning_dump(self, bank: int, prog: int, name: str) -> list[float]: pass
    def get_tuning_banks(self) -> list[tuple[int, int]]: pass

class SequencerClient:
    def __init__(self, sequencer, *args, **kw): ...
    def _reschedule(self, next_tick: int): ...
    def start(self, at_tick: int = 0): ...
    def stop(self): ...
    def mute(self): ...
    def unmute(self): ...
    def toggle_mute(self): ...
    def callback(self, time: int, sequencer): ...
    def _on_error(self, exc): ...

class Sequencer:
    def __init__(self, synth: Synthesizer, time_scale: float = 1000.0,
                  use_system_timer: bool = False): ...
    def send_note(self,
                         at_tick: int,
                         channel: int,
                         key: int,
                         velocity: int,
                         duration: int,
                         dest: int): ...
    def send_noteon(self,
                           at_tick: int,
                           channel: int,
                           key: int,
                           velocity: int,
                           dest: int): ...
    def send_noteoff(self,
                            at_tick: int,
                            channel: int,
                            key: int,
                            dest: int): ...
    def send_program_change(self,
                                   at_tick: int,
                                   channel: int,
                                   program: int,
                                   dest: int): ...
    def send_control_change(self,
                                   at_tick: int,
                                   channel: int,
                                   control: int,
                                   value: int,
                                   dest: int): ...
    def send_timer(self,
                          at_tick: int,
                          dest: int): ...

    def send_tempo_change(self,
                          at_tick: int,
                          tempo: int,
                          dest: int): ...

    def send_key_pressure(self,
                                   at_tick: int,
                                   channel: int,
                                   key: int,
                                   value: int,
                                   dest: int): ...
    def send_pitch_bend(self,
                                   at_tick: int,
                                   channel: int,
                                   pitch: int,
                                   dest: int): ...
    def send_pitch_wheelsens(self,
                                   at_tick: int,
                                   channel: int,
                                   value: int,
                                   dest: int): ...
    def send_program_select(self,
                                   at_tick: int,
                                   channel: int,
                                   sfont_id: int,
                                   bank_num: int,
                                   preset_num: int,
                                   dest: int): ...
    def send_system_reset(self,
                                   at_tick: int,
                                   dest: int): ...
    def send_volume(self,
                                   at_tick: int,
                                   channel: int,
                                   value: int,
                                   dest: int): ...
