#!/usr/bin/env python3
"""Check that an STM32 image's deepest call paths fit its main stack.

usage: stackdepth.py <elf>

Runs in the crate directory with the ARM toolchain on the path. A function's frame is the sum of its pushes and of
the constants it subtracts from the stack pointer. A call is a branch to another function, through a long branch
veneer where the linker placed one, and the run-time library's start calls each entry of .init_array. Each path
must leave MARGIN bytes for an interrupt's exception frame and frames sized at run time: the start's path through
main within the whole stack, and in a packed image the unpacking's path within the stack above its model and the
elaboration's path within the stack above the boot code. Calls through registers and frames sized at run time count
as nothing and are listed with each path, and a path stops at a function it already passed through.
"""
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from featuregen import UNPACK_SCRATCH  # noqa: E402

MARGIN = 1024
START, INIT, ELABORATION = "_start_rom", "__libc_init_array", "adainit"
BRANCH = re.compile(r"(?:bl|blx|b)(?:eq|ne|cs|cc|hs|lo|mi|pl|vs|vc|hi|ls|ge|lt|gt|le)?(?:\.[wn])?|cbn?z")


def run(*args) -> str:
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def registers(text: str) -> tuple:
    """The number of registers a register list names, and their size in bytes."""
    n, size = 0, 4
    for part in text.strip("{} ").split(","):
        r = re.match(r"\s*([a-z]+)(\d+)-[a-z]+(\d+)", part)
        n += int(r.group(3)) - int(r.group(2)) + 1 if r else 1
        size = 8 if part.strip().startswith("d") else size
    return n, size


def graph(elf: Path) -> tuple:
    """Each function's frame, callees, calls through registers and frames sized at run time."""
    frame, calls, indirect, dynamic, at = {}, {}, {}, {}, {}
    name, veneer = None, False
    for line in run("arm-eabi-objdump", "-d", str(elf)).splitlines():
        m = re.match(r"([0-9a-f]{8}) <(.+)>:$", line)
        if m:
            name, veneer = m.group(2), False
            at[int(m.group(1), 16)] = name
            frame[name], calls[name], indirect[name], dynamic[name] = 0, set(), 0, 0
            continue
        m = re.match(r"\s*[0-9a-f]+:\t[0-9a-f ]+\t(\S+)\t?([^@]*)", line)
        if name is None or not m:
            continue
        op, args = m.group(1), m.group(2).strip()
        if op in ("push", "push.w") or op in ("stmdb", "stmdb.w") and args.startswith("sp!"):
            frame[name] += 4 * registers(args.split(",", 1)[1] if op.startswith("stmdb") else args)[0]
        elif op in ("vpush", "vstmdb") and (op == "vpush" or args.startswith("sp!")):
            n, size = registers(args.split(",", 1)[1] if op == "vstmdb" else args)
            frame[name] += n * size
        elif re.fullmatch(r"str(?:\.w)?", op) and re.search(r"\[sp, #-(\d+)\]!$", args):
            frame[name] += int(re.search(r"#-(\d+)", args).group(1))
        elif re.fullmatch(r"sub(?:\.w|w)?", op) and re.match(r"sp, (?:sp, )?#\d+", args):
            frame[name] += int(re.search(r"#(\d+)", args).group(1))
        elif re.fullmatch(r"sub(?:\.w)?", op) and re.match(r"sp, (?:sp, )?(?:r\d+|ip|sl|fp)$", args):
            dynamic[name] += 1
        elif op == "ldr.w" and args == "pc, [pc]":
            veneer = True
        elif op == ".word" and veneer:
            calls[name].add(int(args, 16) & ~1)
            veneer = False
        elif op in ("blx", "bx") and re.fullmatch(r"r\d+|ip", args):
            indirect[name] += 1
        elif BRANCH.fullmatch(op):
            t = re.search(r"\b([0-9a-f]+) <([^>+]+)", args)
            if t and t.group(2) != name:
                calls[name].add(t.group(2))
    for f in calls:
        calls[f] = {at.get(c, "") if isinstance(c, int) else c for c in calls[f]} - {""}
    dump = run("arm-eabi-objdump", "-s", "-j", ".init_array", str(elf))
    for words in re.findall(r"^ [0-9a-f]+ ((?:[0-9a-f]{8} ?){1,4})", dump, re.M):
        for w in words.split():
            calls.setdefault(INIT, set()).add(at.get(int.from_bytes(bytes.fromhex(w), "little") & ~1, ""))
    calls.get(INIT, set()).discard("")
    return frame, calls, indirect, dynamic


def deepest(root: str, frame: dict, calls: dict) -> list:
    """The deepest path from root, by the sum of its frames."""
    memo = {}

    def walk(f: str, path: frozenset) -> list:
        if f in memo:
            return memo[f]
        best = []
        for g in sorted(calls.get(f, ())):
            if g not in path:
                p = walk(g, path | {g})
                if sum(frame.get(h, 0) for h in p) > sum(frame.get(h, 0) for h in best):
                    best = p
        memo[f] = [f] + best
        return memo[f]

    return walk(root, frozenset({root})) if root in frame else []


def symbols(elf: Path) -> dict:
    out = {}
    for line in run("arm-eabi-nm", str(elf)).splitlines():
        parts = line.split()
        if len(parts) == 3:
            out[parts[2]] = int(parts[0], 16)
    return out


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    elf = Path(sys.argv[1])
    frame, calls, indirect, dynamic = graph(elf)
    syms = symbols(elf)
    sys.setrecursionlimit(20000)
    top = syms["__stack_end"]
    checks = [("start", [START], top - syms["__stack_start"])]
    if syms.get("__boot_end", 0) > syms.get("__boot_start", 0):
        checks.append(("unpacking", [START, INIT], top - syms["__unpack_scratch"] - UNPACK_SCRATCH))
        checks.append(("elaboration", [START, "main", ELABORATION], top - syms["__boot_end"]))
    failed = False
    for phase, head, room in checks:
        path = head[:-1] + deepest(head[-1], frame, calls)
        depth = sum(frame.get(f, 0) for f in path)
        print(f"stackdepth: {phase} path {depth} of {room} bytes, {room - depth - MARGIN} to spare after a margin "
              f"of {MARGIN}")
        for f in path:
            notes = (f", {indirect[f]} calls through registers" if indirect.get(f) else "") + \
                (f", {dynamic[f]} frames sized at run time" if dynamic.get(f) else "")
            print(f"  {frame.get(f, 0):6d} {f}{notes}")
        failed = failed or depth + MARGIN > room
    if failed:
        raise SystemExit("stackdepth: a path does not fit its stack with the margin")


if __name__ == "__main__":
    main()
