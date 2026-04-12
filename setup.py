import os, sys
from setuptools import Extension, find_packages
from Cython.Build import cythonize
from setuptools import setup

extra_compile_args = ['-Wall', '-Wextra', '-g', '-O0']

def build_fluidsynth_extn():
    sys.path.insert(0, os.path.dirname(__file__))
    from fsynth.install_fs import ensure_fluidsynth
    ensure_fluidsynth()
    from fsynth import get_fsynth_include_paths, get_fsynth_lib_paths
    extn = Extension(
        'fsynth.lib',
        sources=[
            'fsynth/_fsynth.pyx',
            'fsynth/cfsynth.c',
        ],
        include_dirs=get_fsynth_include_paths(),
        extra_compile_args=extra_compile_args,
        library_dirs=get_fsynth_lib_paths(),
        libraries=['fluidsynth'],
        extra_link_args=[f'-Wl,-rpath,@loader_path'],
    )
    print('Returning extension')
    return extn

setup_kwargs = {
    'name': 'fsynth',
    'version': '0.0.1',
    'author': 'Anustuv Pal',
    'author_email': 'anustuv@gmail.com',
    'description': 'Python adapter for fluidsynth API',
    'ext_modules': cythonize(
        [build_fluidsynth_extn()],
        compiler_directives={"language_level": "3"},
        ),
    'packages': find_packages(),
    'package_data': {
        "fsynth": ["*.pxd", "*.h", "c*.c"],
        "fsynth._libfluidsynth": [
            "lib/*", "include/*", "include/fluidsynth/*"
            ]
    },
    'entry_points': {
        'console_scripts': [
            'install_fs = fsynth.install_fs:main'
        ]
    },
}

setup(**setup_kwargs)
