#!/usr/bin/env python3
"""Print the core units a pull request has to prove: every unit whose specification or
body changed against the base, a generic unit through its instantiations, since GNATprove
analyzes a generic only there. The nightly run proves the whole core.
Usage: changed-units.py <base-ref>."""
import pathlib
import re
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
src = pathlib.Path("core/src")


def code(path):
    """The Ada text of a file without its comments."""
    return re.sub(r"--[^\n]*", "", path.read_text())


def is_generic(name):
    """Whether a unit is a generic unit, not one declaring a generic inside it."""
    spec = src / (name + ".ads")
    context = r"\s*(((private|limited)\s+)*with\s[^;]*;|use\s[^;]*;|pragma\s[^;]*;)"
    return spec.exists() and re.match(r"(" + context + r")*\s*generic\b", code(spec), re.IGNORECASE) is not None


def instantiations(name):
    """The units instantiating a generic unit, by its Ada name."""
    unit = re.escape(name.replace("-", "."))
    pattern = re.compile(r"\bis\s+new\s+" + unit + r"\b", re.IGNORECASE)
    return {spec.stem for spec in src.glob("*.ads") if pattern.search(code(spec))}


changed = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"],
                         check=True, capture_output=True, text=True).stdout.split()
selected = {pathlib.Path(c).stem for c in changed
            if c.startswith("core/src/") and c.endswith((".ads", ".adb"))}
for name in list(selected):
    if is_generic(name):
        selected.remove(name)
        selected |= instantiations(name)

for name in sorted(selected):
    body = src / (name + ".adb")
    spec = src / (name + ".ads")
    if body.exists():
        print(body.name)
    elif spec.exists():
        print(spec.name)
