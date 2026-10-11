#!/usr/bin/env python3
"""Print the core units a pull request has to prove: every unit whose source changed
against the base, and every unit whose specification or body depends, through the
specification with-clauses, on a changed specification. A change to the crate, the gate
or the workflow selects every unit. Usage: changed-units.py <base-ref>."""
import pathlib
import re
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
src = pathlib.Path("core/src")
full_triggers = ("core/alire.toml", "core/adaflight_core.gpr", "prove.do",
                 "tools/changed-units.py", ".github/workflows/prove.yml")

changed = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"],
                         check=True, capture_output=True, text=True).stdout.split()
units = {}
for path in sorted(src.glob("*.ads")):
    units[path.stem] = {"spec": path, "body": src / (path.stem + ".adb")}
withs = {}
for name, files in units.items():
    deps = set()
    for kind in ("spec", "body"):
        if files[kind].exists():
            for m in re.finditer(r"^\s*(?:private\s+)?with\s+([\w.]+(?:\s*,\s*[\w.]+)*)\s*;",
                                 files[kind].read_text(), re.M):
                for ref in re.split(r"\s*,\s*", m.group(1)):
                    deps.add((kind, ref.lower().replace(".", "-")))
    parent = name.rsplit("-", 1)[0]
    if parent != name:
        deps.add(("spec", parent))
    withs[name] = deps

if any(c in full_triggers for c in changed):
    selected = set(units)
else:
    changed_units = {pathlib.Path(c).stem for c in changed if c.startswith("core/src/")}
    changed_specs = {pathlib.Path(c).stem for c in changed
                     if c.startswith("core/src/") and c.endswith(".ads")}
    marked = set(changed_specs)
    while True:
        more = {u for u, deps in withs.items()
                if u not in marked and any(k == "spec" and d in marked for k, d in deps)}
        if not more:
            break
        marked |= more
    selected = set(changed_units)
    selected |= {u for u, deps in withs.items() if any(d in marked for _, d in deps)}
    selected |= marked

for name in sorted(selected):
    if name in units:
        files = units[name]
        print((files["body"] if files["body"].exists() else files["spec"]).name)
