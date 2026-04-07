import os, sys
from setuptools import Extension, find_packages
from Cython.Build import cythonize
from setuptools import setup

extra_compile_args = ['-Wall', '-Wextra', '-g', '-O0']

def build_new_fluidsynth_extn():
    sys.path.insert(0, os.path.dirname(__file__))
    from qzfsynth.install_fs import get_fluidsynth_shared_lib_path, get_fluidsynth_install_prefix
    fslib = get_fluidsynth_shared_lib_path()
    if not fslib.exists():
        return None
    L = os.path.abspath(os.path.dirname(fslib))
    I = os.path.join(get_fluidsynth_install_prefix(), 'include')
    extn = Extension(
        'qzfsynth.newfs',
        sources=[
            'qzfsynth/newfs.pyx',
            'qzfsynth/cnufs.c',
        ],
        include_dirs=[I],
        extra_compile_args=extra_compile_args,
        library_dirs=[L],
        libraries=['fluidsynth'],
        extra_link_args=[f'-Wl,-rpath,@loader_path'],
    )
    print('Returning extension')
    return extn

binary_modules = []

fsextn = build_new_fluidsynth_extn()
if fsextn:
    binary_modules.append(fsextn)

py_modules = [
    'qzfsynth.install_fs'
]

req_pypi = [
    'platformdirs'
]

setup_kwargs = {
    'name': 'qzfsynth',
    'description': 'Python adapter for fluidsynth API',
    'ext_modules': cythonize(
        binary_modules,
        compiler_directives={"language_level": "3"}),
    'install_requires': req_pypi,
    'packages': find_packages(),
}

setup(**setup_kwargs)
