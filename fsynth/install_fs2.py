import os
import sys
import zipfile
import shutil
from pathlib import Path
from platformdirs import PlatformDirs

DEBUG = False

dirs = PlatformDirs('qzfsynth', 'QwertyZen', ensure_exists=True)
_depends_dir = dirs.user_state_path

WIN = 'win32'
LINUX = 'linux'
MACOS = 'darwin'

FLUIDSYNTH_VERSION = '2.5.2'
fsynth_version_file = dirs.user_config_path / 'fsynth_version.txt'
if fsynth_version_file.exists():
    with open(fsynth_version_file) as f:
        FLUIDSYNTH_VERSION = f.read().strip()
else:
    with open(fsynth_version_file, 'w') as f:
        f.write(FLUIDSYNTH_VERSION)

# Posix build
FLUIDSYNTH_GH_SOURCE_URL   = f'https://github.com/FluidSynth/fluidsynth/archive/refs/tags/v{FLUIDSYNTH_VERSION}.zip'

# Windows binary release
FLUIDSYNTH_WIN_CPP11_BUILD = True  # Applies to >=v2.5.0. True for CPP11, False for glib
FLUIDSYNTH_WIN_BIN_PATH    = 'https://github.com/FluidSynth/fluidsynth/releases/download/'

def compare_versions(v1, v2):
    """
    Compare two version strings of the form 'Maj.min.sub'.

    Returns:
        -1 if v1 < v2
         1 if v1 > v2
         0 if v1 == v2
    """
    # Split and convert to integers
    parts1 = list(map(int, v1.split('.')))
    parts2 = list(map(int, v2.split('.')))

    # Pad the shorter one with zeros (e.g., '1.2' becomes '1.2.0')
    max_len = max(len(parts1), len(parts2))
    parts1.extend([0] * (max_len - len(parts1)))
    parts2.extend([0] * (max_len - len(parts2)))

    # Compare component-wise
    for p1, p2 in zip(parts1, parts2):
        if p1 < p2:
            return -1
        elif p1 > p2:
            return 1
    return 0

def download_file_from_url(url: str, dir_path: str, overwrite=False) -> str | None:
    """Downloads a file from a URL and saves it to the given path with progress display.
    Returns the path to the downloaded file, or an empty string on failure."""
    import requests

    if not url or not url.strip():
        print("✗ Error: URL cannot be empty.")
        return None

    if dir_path and not dir_path.exists():
        try:
            os.makedirs(dir_path, exist_ok=True)
            print(f"✓ Created directory: {dir_path}")
        except OSError as e:
            print(f"✗ Error: Could not create directory '{dir_path}': {e}")
            return None

    path = dir_path / os.path.basename(url)
    if not overwrite and path.exists():
        print('File already exists. Not downloading.')
        return path

    print(f"↓ Downloading from:\n  {url}")
    print(f"→ Saving to: {path}")

    try:
        with requests.get(url, stream=True, timeout=30) as response:
            response.raise_for_status()

            total_size = int(response.headers.get("Content-Length", 0))
            bar_width = 40
            downloaded_bytes = 0
            chunk_size = 8192

            with open(path, "wb") as f:
                for chunk in response.iter_content(chunk_size=chunk_size):
                    if not chunk:
                        continue
                    f.write(chunk)
                    downloaded_bytes += len(chunk)

                    done_mb = downloaded_bytes / (1024 * 1024)
                    if total_size > 0:
                        percent = downloaded_bytes / total_size * 100
                        total_mb = total_size / (1024 * 1024)
                        filled = int(bar_width * downloaded_bytes / total_size)
                        bar = "█" * filled + "░" * (bar_width - filled)
                        sys.stdout.write(f"\r  [{bar}] {percent:5.1f}%  {done_mb:.2f} / {total_mb:.2f} MB")
                    else:
                        # Unknown content length — show spinner with bytes so far
                        spinner = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"[downloaded_bytes // chunk_size % 10]
                        sys.stdout.write(f"\r  {spinner} Downloading... {done_mb:.2f} MB")
                    sys.stdout.flush()

        print()  # newline after progress bar
        file_size_mb = os.path.getsize(path) / (1024 * 1024)
        print(f"✓ Download complete! ({file_size_mb:.2f} MB saved)\n")
        return path

    except requests.exceptions.HTTPError as e:
        print(f"\n✗ HTTP Error {e.response.status_code}: {e.response.reason} — check the URL and try again.")
    except requests.exceptions.ConnectionError:
        print("\n✗ Connection error — check your internet connection or URL.")
    except requests.exceptions.Timeout:
        print("\n✗ Request timed out — the server took too long to respond.")
    except requests.exceptions.RequestException as e:
        print(f"\n✗ Request failed: {e}")
    except PermissionError:
        print(f"\n✗ Permission denied: cannot write to '{path}'.")
    except OSError as e:
        print(f"\n✗ File system error: {e}")

    return None

