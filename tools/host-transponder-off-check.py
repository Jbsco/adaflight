#!/usr/bin/env python3
"""Checks a build of the host image without the race transponder over its UART1 TCP port: its resource command
neither lists nor takes a transponder pin.

usage: host-transponder-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "transponderoff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no transponder pin there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("TRANSPONDER" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource TRANSPONDER A01")
            hs.check("resource takes no transponder pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-transponder-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
