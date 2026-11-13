#!/usr/bin/env python3
"""Check that an STM32 image's deepest call paths fit its main stack and its interrupt stack.

usage: stackdepth.py <elf> [--paths N]

Runs in the crate directory with the ARM toolchain on the path. A function's frame is the sum of its pushes and of
the constants it subtracts from the stack pointer. A call is a branch to another function, through a long branch
veneer where the linker placed one, and the run-time library's start calls each entry of .init_array. Each path
must leave MARGIN bytes for an interrupt's exception frame and frames sized at run time: the start's path through
main within the whole stack, and in a packed image the unpacking's path within the stack above its model and the
elaboration's path within the stack above the boot code. Calls through registers and frames sized at run time count
as nothing and are listed with each path, and a path stops at a function it already passed through. With --paths N
the start's check also lists up to N - 1 further paths, each one the deepest path that avoids the largest frame of
every path listed before it.

Interrupt handlers run on the run-time library's interrupt stack, one stack for every nested handler. The handlers
are the procedures the board crates' sources attach in protected objects, at their objects' priorities. The worst
case is a context switch interrupted by a handler of each priority in turn and then by the run-time library's
alarm. Each level costs its entry code and its deepest path, and each level above the first an exception frame,
extended where the level below uses floating point. That sum must leave INTERRUPT_MARGIN bytes. A handler's call
through a register must be one the check can follow: a callback registered through a call REGISTRATIONS names.
The alarm calls a timing event's handler through a register too, so sources that use timing events fail.
"""
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from featuregen import UNPACK_SCRATCH  # noqa: E402

MARGIN = 1024
INTERRUPT_MARGIN = 256
# An exception frame with its alignment word, without and with floating point state.
BASIC_FRAME, EXTENDED_FRAME = 36, 108
# The run-time library's interrupt priorities, 241 to 255.
PRIORITIES = 15
SWITCH, ALARM = "__gnat_pend_sv_trap", "system__bb__time__alarm_handler"
WRAPPER = "system__bb__interrupts__interrupt_wrapper"
IRQ_ENTRY = ("__gnat_irq_trap", "system__bb__board_support__interrupt_handler", WRAPPER)
TICK_ENTRY = ("__gnat_sys_tick_trap", "system__bb__board_support__timer_interrupt_handler", WRAPPER)
# A registration call in the sources, and the prefix of the functions that call what it registered.
REGISTRATIONS = (("EXTI_Dispatch.Register", "adaflight__stm32__exti_dispatch__"),
                 ("ELRS_Timer.Init", "adaflight__stm32__elrs_timer__"),
                 ("RX_SPI_Device.Set_Edge_Handler", "adaflight__stm32__rx_spi_device__"))
PROTECTED = re.compile(r"^[ \t]*protected (?:type )?(\w+)\s+with\s+Interrupt_Priority\s*=>\s*([^,\n]+?)\s*"
                       r"(?:,[^\n]*)?\s+is\n"
                       r"(.*?)^[ \t]*end \1;", re.M | re.S)
ATTACH = re.compile(r"procedure\s+(\w+)\s+with\s+Attach_Handler\s*=>")
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
    """Each function's frame, callees, calls through registers and frames sized at run time, and whether it has a
    floating point instruction."""
    frame, calls, indirect, dynamic, floating, at = {}, {}, {}, {}, {}, {}
    name, veneer = None, False
    for line in run("arm-eabi-objdump", "-d", str(elf)).splitlines():
        m = re.match(r"([0-9a-f]{8}) <(.+)>:$", line)
        if m:
            name, veneer = m.group(2), False
            at[int(m.group(1), 16)] = name
            frame[name], calls[name], indirect[name], dynamic[name], floating[name] = 0, set(), 0, 0, False
            continue
        m = re.match(r"\s*[0-9a-f]+:\t[0-9a-f ]+\t(\S+)\t?([^@]*)", line)
        if name is None or not m:
            continue
        op, args = m.group(1), m.group(2).strip()
        floating[name] = floating[name] or op.startswith("v")
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
    return frame, calls, indirect, dynamic, floating


