#!/usr/bin/env python3
"""Checks the board generator against the gyro device vectors: each line's define set, written as a board
configuration file, must give the board values the line lists: the gyro count, the default enabled mask, and
for each gyro of that count its SPI bus or zero without a gyro driver on an SPI bus, its select, interrupt and
clock pin tags, its alignment code and its custom angles.
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
NAMES = (("Gyro_1_SPI_Device", "Gyro_1_CS_Tag", "Gyro_1_EXTI_Tag", "Gyro_Clkin_Tag", "Gyro_1_Align",
          "Gyro_1_Align_Roll", "Gyro_1_Align_Pitch", "Gyro_1_Align_Yaw"),
         ("Gyro_2_SPI_Device", "Gyro_2_CS_Tag", "Gyro_2_EXTI_Tag", "Gyro_2_Clkin_Tag", "Gyro_2_Align",
          "Gyro_2_Align_Roll", "Gyro_2_Align_Pitch", "Gyro_2_Align_Yaw"))
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
if failures or not lines:
    print(f"boardgen check: {failures} of {lines} define sets differ")
    sys.exit(1)
print("boardgen checks passed")
