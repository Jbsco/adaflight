#!/usr/bin/env python3
"""Runs host smoke's gyro chip checks for the named chips over a host image built for another board, such as a
board whose configuration builds only the MPU9250 driver. The board's gyro alignment, when it names one, turns
the expected readings.

usage: host-gyro-check.py [--align CW90|CW180|CW270] <host image> <chip>..."""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("host_smoke", os.path.join(HERE, "host-smoke.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)


def main() -> int:
    args = sys.argv[1:]
    turns = {"CW90": lambda v: (v[1], -v[0], v[2]), "CW180": lambda v: (-v[0], -v[1], v[2]),
             "CW270": lambda v: (-v[1], v[0], v[2])}
    turn = lambda v: v
    if len(args) >= 2 and args[0] == "--align":
        if args[1] not in turns:
            raise SystemExit(__doc__)
        turn = turns[args[1]]
        args = args[2:]
    if len(args) < 2:
        raise SystemExit(__doc__)
    known = {chip[0]: chip for chip in hs.GYRO_CHIPS}
    unknown = [name for name in args[1:] if name not in known]
    if unknown:
        raise SystemExit(f"host-gyro-check: no gyro model named {unknown}")
    image = os.path.abspath(args[0])
    hs.features = hs.build_features(image)
    with tempfile.TemporaryDirectory() as work:
        hs.gyro_chip_checks(image, work, [known[name] for name in args[1:]], turn)
    print("host-gyro-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
