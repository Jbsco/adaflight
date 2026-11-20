#!/usr/bin/env python3
"""Checks a build of the host image without the compass over its UART1 TCP port: peripherals prints no compass line
for a configured compass, its settings have no compass setting, and its resource command neither lists nor
takes a compass pin; MSP answers the compass configuration write and calibration as unknown, and its sensor
alignment and sensor configuration writes pass over compass fields, and with the simulator's link it offers no
MAG mode.

usage: host-compass-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "compassoff.bin"))
        try:
            hs.time.sleep(2.5)
            hs.check("compass configuration write is refused as unknown there", hs.msp(sock, 224, bytes(2)) is None)
            hs.check("compass calibration is refused as unknown there", hs.msp(sock, 206) is None)
            # A build with the compass refuses an alignment or a hardware value outside its setting's range.
            align = hs.msp(sock, 126) or bytes(10)
            hs.check("sensor alignment write passes over the compass alignment there",
                     hs.msp(sock, 220, align[:2] + bytes([200]) + align[3:5]) is not None)
            sensors = hs.msp(sock, 96) or bytes(3)
            hs.check("sensor configuration write passes over the compass hardware there",
                     hs.msp(sock, 97, sensors[:2] + bytes([200]) + sensors[3:]) is not None)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            # A build with the compass prints a configured one that it did not detect.
            hs.cli(sock, "set mag_hardware = HMC5883")
            text = hs.cli(sock, "peripherals")
            hs.check("peripherals prints no compass line there",
                     "peripherals" in text and "UNKNOWN COMMAND" not in text and "mag:" not in text, text[-200:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            gone = ("mag_", "align_mag", "blackbox_disable_mag")
            hs.check("dump has no compass settings there",
                     "acc_hardware" in names and not any(n.startswith(gone) for n in names),
                     repr([n for n in names if n.startswith(gone)]))
            text = hs.cli(sock, "get mag_declination")
            hs.check("get finds no compass setting there", "INVALID NAME" in text, text[-120:])
            hs.check("dump has no compass pins there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("COMPASS_" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource COMPASS_CS A01")
            hs.check("resource takes no compass pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
        # A build with the compass detects the simulator's and offers MAG mode.
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "compassoff.bin"),
                              {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        try:
            hs.time.sleep(4.0)
            names = hs.msp(sock, 116) or b""
            hs.check("box names offer no MAG mode with the simulator's link there",
                     b"ARM;" in names and b";MAG;" not in names, repr(names[:120]))
        finally:
            hs.stop(proc)
            sock.close()
    print("host-compass-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
