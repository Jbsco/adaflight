#!/usr/bin/env python3
"""Checks a build of the host image without the flight log over its UART1 TCP port: the command line knows no msc
command and its help lists none, its settings have no flight log, SD card, flash or mass storage setting, its
resource command neither lists nor takes the mass storage pin, MSP reports no flight log, answers its write and the
flash erase as unknown, and offers neither flight log mode.

usage: host-blackbox-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "bboff.bin"))
        try:
            hs.time.sleep(2.5)
            kept = hs.msp2(sock, 0x3010, b"motor_pwm_protocol")
            hs.check("setting outside the flight log reads by name over MSP there",
                     kept is not None and kept.startswith(b"motor_pwm_protocol = "), repr(kept))
            hs.check("flight log setting has no name over MSP there", hs.msp2(sock, 0x3010, b"blackbox_device") is None)
            reply = hs.msp(sock, 80)
            hs.check("flight log reply reports none there", reply == bytes(11), repr(reply))
            # The write range-checks its fields: a build with the flight log takes its own reply back.
            hs.check("flight log write is refused as unknown there",
                     hs.msp(sock, 81, (reply or bytes(11))[1:11]) is None)
            hs.check("flash erase is refused as unknown there", hs.msp(sock, 72) is None)
            names = hs.msp(sock, 116) or b""
            hs.check("box names offer no flight log mode there",
                     b"ARM;" in names and b"BLACKBOX" not in names, repr(names[:80]))
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            text = hs.cli(sock, "msc")
            hs.check("build without the flight log knows no msc command", "UNKNOWN COMMAND" in text, text[-120:])
            text = hs.cli(sock, "help msc")
            hs.check("help lists no msc command there", "NO MATCHES" in text, text[-120:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            gone = ("blackbox_", "sdcard_", "osd_log_status_pos", "usb_msc_pin_pullup", "flash_spi_bus")
            hs.check("dump has no flight log, storage or mass storage settings there",
                     "motor_pwm_protocol" in names and not any(n.startswith(gone) for n in names),
                     repr([n for n in names if n.startswith(gone)]))
            text = hs.cli(sock, "get blackbox_device")
            hs.check("get finds no flight log setting there", "INVALID NAME" in text, text[-120:])
            hs.check("dump has no mass storage pin there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("USB_MSC_PIN" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource USB_MSC_PIN A01")
            hs.check("resource takes no mass storage pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-blackbox-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
