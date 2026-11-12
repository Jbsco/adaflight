#!/usr/bin/env python3
"""Checks a wing build of the host image without the flight plan over its UART1 TCP port: the MSP box ids offer
launch and leave out launch control, the flight plan's boxes and the altitude and position holds, the build options
list the wing, and the command line has the wing's launch settings and TPA limits without the multirotor rescue
settings.

usage: host-wing-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "wing.bin"))
        try:
            hs.time.sleep(2.5)
            ids = (hs.msp(sock, 119) or b"") + (hs.msp(sock, 119, bytes([1])) or b"")
            hs.check("wing box ids leave out launch control and the flight plan's boxes",
                     len(ids) > 20 and 49 not in ids and 56 not in ids and 57 not in ids, repr(list(ids)))
            hs.check("wing box ids offer launch", 58 in ids, repr(list(ids)))
            hs.check("wing box ids leave out altitude and position hold", 3 not in ids and 11 not in ids,
                     repr(list(ids)))
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            text = hs.cli(sock, "options")
            hs.check("wing build options list the wing", 16424 in {int(w) for w in text.split() if w.isdigit()},
                     text[-160:])
            text = hs.cli(sock, "get launch_throttle")
            hs.check("wing command line lists launch settings", "launch_throttle = 80" in text, text[-120:])
            text = hs.cli(sock, "get gps_rescue_return_alt")
            hs.check("wing command line leaves out multirotor rescue settings", "INVALID NAME" in text, text[-120:])
            text = hs.cli(sock, "get osd_wp")
            hs.check("wing build without the flight plan lists no waypoint element position", "INVALID NAME" in text,
                     text[-120:])
            text = hs.cli(sock, "set tpa_low_rate = -128")
            hs.check("wing command line takes wing TPA limits", "tpa_low_rate set to -128" in text, text[-120:])
            text = hs.cli(sock, "status")
            hs.check("wing status answers", "System Uptime" in text or "MCU" in text, text[:160])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-wing-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
