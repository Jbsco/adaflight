#!/usr/bin/env python3
"""Checks a build of the host image without the compass over its UART1 TCP port: peripherals prints no compass line
for a configured compass, and its resource command neither lists nor takes a compass pin.

usage: host-compass-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "compassoff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            # A build with the compass prints a configured one that it did not detect.
            hs.cli(sock, "set mag_hardware = HMC5883")
            text = hs.cli(sock, "peripherals")
            hs.check("peripherals prints no compass line there",
                     "peripherals" in text and "UNKNOWN COMMAND" not in text and "mag:" not in text, text[-200:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no compass pins there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("COMPASS_" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource COMPASS_CS A01")
            hs.check("resource takes no compass pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-compass-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
