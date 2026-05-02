import os, sys
from setuptools import Extension, find_packages
from Cython.Build import cythonize
from setuptools import setup
sys.path.insert(0, os.path.dirname(__file__))
from fsynth.install_fs2 import FluidsynthExtensionUtil

cc = FluidsynthExtensionUtil()

def build_fluidsynth_extn():
    cc.ensure_fluidsynth()
    extn = Extension(
        'fsynth.lib',
        sources=['fsynth/_fsynth.pyx'] + cc.get_fsynth_c_sources(),
        include_dirs=cc.get_compiler_include_paths(),
        extra_compile_args=cc.get_compiler_extra_args(),
        library_dirs=cc.get_linker_lib_dirs(),
        libraries=cc.get_linker_libs(),
        extra_link_args=cc.get_linker_extra_args(),
    )
    return extn

package_data = {
    "fsynth": ["*.pxd", "*.pyi", "*.h", "c*.c"],
}
package_data = cc.update_package_data(package_data)

setup_kwargs = {
    'name': 'fsynth',
    'version': '0.0.1',
    'author': 'Anustuv Pal',
    'author_email': 'anustuv@gmail.com',
    'description': 'Python enhanced fluidsynth API',
    'ext_modules': cythonize(
        [build_fluidsynth_extn()],
        compiler_directives={"language_level": "3"},
        ),
    'packages': find_packages(),
    'package_data': package_data,
    'install_requires': ['platformdirs'],
    'entry_points': {
        'console_scripts': [
            'install_fs = fsynth.install_fs2:main'
        ]
    },
}

setup(**setup_kwargs)
