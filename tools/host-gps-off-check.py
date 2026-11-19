#!/usr/bin/env python3
"""Checks a build of the host image without the GPS over its UART1 TCP port: the command line knows no
gpspassthrough command and its help lists none, and status and env print no GPS lines.

usage: host-gps-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "gpsoff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            text = hs.cli(sock, "gpspassthrough")
            hs.check("build without the GPS knows no gpspassthrough command", "UNKNOWN COMMAND" in text, text[-120:])
            text = hs.cli(sock, "help gpspass")
            hs.check("help lists no gpspassthrough command there", "NO MATCHES" in text, text[-120:])
            text = hs.cli(sock, "status")
            hs.check("status prints no GPS line there", "CPU:" in text and "GPS:" not in text, text[-200:])
            text = hs.cli(sock, "env")
            hs.check("env prints no GPS lines there", "OSD_DEVICE" in text and "GPS_" not in text, text[-200:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-gps-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
