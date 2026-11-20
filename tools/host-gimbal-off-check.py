#!/usr/bin/env python3
"""Checks a build of the host image without the gimbal control over its UART1 TCP port: its settings have no gimbal
setting.

usage: host-gimbal-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "gimbaloff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            # The servo gimbal's mode belongs to the servos, which this build keeps.
            gimbal = [n for n in names if n.startswith("gimbal_") and n != "gimbal_mode"]
            hs.check("dump has no gimbal settings there", "gimbal_mode" in names and not gimbal, repr(gimbal))
            text = hs.cli(sock, "get gimbal_uart")
            hs.check("get finds no gimbal setting there", "INVALID NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-gimbal-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
