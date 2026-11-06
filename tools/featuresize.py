#!/usr/bin/env python3
"""Measure each feature's flash cost for one board.

usage: featuresize.py <board> [features]

A build of the board's selection comes first, then a build with each feature switched, every one through target.do.
A feature on in the selection costs what leaving it out saves, and a feature off costs what adding it takes. A
build past its flash region counts its code size from the overflow its link or its packing names. A build that
fails for another reason leaves its feature without a cost, and with that reason. The result goes to
targets/<crate>/bin/sizes-<board>.json and to the output as JSON, and a line per build to the error output.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP = {"Packed_Data", "Stack_Check"}


def board_info(board: str, features: str) -> dict:
    run = subprocess.run([sys.executable, str(ROOT / "tools/featuregen.py"), "--json",
                          str(ROOT / "third_party/board-configs/configs"), board, features],
                         capture_output=True, text=True)
    if run.returncode != 0:
        raise SystemExit(run.stderr.strip())
    return json.loads(run.stdout)


def region_bytes(crate: str) -> int:
    text = (ROOT / "targets" / crate / "gen/memory.ld").read_text()
    m = re.search(r"^\s*flash\s+\(rx\)\s*:\s*ORIGIN\s*=\s*0x[0-9A-Fa-f]+,\s*LENGTH\s*=\s*(\d+)K", text, re.M)
    if not m:
        raise SystemExit(f"featuresize: no flash region in targets/{crate}/gen/memory.ld")
    return int(m.group(1)) * 1024


def build(board: str, crate: str, features: str):
    """The build's code size and its flash region, or the reason it failed when that is not its flash size."""
    env = dict(os.environ, BOARD=board, CRATE=crate, FEATURES=features)
    run = subprocess.run(["bash", "target.do"], cwd=ROOT, env=env, capture_output=True, text=True)
    text = run.stdout + run.stderr
    fits = re.search(r"target: code (\d+) of (\d+) bytes", text)
    if run.returncode == 0 and fits:
        return int(fits.group(1)), int(fits.group(2))
    over = re.search(r"region `flash' overflowed by (\d+) bytes|overflows the flash region by (\d+) bytes", text)
    if over:
        room = region_bytes(crate)
        return room + int(over.group(1) or over.group(2)), room
    other = re.search(r"region `\w+' overflowed by \d+ bytes|\S+: error: .*|^target: .*", text, re.M)
    return other.group(0) if other else "the build failed"


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    board = sys.argv[1]
    changes = sys.argv[2] if len(sys.argv) == 3 else ""
    info = board_info(board, changes)
    crate = info["crate"]
    if crate is None:
        raise SystemExit(f"featuresize: no board crate builds the {info['mcu']}")
    base = build(board, crate, changes)
    if isinstance(base, str):
        raise SystemExit(f"featuresize: {board} with '{changes}' does not build: {base}")
    used, room = base
    print(f"featuresize: {board} '{changes}' {used} of {room} bytes", file=sys.stderr, flush=True)
    costs, failures = {}, {}
    measured = [feature for feature in info["features"] if feature["name"] not in SKIP]
    for count, feature in enumerate(measured, 1):
        name = feature["name"]
        state = "off" if feature["on"] else "on"
        print(f"featuresize: building {board} with {name} {state} ({count} of {len(measured)})", file=sys.stderr,
              flush=True)
        switched = build(board, crate, f"{changes} {'-' if feature['on'] else '+'}{name}".strip())
        if isinstance(switched, str):
            costs[name] = None
            failures[name] = switched
            print(f"featuresize: {name} {'off' if feature['on'] else 'on'}: {switched}", file=sys.stderr, flush=True)
        else:
            costs[name] = used - switched[0] if feature["on"] else switched[0] - used
            print(f"featuresize: {name} {'off' if feature['on'] else 'on'}: {costs[name]} bytes",
                  file=sys.stderr, flush=True)
    build(board, crate, changes)
    result = {"board": board, "crate": crate, "features": changes, "used": used, "room": room, "costs": costs,
              "failures": failures}
    text = json.dumps(result, indent=1) + "\n"
    (ROOT / "targets" / crate / "bin" / f"sizes-{board}.json").write_text(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
