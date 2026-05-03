# fsynth.lib

A Pythonic Object Oriented wrapper library for `fluidsynth` C-API.

Example:

```
from fsynth.lib import *

settings = Settings()
synth = Synthesizer(settings)
au = AudioDriver(settings, synth)

settings.set('synth.gain', 0.7)
synth.sfload('path/to/sfont.sf2')

synth.noteon(0, 60, 80)
```

See `test/` directory for usage and applications.
- `test_metronome.py`: Experiment with two metronomes.
- `test_player.py`: Play MIDI file with chosen soundfont.
- `test_render.py`: Save synthesized audio to wav file.
- `test_sequencer_clients.py`: Sequences two arpeggios and a metronome in a loop.

See `fsynth/lib.pyi` for currently implemented Python API.

See `fsynth/lib.pxd` for Cython interface.

## How to install?

a. For interactive usage
```
pip install git+https://github.com/qwertyzen/fsynth.git
```

b. Or, installing locally from source
```
$ git clone https://github.com/qwertyzen/fsynth.git
$ cd fsynth
$ pip install .
```

c. Or, in your `setup.py`:
```
setup(
    install_requires: [
        ...,
        'fsynth @ git+https://github.com/qwertyzen/fsynth.git'
    ]
)
```

## Managing fluidsynth versions

1. Run `install_fs --set-version 2.5.2`.

3. Run `pip install .` from root of `fsynth` to build and link the Python extension.

## Build requirements

For MacOS and Linux:
- Python, cmake tools, C compiler, fluidsynth dependencies.

For Windows:
- Python, MSVC build tools

## Packaging with pyinstaller

If you are importing `fsynth.lib` from pure python and pyinstaller can discover it, then `fsynth.lib` will be packaged. Otherwise, you can add to your pyinstaller spec `--hidden-imports=fsynth.lib`.
