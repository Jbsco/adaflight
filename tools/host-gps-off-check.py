#!/usr/bin/env python3
"""Checks a build of the host image without the GPS over its UART1 TCP port: the command line knows no
gpspassthrough command and its help lists none, status and env print no GPS lines, its settings have no GPS,
rescue or hold setting, MSP has no GPS reply, and MSP refuses GPS writes as unknown.

usage: host-gps-off-check.py <host image>"""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("host_smoke", os.path.join(HERE, "host-smoke.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)

# Settings that only a build with the GPS lists, one from each group.
GPS_SETTINGS = ("gps_provider", "gps_rescue_min_sats", "alt_hold_deadband", "pos_hold_deadband", "frsky_gps_format")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    with tempfile.TemporaryDirectory() as work:
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "gpsoff.bin"))
        try:
            hs.time.sleep(2.5)
            kept = hs.msp2(sock, 0x3010, b"motor_pwm_protocol")
            hs.check("setting outside the GPS reads by name over MSP there",
                     kept is not None and kept.startswith(b"motor_pwm_protocol = "), repr(kept))
            hs.check("GPS setting has no name over MSP there", hs.msp2(sock, 0x3010, b"gps_provider") is None)
            hs.check("motor reply still answers there", hs.msp(sock, 104) is not None)
            for command in (106, 107, 132, 135, 136, 164):
                hs.check(f"MSP {command} has no GPS reply there", hs.msp(sock, command) is None)
            # The rescue write range-checks its fields: a build with the GPS takes its own rescue reply back.
            rescue = hs.msp(sock, 135) or bytes(19)
            for command, payload in ((201, bytes(14)), (223, bytes(5)), (225, rescue), (226, bytes(9))):
                hs.check(f"MSP {command} GPS write is refused as unknown there",
                         hs.msp(sock, command, payload) is None)
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
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            hs.check("dump has no GPS, rescue or hold settings there",
                     "motor_pwm_protocol" in names and not any(n in GPS_SETTINGS for n in names),
                     repr([n for n in names if n in GPS_SETTINGS]))
            text = hs.cli(sock, "get gps_provider")
            hs.check("get finds no GPS setting there", "INVALID NAME" in text, text[-120:])
            text = hs.cli(sock, "set gps_rescue_min_sats = 9")
            hs.check("set refuses a rescue setting there", "INVALID NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-gps-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