def deepest(root: str, frame: dict, calls: dict, avoid: frozenset = frozenset()) -> list:
    """The deepest path from root, by the sum of its frames, through no function in avoid."""
    memo = {}

    def walk(f: str, path: frozenset) -> list:
        if f in memo:
            return memo[f]
        best = []
        for g in sorted(calls.get(f, ())):
            if g not in path and g not in avoid:
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


def show(f: str, frame: dict, indirect: dict, dynamic: dict) -> None:
    notes = (f", {indirect[f]} calls through registers" if indirect.get(f) else "") + \
        (f", {dynamic[f]} frames sized at run time" if dynamic.get(f) else "")
    print(f"  {frame.get(f, 0):6d} {f}{notes}")


def sources() -> list:
    """The board crates' sources: package name, text without comments, and file name."""
    out = []
    targets = Path(__file__).resolve().parent.parent / "targets"
    for path in [p for crate in ("stm32f4", "stm32f7") for p in sorted((targets / crate / "src").glob("*.ad[bs]"))]:
        text = re.sub(r"--[^\n]*", "", path.read_text())
        package = re.search(r"^package (?:body )?([\w.]+)", text, re.M)
        if package:
            out.append((package.group(1).lower().replace(".", "__") + "__", text, path.name))
    return out


def rank(priority: str, where: str) -> int:
    """A priority's place among the interrupt priorities, from their first one."""
    m = re.fullmatch(r"System\.Interrupt_Priority'(First|Last)(?:\s*([+-])\s*(\d+))?", priority)
    if not m or (m.group(2) or "+") != ("+" if m.group(1) == "First" else "-") and m.group(3):
        raise SystemExit(f"stackdepth: {where} has a priority this check does not read: {priority}")
    step = int(m.group(3) or 0)
    return step if m.group(1) == "First" else PRIORITIES - 1 - step


def attached(frame: dict) -> dict:
    """The image's attached handlers by their priority's rank."""
    levels = {}
    for prefix, text, name in sources():
        if re.search(r"\bTiming_Events?\b", text):
            raise SystemExit(f"stackdepth: {name} uses timing events, whose handlers this check does not follow")
        found = 0
        for obj in PROTECTED.finditer(text):
            for proc in ATTACH.finditer(obj.group(3)):
                found += 1
                symbol = f"{prefix}{obj.group(1).lower()}__{proc.group(1).lower()}P"
                if symbol in frame:
                    levels.setdefault(rank(obj.group(2), name), set()).add(symbol)
                elif any(f.startswith(f"{prefix}{obj.group(1).lower()}__") for f in frame):
                    raise SystemExit(f"stackdepth: {name} attaches {proc.group(1)}, which the image lacks as {symbol}")
        if found != len(re.findall(r"\bAttach_Handler\b", text)):
            raise SystemExit(f"stackdepth: {name} attaches a handler in a form this check does not read")
    return levels


def registered(frame: dict, calls: dict, indirect: dict) -> set:
    """Adds each registered callback as a callee of its dispatcher's functions that call through a register, and
    returns those functions."""
    dispatchers = set()
    for call, dispatcher in REGISTRATIONS:
        callbacks = set()
        for prefix, text, name in sources():
            for m in re.finditer(re.escape(call) + r"\s*\([^;]*?(\w+)'Access[^;]*\)\s*;", text, re.S):
                base = prefix + m.group(1).lower()
                names = {f for f in frame
                         if f == base or f.startswith(base + ".") or re.fullmatch(re.escape(base) + r"__\d+", f)}
                if not names and any(f.startswith(prefix) for f in frame):
                    raise SystemExit(f"stackdepth: {name} registers {m.group(1)}, which the image lacks as {base}")
                callbacks |= names
        for f in frame:
            if f.startswith(dispatcher) and indirect.get(f):
                calls[f] = calls[f] | callbacks
                dispatchers.add(f)
    return dispatchers


