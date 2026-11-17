#!/usr/bin/env python3
"""Checks the board generator against the gyro device vectors: each line's define set, written as a board
configuration file, must give the board values the line lists (SPI bus or zero without a gyro driver on an SPI
bus, select, interrupt and clock pin tags, alignment code, custom angles).
Usage: boardgen-check.py <gyrodev.csv>"""
import importlib.util
import os
import re
import sys
import tempfile

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("boardgen", os.path.join(here, "boardgen.py"))
boardgen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(boardgen)
NAMES = ("Gyro_1_CS_Tag", "Gyro_1_EXTI_Tag", "Gyro_Clkin_Tag", "Gyro_1_Align", "Gyro_1_Align_Roll",
         "Gyro_1_Align_Pitch", "Gyro_1_Align_Yaw")
failures = lines = 0
for line in open(sys.argv[1]):
    f = line.rstrip("\n").split(",")
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
    spi = int(values["Gyro_1_SPI_Device"]) if values["Gyro_SPI"] == "True" else 0
    got = [spi] + [int(values[n]) for n in NAMES]
    wanted = [int(v) for v in f[4:12]]
    if got != wanted:
        failures += 1
        print(f"boardgen: gyro define set {f[1]} gives {got}, the vectors list {wanted}")
if failures or not lines:
    print(f"boardgen check: {failures} of {lines} define sets differ")
    sys.exit(1)
print("boardgen checks passed")
