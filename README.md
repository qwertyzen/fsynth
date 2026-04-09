# fsynth.lib

A Pythonic Object Oriented wrapper for `libfluidsynth`.

## How to install?

1. Clone the repo
2. Activate python venv
3. Go to project root
4. Run: `pip install .`

This installs the install script `install_fs`.

5. Run: `install_fs install`

- For Posix, it fetches the fluidsynth source release and builds the shared libraries.
- For Windows, it fetches the prebuild binary.

6. Run: `pip install .`

- This builds the `fsynth.lib` extension module and installs it.

## Usage

```
from fsynth.lib import *

settings = Settings()
synth = Synthesizer(settings)
au = AudioDriver(settings, synth)

settings.set('synth.gain', 0.7)
synth.sfload('path/to/sfont.sf2')

synth.noteon(0, 60, 80)
```

More examples can be found in the `test/` directory for usage and applications.

See `fsynth/lib.pyi` for currently implemented Python API.

## Managing fluidsynth versions

1. Modify the `FLUIDSYNTH_VERSION` variable in `fsynth/install_fs.py` to a valid fluidsynth version string.

2. Run `install_fs install` to install the fluidsynth library.

3. Run `pip install .` from root of `fsynth` to build and link the Python extension.

## Build requirements

For Posix:
- cmake tools, C compiler, Python, fluidsynth dependencies.

For Windows:
- MSVC build tools, Python

## Packaging with pyinstaller

Package the fluidsynth shared library with executable in compliance with LGPL requirements.

In a `Makefile`

```
LIB_PATH := $(shell install_fs get_lib_path)

makespec:
		pyi-makespec --onedir --windowed \
        --name="MyApp" \
        --add-binary="$(LIB_PATH)":. \
```

In a pyinstaller `.spec` file

```
from fsynth.install_fs import get_lib_path

a = Analysis(
    ['path/to/app.py'],
    pathex=[],
    binaries=[
        (get_lib_path(), '.')
        ],
    ...
)
```

You may have to add `--hidden-imports=fsynth.lib`.
