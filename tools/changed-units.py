#!/usr/bin/env python3
"""Print the core units a pull request has to prove: every unit whose specification or
body changed against the base, a generic unit through its instantiations, since GNATprove
analyzes a generic only there. With --all, every unit of the core the same way, for the
nightly run; with --shard k/n, the k-th of n groups of about equal source, counting a
generic's source for its instantiation.
Usage: changed-units.py <base-ref> | --all [--shard k/n]."""
import pathlib
import re
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
shard = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--shard" else None
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
    """The units instantiating a generic unit, by its Ada name or, for a child of a generic
    unit, by its name under each instance of the parent."""
    names = [name.replace("-", ".")]
    parent, _, child = name.rpartition("-")
    if parent and is_generic(parent):
        names += [instance.replace("-", ".") + "." + child for instance in instantiations(parent)]
    found = set()
    for ada in names:
        pattern = re.compile(r"\bis\s+new\s+" + re.escape(ada) + r"\b", re.IGNORECASE)
        found |= {spec.stem for spec in src.glob("*.ads") if pattern.search(code(spec))}
    return found


if base == "--all":
    changed = [str(p) for p in src.glob("*.ad[sb]")]
else:
    changed = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"],
                             check=True, capture_output=True, text=True).stdout.split()
selected = {pathlib.Path(c).stem for c in changed
            if c.startswith("core/src/") and c.endswith((".ads", ".adb"))}
for name in list(selected):
    if is_generic(name):
        selected.remove(name)
        selected |= instantiations(name)



def generic_of(name):
    """The generic unit an instance unit instantiates, through the parent's generic for a
    child instantiated under an instance of its parent, or the unit itself."""
    spec, body = src / (name + ".ads"), src / (name + ".adb")
    if body.exists() or not spec.exists():
        return name
    generic = re.search(r"\bis\s+new\s+([\w.]+)", code(spec))
    if not generic:
        return name
    target = generic.group(1).lower().replace(".", "-")
    parent, _, child = target.rpartition("-")
    if not (src / (target + ".ads")).exists() and parent and (src / (parent + ".ads")).exists():
        target = generic_of(parent) + "-" + child
    return target


def weight(name):
    """The bytes of source a unit's proof covers: its own, or its generic's for an instantiation."""
    name = generic_of(name)
    return sum(f.stat().st_size for f in (src / (name + ".ads"), src / (name + ".adb")) if f.exists())


if shard:
    k, n = (int(v) for v in shard.split("/"))
    loads, groups = [0] * n, [set() for _ in range(n)]
    for name in sorted(selected, key=lambda u: (-weight(u), u)):
        i = loads.index(min(loads))
        groups[i].add(name)
        loads[i] += weight(name)
    selected = groups[k]

for name in sorted(selected):
    body = src / (name + ".adb")
    spec = src / (name + ".ads")
    if body.exists():
        print(body.name)
    elif spec.exists():
        print(spec.name)
