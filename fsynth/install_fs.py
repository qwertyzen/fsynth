import os
import sys
from sys import platform
import zipfile
from platformdirs import PlatformDirs
import shutil
import subprocess

dirs = PlatformDirs('qzfsynth', 'QwertyZen', ensure_exists=True)
_depends_dir = dirs.user_state_path

WIN = 'win32'
LINUX = 'linux'
MACOS = 'darwin'

FLUIDSYNTH_VERSION         = '2.5.2'

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

def get_win_bin_url():
    if compare_versions(FLUIDSYNTH_VERSION, '2.5.0') >= 0:
        _GLIB_OR_CPP = 'cpp11' if FLUIDSYNTH_WIN_CPP11_BUILD else 'glib'
        loc = FLUIDSYNTH_WIN_BIN_PATH + f'v{FLUIDSYNTH_VERSION}/fluidsynth-v{FLUIDSYNTH_VERSION}-win10-x64-{_GLIB_OR_CPP}.zip'
    else:
        loc = FLUIDSYNTH_WIN_BIN_PATH + f'v{FLUIDSYNTH_VERSION}/fluidsynth-{FLUIDSYNTH_VERSION}-win10-x64.zip'
    return FLUIDSYNTH_WIN_BIN_PATH + loc

def get_fluidsynth_install_prefix():
    if platform == MACOS or platform == LINUX:
        return _depends_dir / f'fluidsynth-{FLUIDSYNTH_VERSION}' / 'install'
    elif platform == WIN:
        zip_name = os.path.basename(get_win_bin_url()).replace('.zip', '')
        return _depends_dir / zip_name

def get_fluidsynth_shared_lib_path():
    if platform == MACOS:
        lib = 'libfluidsynth.dylib'
    elif platform == WIN:
        lib = 'libfluidsynth-3.dll'
    elif platform == LINUX:
        lib = 'libfluidsynth.so.3'
    else:
        raise NotImplementedError("Unsupported platform. Please contact us for support.")

    install_prefix = get_fluidsynth_install_prefix()
    if platform == MACOS or platform == LINUX:
        return install_prefix / 'lib' / lib
    elif platform == WIN:
        return install_prefix / 'bin' / lib

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

def unzip_file(zip_file: str, path: str) -> None:
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
                path = path / zf.filename.replace('.zip', '')
            zf.extractall(path)

        print()  # newline after progress bar
        print(f"✓ Extraction complete! Extracted to '{path}'\n")

    except zipfile.BadZipFile:
        print("\n✗ Error: The zip file is corrupted or invalid.")
    except PermissionError as e:
        print(f"\n✗ Permission denied: {e}")
    except OSError as e:
        print(f"\n✗ File system error during extraction: {e}")

def install_fluidsynth_posix(debug=False):
    dfs = download_file_from_url(FLUIDSYNTH_GH_SOURCE_URL, _depends_dir)
    if not dfs:
        return
    src_path = _depends_dir / f'fluidsynth-{FLUIDSYNTH_VERSION}'
    unzip_file(dfs, _depends_dir)
    install_path = src_path / 'install'
    build_path = src_path / 'build'
    if install_path.exists():
        shutil.rmtree(install_path)
    os.makedirs(install_path)
    if build_path.exists():
        shutil.rmtree(build_path)
    os.makedirs(build_path)

    curdir = os.path.abspath(os.curdir)
    os.chdir(build_path)

    debug_opts = ''
    if debug:
        debug_opts = '-DCMAKE_BUILD_TYPE=Debug'
    lib_opts = ''
    if platform == MACOS:
        lib_opts = '-DBUILD_SHARED_LIBS=ON -Denable-framework=OFF'
    cmd = f'cmake --install-prefix "{install_path}" {debug_opts} {lib_opts} ..'
    print(f'Running: {cmd}')
    os.system(cmd)
    os.system('make')
    os.system('make install')

    os.chdir(install_path)
    os.chdir(curdir)

def install_fluidsynth_windows():
    dfb = download_file_from_url(get_win_bin_url(), _depends_dir)
    if not dfb:
        return
    unzip_file(dfb, _depends_dir)

def handle_install(args):
    if platform == MACOS or platform == LINUX:
        install_fluidsynth_posix(debug=args.debug)
    elif platform == WIN:
        install_fluidsynth_windows()
    else:
        raise OSError(f'Unsupported OS: {os.name}')

def ensure_fluidsynth():
    fs_sh_lib = get_fluidsynth_shared_lib_path()
    if not os.path.exists(fs_sh_lib):
        if platform == MACOS or platform == LINUX:
            install_fluidsynth_posix()
        elif platform == WIN:
            install_fluidsynth_windows()
        else:
            raise OSError(f'Unsupported OS: {os.name}')
    install_dir = os.path.join(os.path.dirname(__file__), '_libfluidsynth')
    lib_dir = os.path.dirname(fs_sh_lib)
    inc_dir = os.path.join(get_fluidsynth_install_prefix(), 'include')
    install_lib_dir = os.path.join(install_dir, 'lib')
    install_inc_dir = os.path.join(install_dir, 'include')
    shutil.rmtree(install_lib_dir, ignore_errors=True)
    shutil.rmtree(install_inc_dir, ignore_errors=True)
    shutil.copytree(lib_dir, install_lib_dir, dirs_exist_ok=True)
    shutil.copytree(inc_dir, install_inc_dir, dirs_exist_ok=True)

def handle_show_info(args):
    print(f'Platform: {platform}')
    print(f'Fluidsynth version: {FLUIDSYNTH_VERSION}')
    print(f'Install prefix: {get_fluidsynth_install_prefix()}')
    print(f'Library path: {get_fluidsynth_shared_lib_path()}')
    print(f'Installed: {os.path.exists(get_fluidsynth_shared_lib_path())}')
    print()

def handle_ls(args):
    print(f'Path: {_depends_dir}')
    print()
    if platform == WIN:
        subprocess.run(['dir', _depends_dir])
    else:
        subprocess.run(['ls', '-lhF', _depends_dir])

def handle_get_lib_path(args):
    print(get_fluidsynth_shared_lib_path())

def handle_clean(args):
    shutil.rmtree(_depends_dir)

def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="FluidSynth dependency manager"
    )

    parser.add_argument('-l', '--ls', action='store_true', help='List depends directory')

    subparsers = parser.add_subparsers(dest="command")

    parser_info = subparsers.add_parser(
        "show_info", help="Display information"
    )
    parser_info.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    parser_info.set_defaults(func=handle_show_info)

    parser_install = subparsers.add_parser(
        "install", help=f"Install fluidsynth library v{FLUIDSYNTH_VERSION}"
    )
    parser_install.add_argument(
        "-d", "--debug",
        action="store_true",
        help="Build with debug symbols"
    )
    parser_install.set_defaults(func=handle_install)

    parser_get_lib = subparsers.add_parser(
        "get_lib_path", help="Display path to shared library"
    )
    parser_get_lib.set_defaults(func=handle_get_lib_path)

    parser_clean = subparsers.add_parser(
        "clean", help="Remove current installation and downloads."
    )
    parser_clean.set_defaults(func=handle_clean)

    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_usage()
        sys.exit(0)
    if args.ls:
        handle_ls(args)
    elif hasattr(args, 'func'):
        args.func(args)


if __name__ == '__main__':
    main()
