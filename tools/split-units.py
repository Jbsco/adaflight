#!/usr/bin/env python3
"""Split the units a proof run selected into groups of about equal source size, one
proof job each. Usage: split-units.py <units-file> <groups>. Prints a JSON list of
numbered groups, each with its units space-separated. Eight units or fewer stay in one
group, since a job's set-up costs more than their proof."""
import json
import pathlib
import sys

units = sorted(u for u in pathlib.Path(sys.argv[1]).read_text().split() if u)
groups = int(sys.argv[2]) if len(units) > 8 else 1
src = pathlib.Path("core/src")


def size(unit):
    stem = unit[:-len(".adb")]
    return sum((src / (stem + ext)).stat().st_size
               for ext in (".adb", ".ads") if (src / (stem + ext)).exists())


bins = [[0, []] for _ in range(groups)]
for unit in sorted(units, key=lambda u: (-size(u), u)):
    target = min(bins, key=lambda b: b[0])
    target[0] += size(unit)
    target[1].append(unit)
chosen = [sorted(b[1]) for b in bins if b[1]]
assert sorted(u for group in chosen for u in group) == units, "groups do not cover the units"
print(json.dumps([{"group": n + 1, "units": " ".join(group)} for n, group in enumerate(chosen)]))
