#!/usr/bin/env python3
import sys
import os
import shutil
import subprocess
from pathlib import Path

def main():
    home = Path.home()
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <source_file> <destination_dir>")
        sys.exit(1)

    src_file = sys.argv[1]
    dest_dir = sys.argv[2]

    if not os.path.isfile(src_file):
        print(f"Error: File '{src_file}' does not exist.")
        sys.exit(1)

    if not os.path.isdir(dest_dir):
        print(f"Error: Directory '{dest_dir}' does not exist.")
        sys.exit(1)

    try:
        shutil.copy(src_file, dest_dir)
        print(f"Copied '{src_file}' to '{dest_dir}'.")
    except Exception as e:
        print(f"Error copying file: {e}")
        sys.exit(1)

    try:
        subprocess.run([home / "git/mojo-googledrive/bin/gd-remove.pl", src_file], check=True)
        print(f"Ran gd-remove.pl on '{src_file}'.")
    except Exception as e:
        print(f"Error running gd-remove.pl: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
