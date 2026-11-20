#!/usr/bin/env python3
"""Checks a build of the host image without the rangefinders over its UART1 TCP port: its settings have no
rangefinder or optical flow setting, and its resource command neither lists nor takes a sonar pin.

usage: host-rangefinder-off-check.py <host image>"""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("host_smoke", os.path.join(HERE, "host-smoke.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    with tempfile.TemporaryDirectory() as work:
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "rangefinderoff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            gone = ("rangefinder_hardware", "rangefinder_uart", "opticalflow_", "osd_lidar_dist_pos")
            hs.check("dump has no rangefinder or optical flow settings there",
                     "rangefinder_max_range_cm" in names and not any(n.startswith(gone) for n in names),
                     repr([n for n in names if n.startswith(gone)]))
            text = hs.cli(sock, "get rangefinder_hardware")
            hs.check("get finds no rangefinder setting there", "INVALID NAME" in text, text[-120:])
            hs.check("dump has no sonar pins there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("SONAR_" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource SONAR_TRIGGER A01")
            hs.check("resource takes no sonar pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-rangefinder-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
