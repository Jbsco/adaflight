#!/usr/bin/env python3
"""Checks a build of the host image without the pitot sensor over its UART1 TCP port: its settings have no pitot
setting.

usage: host-pitot-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "pitotoff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            gone = ("pitot_", "blackbox_disable_pitot", "osd_airspeed")
            hs.check("dump has no pitot settings there",
                     "acc_hardware" in names and not any(n.startswith(gone) for n in names),
                     repr([n for n in names if n.startswith(gone)]))
            text = hs.cli(sock, "get pitot_hardware")
            hs.check("get finds no pitot setting there", "INVALID NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-pitot-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
