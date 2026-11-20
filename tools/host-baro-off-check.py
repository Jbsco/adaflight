#!/usr/bin/env python3
"""Checks a build of the host image without the barometer over its UART1 TCP port: peripherals prints no barometer line
for a configured barometer, and its resource command neither lists nor takes a barometer pin.

usage: host-baro-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "barooff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            # A build with the barometer prints a configured one that it did not detect.
            hs.cli(sock, "set baro_hardware = MS5611")
            text = hs.cli(sock, "peripherals")
            hs.check("peripherals prints no barometer line there",
                     "peripherals" in text and "UNKNOWN COMMAND" not in text and "baro:" not in text, text[-200:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no barometer pins there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("BARO_" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource BARO_CS A01")
            hs.check("resource takes no barometer pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-baro-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
