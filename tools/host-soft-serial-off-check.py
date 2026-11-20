#!/usr/bin/env python3
"""Checks a build of the host image without the software serial ports over its UART1 TCP port: its board information
reports no software serial ports, and its resource command neither lists nor takes a software serial pin.

usage: host-soft-serial-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "softserialoff.bin"))
        try:
            hs.time.sleep(2.5)
            info = hs.msp(sock, 4) or b""
            hs.check("board information reports no software serial ports there",
                     len(info) > 7 and info[7] & 0x01 and not info[7] & 0x02, repr(info[:9]))
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no software serial pins there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("SOFTSERIAL" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource SOFTSERIAL_TX 1 A01")
            hs.check("resource takes no software serial pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-soft-serial-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
