#!/usr/bin/env python3
"""Build one board from each feature set of the board configurations.

usage: boardsurvey.py [--list]

The STM32F4 and STM32F7 board configurations fall into sets by MCU and by the features their builds choose
(tools/featuregen.py). The gates build a handful of boards, so a set none of them covers can stop building
unseen. This builds the first board of each set through target.do, and a second one from the middle of a set of
ten boards or more, and prints a line per build: its code size against its flash region, its overflow in bytes,
or the reason another failure gives. A line names its set by MCU, board count and the features a board's
configuration decides. An MCU without a memory layout is named and not built. With --list it prints the sets and
builds nothing. The exit status is nonzero when a build fails or an MCU has no layout.
"""
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import featuregen  # noqa: E402
import featuresize  # noqa: E402
import memorygen  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CONFIGS = ROOT / "third_party/board-configs/configs"


def crate_of(mcu: str):
    return "stm32f4" if mcu.startswith("STM32F4") else "stm32f7" if mcu.startswith("STM32F7") else None


def feature_sets() -> dict:
    """The boards of each set, keyed by crate, MCU and the features on."""
    sets = {}
    for config in sorted(CONFIGS.glob("*/*/config.h")):
        board = config.parent.name
        m = re.search(r"^#define\s+FC_TARGET_MCU\s+(\w+)", config.read_text(), re.M)
        mcu = m.group(1) if m else ""
        crate = crate_of(mcu)
        if crate is None:
            continue
        if mcu in memorygen.LAYOUTS:
            _, _, chosen = featuregen.board_selection(CONFIGS, board, "")
            on = tuple(name for name, _, _ in featuregen.FEATURES if chosen[name])
        else:
            on = ()
        sets.setdefault((crate, mcu, on), []).append(board)
    return sets


def main() -> None:
    if sys.argv[1:] not in ([], ["--list"]):
        raise SystemExit(__doc__)
    listing = sys.argv[1:] == ["--list"]
    sets = feature_sets()
    failed = False
    for (crate, mcu, on), boards in sorted(sets.items(), key=lambda item: (item[0][0], item[0][1], -len(item[1]))):
        decided = ",".join(name for name in on if name in featuregen.BOARD_DEFINES)
        label = f"{crate} {mcu} x{len(boards)} [{decided or '-'}]"
        if mcu not in memorygen.LAYOUTS:
            print(f"no memory layout: {label} {boards[0]}", flush=True)
            failed = True
            continue
        picked = [boards[0]] + ([boards[len(boards) // 2]] if len(boards) >= 10 else [])
        if listing:
            print(f"{label} {' '.join(picked)}", flush=True)
            continue
        for board in picked:
            result = featuresize.build(board, crate, "")
            if isinstance(result, str):
                print(f"failed: {label} {board}: {result}", flush=True)
                failed = True
            elif result[0] > result[1]:
                print(f"over by {result[0] - result[1]} bytes: {label} {board}: code {result[0]} of {result[1]} bytes",
                      flush=True)
                failed = True
            else:
                print(f"ok: {label} {board}: code {result[0]} of {result[1]} bytes", flush=True)
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