def reach(roots: list, calls: dict, frame: dict) -> set:
    seen, todo = set(roots), list(roots)
    while todo:
        for g in calls.get(todo.pop(), ()):
            if g not in seen and g in frame:
                seen.add(g)
                todo.append(g)
    return seen


def interrupts(frame: dict, calls: dict, indirect: dict, dynamic: dict, floating: dict, syms: dict) -> bool:
    """Prints the interrupt stack's worst case by level and returns whether it fails."""
    needed = (SWITCH, ALARM, WRAPPER, IRQ_ENTRY[0], TICK_ENTRY[0], "__interrupt_stack_start", "__interrupt_stack_end")
    for name in needed:
        if name not in frame and name not in syms:
            raise SystemExit(f"stackdepth: the image has no {name}")
    room = syms["__interrupt_stack_end"] - syms["__interrupt_stack_start"]
    dispatchers = registered(frame, calls, indirect)
    levels = [("context switch", (), [SWITCH])]
    levels += [(f"handlers at priority rank {r}", IRQ_ENTRY, sorted(h)) for r, h in sorted(attached(frame).items())]
    levels.append(("alarm", TICK_ENTRY, [ALARM]))
    total, extended, lines, unknown = 0, False, [], set()
    for k, (title, entry, roots) in enumerate(levels):
        path = max((deepest(h, frame, calls) for h in roots), key=lambda p: sum(frame.get(f, 0) for f in p))
        head = [f for f in entry if f in frame]
        between = 0 if k == 0 else EXTENDED_FRAME if extended else BASIC_FRAME
        cost = between + sum(frame.get(f, 0) for f in head + path)
        members = reach(roots, calls, frame)
        extended = any(floating.get(f) for f in members | set(head))
        unknown |= {f for f in members if indirect.get(f) and f not in dispatchers
                    and not f.startswith(("system__", "ada__", "__gnat"))}
        total += cost
        lines.append((f"stackdepth: interrupt level {k + 1}, {title}: {cost} bytes with an exception frame of "
                      f"{between}, {len(roots)} at this level", head + path))
    print(f"stackdepth: interrupts {total} of {room} bytes, {room - total - INTERRUPT_MARGIN} to spare after a margin "
          f"of {INTERRUPT_MARGIN}")
    for line, path in lines:
        print(line)
        for f in path:
            show(f, frame, indirect, dynamic)
    for f in sorted(unknown):
        print(f"stackdepth: {f} calls through a register on a handler's path, and no registration names its callees")
    return total + INTERRUPT_MARGIN > room or bool(unknown)


def main() -> None:
    if len(sys.argv) not in (2, 4) or len(sys.argv) == 4 and (sys.argv[2] != "--paths" or not sys.argv[3].isdigit()):
        raise SystemExit(__doc__)
    elf = Path(sys.argv[1])
    more = int(sys.argv[3]) - 1 if len(sys.argv) == 4 else 0
    frame, calls, indirect, dynamic, floating = graph(elf)
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
            show(f, frame, indirect, dynamic)
        failed = failed or depth + MARGIN > room
        avoid = frozenset()
        for k in range(more if phase == "start" else 0):
            avoid = avoid | {max(path[len(head) - 1:], key=lambda f: frame.get(f, 0))}
            path = head[:-1] + deepest(head[-1], frame, calls, avoid)
            print(f"stackdepth: start path {k + 2}, {sum(frame.get(f, 0) for f in path)} bytes")
            for f in path:
                show(f, frame, indirect, dynamic)
    failed = interrupts(frame, calls, indirect, dynamic, floating, syms) or failed
    if failed:
        raise SystemExit("stackdepth: a path does not fit its stack with the margin")


if __name__ == "__main__":
    main()