def unzip_file(zip_file: str, path: str, dirname: str = None) -> str | None:
    """Unzips a zip archive into the given directory path."""

    if not os.path.exists(zip_file):
        print(f"✗ Error: Zip file not found: '{zip_file}'")
        return

    if not zipfile.is_zipfile(zip_file):
        print(f"✗ Error: '{zip_file}' is not a valid zip file.")
        return

    try:
        os.makedirs(path, exist_ok=True)
    except OSError as e:
        print(f"✗ Error: Could not create output directory '{path}': {e}")
        return

    print(f"📦 Extracting: {zip_file}")
    print(f"→ Destination: {path}")

    try:
        with zipfile.ZipFile(zip_file, "r") as zf:
            names = zf.namelist()
            top_levels = {name.split('/')[0] for name in names}
            if len(top_levels) != 1:
                if dirname:
                    path = path / dirname
                else:
                    path = path / zf.filename.replace('.zip', '')
            zf.extractall(path)

        print()
        print(f"✓ Extraction complete! Extracted to '{path}'\n")
        return path

    except zipfile.BadZipFile:
        print("\n✗ Error: The zip file is corrupted or invalid.")
    except PermissionError as e:
        print(f"\n✗ Permission denied: {e}")
    except OSError as e:
        print(f"\n✗ File system error during extraction: {e}")

class AnyOS:
    def __init__(self):
        self._install_path = None
        self._package_dir = Path(os.path.dirname(__file__)) / '_libfluidsynth'

    def get_fluidsynth_root_path(self):
        return _depends_dir / f'fluidsynth-{FLUIDSYNTH_VERSION}'

    def get_shared_lib_src_path(self):
        return self._install_path / 'lib'

    def get_include_path(self):
        return self._install_path / 'include'

    def get_shared_lib_name(self):
        raise TypeError

    def ensure_fluidsynth(self):
        fs_lib_path = self.get_shared_lib_src_path() / self.get_shared_lib_name()
        if not fs_lib_path.exists():
            self.install_fluidsynth()
        self.prepare_package_data()

    def get_linker_extra_args(self):
        return []

    def update_package_data_arg(self, package_data: dict):
        data = package_data.copy()
        data['fsynth._libfluidsynth'] = ['*']
        return data

    def get_linker_lib_name(self):
        return None

    def install_fluidsynth(self):
        raise NotImplementedError('Do not directly instantiate baseclass.')

    def prepare_package_data(self):
        raise NotImplementedError('Do not directly instantiate baseclass.')

    def get_compiler_extra_args(self):
        return ['']

    def get_linker_extra_args(self):
        return ['']

class Posix(AnyOS):
    def __init__(self):
        super().__init__()
        self._src_path = self.get_fluidsynth_root_path()
        self._install_path = self._src_path / 'install'
        self._build_path =   self._src_path / 'build'

    def _get_cmake_lib_opts(self):
        return ''

    def install_fluidsynth(self):
        dfs = download_file_from_url(FLUIDSYNTH_GH_SOURCE_URL, _depends_dir)
        if not dfs:
            return
        unzip_file(dfs, _depends_dir, self._src_path)
        if self._install_path.exists():
            shutil.rmtree(self._install_path)
        os.makedirs(self._install_path)
        if self._build_path.exists():
            shutil.rmtree(self._build_path)
        os.makedirs(self._build_path)

        curdir = os.path.abspath(os.curdir)
        os.chdir(self._build_path)

        debug_opts = ''
        if DEBUG:
            debug_opts = '-DCMAKE_BUILD_TYPE=Debug'
        cmd = f'cmake --install-prefix "{self._install_path}" {debug_opts} {self._get_cmake_lib_opts()} ..'
        print(f'Running: {cmd}')
        os.system(cmd)
        os.system('make')
        os.system('make install')

        os.chdir(curdir)

    def prepare_package_data(self):
        lib_dir = self.get_shared_lib_src_path()
        inc_dir = self.get_include_path()
        install_lib_dir = self._package_dir / 'lib'
        install_inc_dir = self._package_dir / 'include'
        shutil.rmtree(install_lib_dir, ignore_errors=True)
        shutil.rmtree(install_inc_dir, ignore_errors=True)
        shutil.copytree(lib_dir, install_lib_dir, dirs_exist_ok=True)
        shutil.copytree(inc_dir, install_inc_dir, dirs_exist_ok=True)

    def get_compiler_extra_args(self):
        args = ['-Wall', '-Wextra']
        if DEBUG:
            args += ['-g', '-O0']
        return args

    def get_linker_lib_name(self):
        return 'fluidsynth'

