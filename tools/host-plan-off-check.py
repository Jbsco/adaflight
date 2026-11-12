#!/usr/bin/env python3
"""Checks a multirotor build of the host image without the flight plan over its UART1 TCP port: the MSP box ids
leave out the autopilot and the waypoint capture and keep the holds, the build options leave the flight plan out,
and the command line knows no waypoint command in its help and dumps.

usage: host-plan-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "planoff.bin"))
        try:
            hs.time.sleep(2.5)
            ids = (hs.msp(sock, 119) or b"") + (hs.msp(sock, 119, bytes([1])) or b"")
            hs.check("box ids without the flight plan keep altitude and position hold",
                     len(ids) > 30 and 3 in ids and 11 in ids, repr(list(ids)))
            hs.check("box ids without the flight plan leave out the autopilot", 56 not in ids, repr(list(ids)))
            hs.check("box ids without the flight plan leave out waypoint capture", 57 not in ids, repr(list(ids)))
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            options = {int(w) for w in hs.cli(sock, "options").split() if w.isdigit()}
            hs.check("build without the flight plan leaves its build option out", 16427 not in options,
                     repr(sorted(options)))
            text = hs.cli(sock, "waypoint")
            hs.check("build without the flight plan knows no waypoint command", "UNKNOWN COMMAND" in text,
                     text[-120:])
            text = hs.cli(sock, "help waypoint")
            hs.check("help lists no waypoint command there", "NO MATCHES" in text, text[-120:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no waypoint section there",
                     any(line.startswith("aux ") for line in lines)
                     and not any(line.startswith("waypoint") for line in lines), repr(lines[-3:]))
        finally:
            hs.stop(proc)
            sock.close()
    print("host-plan-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
