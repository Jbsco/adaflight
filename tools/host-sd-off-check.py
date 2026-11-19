#!/usr/bin/env python3
"""Checks a build of the host image without the SD card over its UART1 TCP port: the command line knows no sd_info
command and its help lists none, status prints no SD card line, its settings have no SD card setting, and its
resource command neither lists nor takes an SD card pin.

usage: host-sd-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "sdoff.bin"))
        try:
            hs.time.sleep(2.5)
            kept = hs.msp2(sock, 0x3010, b"motor_pwm_protocol")
            hs.check("setting outside the SD card reads by name over MSP there",
                     kept is not None and kept.startswith(b"motor_pwm_protocol = "), repr(kept))
            hs.check("SD card setting has no name over MSP there", hs.msp2(sock, 0x3010, b"sdcard_mode") is None)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            text = hs.cli(sock, "sd_info")
            hs.check("build without the SD card knows no sd_info command", "UNKNOWN COMMAND" in text, text[-120:])
            text = hs.cli(sock, "help sd_info")
            hs.check("help lists no sd_info command there", "NO MATCHES" in text, text[-120:])
            text = hs.cli(sock, "status")
            hs.check("status prints no SD card line there", "CPU:" in text and "SD-CARD" not in text, text[-200:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            hs.check("dump has no SD card settings there",
                     "motor_pwm_protocol" in names and not any(n.startswith("sdcard_") for n in names),
                     repr([n for n in names if n.startswith("sdcard_")]))
            hs.check("dump has no SD card pins there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("SDCARD" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "get sdcard_mode")
            hs.check("get finds no SD card setting there", "INVALID NAME" in text, text[-120:])
            text = hs.cli(sock, "resource SDCARD_DETECT A01")
            hs.check("resource takes no SD card pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-sd-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
