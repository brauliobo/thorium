# Copyright (c) 2026 Alex313031 and gz83.

# This file is the equivalent of build_win.sh in the parent directory.

import os
import subprocess
import sys

# Error handling functions


def fail(msg):
    # Print error message and exit
    print(f"{sys.argv[0]}: {msg}", file=sys.stderr)
    sys.exit(111)


def try_run(command):
    if subprocess.call(command, shell=True) != 0:
        fail(f"Failed {command}")


# Help function
def display_help():
    print("\nScript to build Alacrium for Windows.\n")
    print("Usage: python win_scripts\build_win.py # (where # is number of jobs)\n")


if '--help' in sys.argv:
    display_help()
    sys.exit(0)


# Use the repository-local Chromium checkout.
cr_src_dir = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'chromium', 'src'
)

print("\nBuilding Alacrium for Windows\n")

# Change directory and run build commands
os.chdir(cr_src_dir)
# Determine the number of threads to use
jobs = sys.argv[1] if len(sys.argv) > 1 else str(os.cpu_count())

try_run(f'autoninja -C out/alacrium alacrium_all -j{jobs}')

try_run(f'autoninja -C out/alacrium setup mini_installer -j{jobs}')

installer_dest = os.path.normpath(os.path.join(cr_src_dir, 'out', 'alacrium'))

print(f"Build Completed. Installer at '{installer_dest}'")