class MacOS(Posix):
    def get_shared_lib_name(self):
        return 'libfluidsynth.dylib'

    def get_linker_extra_args(self):
        return ['-Wl,-rpath,@loader_path']

    def _get_cmake_lib_opts(self):
        return '-DBUILD_SHARED_LIBS=ON -Denable-framework=OFF'

class Linux(Posix):
    def get_shared_lib_name(self):
        return 'libfluidsynth.so.3'

    def get_linker_extra_args(self):
        return ["-Wl,-rpath,'$ORIGIN'"]

class Windows(AnyOS):
    def __init__(self):
        super().__init__()
        self._install_path = self.get_fluidsynth_root_path()

    def _get_win_bin_url(self):
        if compare_versions(FLUIDSYNTH_VERSION, '2.5.0') >= 0:
            _GLIB_OR_CPP = 'cpp11' if FLUIDSYNTH_WIN_CPP11_BUILD else 'glib'
            loc = f'v{FLUIDSYNTH_VERSION}/fluidsynth-v{FLUIDSYNTH_VERSION}-win10-x64-{_GLIB_OR_CPP}.zip'
        else:
            loc = f'v{FLUIDSYNTH_VERSION}/fluidsynth-{FLUIDSYNTH_VERSION}-win10-x64.zip'
        return FLUIDSYNTH_WIN_BIN_PATH + loc

    def get_shared_lib_name(self):
        return 'libfluidsynth-3.lib'

    def get_linker_lib_name(self):
        return self.get_shared_lib_name().replace('.lib', '')

    def install_fluidsynth(self):
        dfb = download_file_from_url(self._get_win_bin_url(), _depends_dir)
        if not dfb:
            return
        unzip_file(dfb, _depends_dir)

    def prepare_package_data(self):
        libdir = self._install_path / 'lib'
        incdir = self._install_path / 'include'
        dlldir = self._install_path / 'bin'
        dllfile = dlldir / self.get_shared_lib_name().replace('.lib', '.dll')
        install_lib_dir = self._package_dir / 'lib'
        install_inc_dir = self._package_dir / 'include'
        install_dll_dir = self._package_dir / '..'
        shutil.rmtree(install_lib_dir, ignore_errors=True)
        shutil.rmtree(install_inc_dir, ignore_errors=True)
        shutil.copytree(libdir, install_lib_dir, dirs_exist_ok=True)
        shutil.copytree(incdir, install_inc_dir, dirs_exist_ok=True)
        shutil.copy(dllfile, install_dll_dir)

    def update_package_data_arg(self, package_data: dict):
        data = super().updata_package_data_arg(package_data)
        data['fsynth'].append('*.dll')
        return data

    def get_compiler_extra_args(self):
        args = ['/W4']
        if DEBUG:
            args += ['/DEBUG', '/O0']
        return args

class FluidsynthExtensionUtil:
    def __init__(self):
        self.fsynth_manager: AnyOS = {
            MACOS: MacOS,
            LINUX: Linux,
            WIN: Windows
        }[sys.platform]()

    def ensure_fluidsynth(self):
        self.fsynth_manager.ensure_fluidsynth()

    def get_compiler_include_paths(self):
        return [
            str(self.fsynth_manager.get_include_path()),
            os.path.dirname(__file__)]

    def get_compiler_extra_args(self):
        return self.fsynth_manager.get_compiler_extra_args()

    def get_linker_lib_dirs(self):
        return [str(self.fsynth_manager.get_shared_lib_src_path())]

    def get_linker_libs(self):
        return [self.fsynth_manager.get_linker_lib_name()]

    def get_linker_extra_args(self):
        return self.fsynth_manager.get_linker_extra_args()

    def update_package_data(self, package_data: dict):
        return self.fsynth_manager.update_package_data_arg(package_data)

    def get_fsynth_c_sources(self):
        this_path = Path(os.path.dirname(__file__))
        srcs = list(map(str, this_path.glob('c*.c')))
        return srcs

def _handle_uninst(args):
    shutil.rmtree(dirs.user_state_path, ignore_errors=True)
    shutil.rmtree(dirs.user_config_path, ignore_errors=True)

def _handle_set_version(ver):
    with open(fsynth_version_file, 'w') as f:
        f.write(ver.strip())
    print(ver)

def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="FluidSynth dependency manager"
    )

    parser.add_argument('-u', '--uninst', action='store_true', help='Remove fluidsynth sources and binaries.')
    parser.add_argument('-s', '--set-version', type=str, help='Set the version of fluidsynth library.')

    args = parser.parse_args()
    if len(sys.argv) == 1:
        parser.print_usage()
        sys.exit(0)
    if args.uninst:
        _handle_uninst(args)
    if args.set_version:
        _handle_set_version(args.set_version)

if __name__ == '__main__':
    main()
