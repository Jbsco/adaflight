#!/usr/bin/env python3
"""Checks the board generator against the gyro device vectors: each line's define set, written as a board
configuration file, must give the board values the line lists: the gyro count, the default enabled mask, and
for each gyro of that count its SPI bus or zero without a gyro driver on an SPI bus, its select, interrupt and
clock pin tags, its alignment code and its custom angles. A board driver line names a board configuration by its
position in the byte-ordered list of configuration paths, and whether it builds the SPI MPU6500 gyro driver and the
accelerometer one; every board has one. Board pin lines list a board configuration's pin defines and timer map
entries, by the board's position, as the C preprocessor reads the file alone, and the generator must read the
same, no more and no fewer. Board lines go unchecked, and are reported, where the board configuration submodule
is not checked out.
Usage: boardgen-check.py <gyrodev.csv, boarddrv.csv or boardpins.csv>"""
import importlib.util
import os
import re
import sys
import tempfile

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("boardgen", os.path.join(here, "boardgen.py"))
boardgen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(boardgen)
NAMES = (("Gyro_1_SPI_Device", "Gyro_1_CS_Tag", "Gyro_1_EXTI_Tag", "Gyro_Clkin_Tag", "Gyro_1_Align",
          "Gyro_1_Align_Roll", "Gyro_1_Align_Pitch", "Gyro_1_Align_Yaw"),
         ("Gyro_2_SPI_Device", "Gyro_2_CS_Tag", "Gyro_2_EXTI_Tag", "Gyro_2_Clkin_Tag", "Gyro_2_Align",
          "Gyro_2_Align_Roll", "Gyro_2_Align_Pitch", "Gyro_2_Align_Yaw"))
failures = lines = 0
configs = os.path.join(here, "..", "third_party", "board-configs", "configs")
boards = sorted(os.path.relpath(d, configs) for d, _, files in os.walk(configs) if "config.h" in files)
driver_lines = skipped = 0
pins, timers = {}, {}
for line in open(sys.argv[1]):
    f = line.rstrip("\n").split(",")
    if f[0] in ("boarddrv", "boardpin", "boardtimer") and not boards:
        skipped += 1
        continue
    if f[0] == "boardpin":
        pins.setdefault(int(f[1]), {})[f[2]] = f[3]
        continue
    if f[0] == "boardtimer":
        timers.setdefault(int(f[1]), []).append((int(f[3]), f[4], int(f[5]), int(f[6])))
        continue
    if f[0] == "boarddrv":
        lines += 1
        driver_lines += 1
        board = boards[int(f[1])]
        with open(os.path.join(configs, board, "config.h")) as config:
            got = [int(v) for v in boardgen.mpu6500_drivers(boardgen.config_defines(config.read()))]
        if got != [int(f[2]), int(f[3])]:
            failures += 1
            if failures <= 10:
                print(f"boardgen-check: {board}: MPU6500 drivers {got}, want {f[2:4]}")
        continue
    if f[0] != "gyrodev":
        continue
    lines += 1
    with tempfile.TemporaryDirectory() as work:
        board = os.path.join(work, "MAKER", "BOARD")
        os.makedirs(board)
        config = os.path.join(board, "config.h")
        with open(config, "w") as out:
            for define in f[2].split(";"):
                name, _, value = define.partition("=")
                out.write(f"#define {name} {value}".rstrip() + "\n")
        text = boardgen.generate(boardgen.Path(config), {})
    values = dict(re.findall(r"^   (\w+) +: constant(?: Boolean)? := (-?\w+);", text, re.M))
    count = int(values["Gyro_Count"])
    got = [count, int(values["Default_Gyros_Enabled"])]
    for gyro, names in enumerate(NAMES):
        row = [int(values[n]) for n in names] if gyro < count else [0] * len(names)
        if values["Gyro_SPI"] != "True":
            row[0] = 0
        got += row
    wanted = [int(v) for v in f[3:21]]
    if got != wanted:
        failures += 1
        print(f"boardgen: gyro define set {f[1]} gives {got}, the vectors list {wanted}")
for position in range(len(boards)) if pins or timers else ():
    lines += 1
    board = boards[position]
    with open(os.path.join(configs, board, "config.h")) as config:
        defines = boardgen.config_defines(config.read())
    got = {k: v for k, v in defines.items() if k.endswith("_PIN")}
    entries = boardgen.timer_entries(defines)
    # The receiver input pins' tags the generated board package gives the configuration reset.
    text = boardgen.generate(boardgen.Path(os.path.join(configs, board, "config.h")), {})
    values = dict(re.findall(r"^   (\w+) +: constant(?: Boolean)? := (-?\w+);", text, re.M))
    for name, define in [("PPM_Tag", "RX_PPM_PIN")] + [(f"PWM{i}_Tag", f"RX_PWM{i}_PIN") for i in range(1, 5)]:
        if int(values[name]) != boardgen.pin_tag(pins.get(position, {}).get(define, "")):
            failures += 1
            if failures <= 10:
                print(f"boardgen-check: {board}: {name} {values[name]}, the vectors' {define} is "
                      f"{pins.get(position, {}).get(define)}")
    if got != pins.get(position, {}) or entries != timers.get(position, []):
        failures += 1
        if failures <= 10:
            differ = sorted(k for k in set(got) | set(pins.get(position, {}))
                            if got.get(k) != pins.get(position, {}).get(k))
            print(f"boardgen-check: {board}: pins {differ[:4]} or timer map entries read differently")
if driver_lines and driver_lines != len(boards):
    failures += 1
    print(f"boardgen-check: {driver_lines} board driver lines for {len(boards)} board configurations")
if skipped and not lines and not failures:
    print(f"boardgen check: {skipped} board lines not checked, the board configuration submodule is not checked out")
    sys.exit(0)
if failures or not lines:
    print(f"boardgen check: {failures} of {lines} define sets differ")
    sys.exit(1)
print("boardgen checks passed")
