#!/usr/bin/env python3
"""Print the core units a pull request has to prove: every unit whose specification or
body changed against the base, and every unit that depends on a changed specification by a
with clause or as its child, since a changed declaration can undo a proof in a unit the
pull request leaves alone. A generic unit goes through its instantiations, since GNATprove
analyzes a generic only there. With --all, every unit of the core the same way, for the
nightly run; with --shard k/n, the k-th of n groups of about equal source, counting a
generic's source for its instantiation; with --shards, the number of groups the selection
needs for a group to cover no more source than one of the nightly run's six, each with a
unit. A naming variant (a stem with a double underscore), which the core project takes in
place of its default by a scenario variable, is left out.
Usage: changed-units.py <base-ref> | --all [--shard k/n | --shards]."""
import pathlib
import re
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
shard = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--shard" else None
count_shards = len(sys.argv) > 2 and sys.argv[2] == "--shards"
NIGHTLY_SHARDS = 6
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
            if c.startswith("core/src/") and c.endswith((".ads", ".adb")) and "__" not in pathlib.Path(c).stem}


def dependents(name):
    """The units that name a unit, or a child of it, in a with clause, and the unit's children."""
    ada = name.replace("-", ".").lower()
    clause = re.compile(r"^\s*(?:(?:private|limited)\s+)*with\s+([^;]+);", re.IGNORECASE | re.MULTILINE)
    found = set()
    for file in src.glob("*.ad[sb]"):
        if "__" in file.stem or file.stem == name:
            continue
        if file.stem.startswith(name + "-"):
            found.add(file.stem)
            continue
        withed = {unit.strip().lower() for names in clause.findall(code(file)) for unit in names.split(",")}
        if any(unit == ada or unit.startswith(ada + ".") for unit in withed):
            found.add(file.stem)
    return found


if base != "--all":
    for spec in sorted(pathlib.Path(c).stem for c in changed
                       if c.startswith("core/src/") and c.endswith(".ads") and "__" not in pathlib.Path(c).stem):
        selected |= dependents(spec)
pending = sorted(name for name in selected if is_generic(name))
expanded = set()
while pending:
    name = pending.pop()
    if name in expanded:
        continue
    expanded.add(name)
    selected.discard(name)
    for instance in instantiations(name):
        if instance not in expanded:
            selected.add(instance)
            if is_generic(instance):
                pending.append(instance)



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


if count_shards:
    everything = sum(f.stat().st_size for f in src.glob("*.ad[sb]") if "__" not in f.stem)
    load = sum(weight(name) for name in selected)
    print(max(1, min(NIGHTLY_SHARDS, len(selected), -(-load * NIGHTLY_SHARDS // everything))))
    sys.exit(0)

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
