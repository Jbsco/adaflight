#!/usr/bin/env python3
"""Print the core units a pull request has to prove: every unit whose specification or
body changed against the base. The nightly run proves the whole core.
Usage: changed-units.py <base-ref>."""
import pathlib
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
src = pathlib.Path("core/src")

changed = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"],
                         check=True, capture_output=True, text=True).stdout.split()
selected = {pathlib.Path(c).stem for c in changed
            if c.startswith("core/src/") and c.endswith((".ads", ".adb"))}

for name in sorted(selected):
    body = src / (name + ".adb")
    spec = src / (name + ".ads")
    if body.exists():
        print(body.name)
    elif spec.exists():
        print(spec.name)
