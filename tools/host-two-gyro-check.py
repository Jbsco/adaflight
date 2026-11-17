#!/usr/bin/env python3
"""Checks a host image built for a board with two gyros, IFLIGHT_F405_TWING with its second gyro a quarter turn
from its first, over its UART1 TCP port and the host's ICM-20689 model, which answers behind both select pins.
The second chip reads twice the first's rates and twice its first acceleration, so each reading shows its chip.
A fresh configuration runs both gyros, and their aligned readings' mean is the rate. With the second gyro
enabled alone, its own rates and acceleration arrive turned by its alignment, which the sensor alignment reply
reports. With the first alone they arrive as that gyro reads them.

usage: host-two-gyro-check.py <host image>"""
import importlib.util
import os
import struct
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("host_smoke", os.path.join(HERE, "host-smoke.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)
CHIP = {"ADAFLIGHT_GYRO_CHIP": "ICM20689"}


def near(values, wanted, margin=2):
    return values is not None and all(abs(a - b) <= margin for a, b in zip(values, wanted))


def readings(image, store):
    """One start: the raw IMU reply after the model's rate step, the sensor alignment reply, the gyro sensor
    reply, the status text and the enabled mask's settings."""
    began = hs.time.time()
    proc, sock = hs.start(image, store, CHIP)
    try:
        hs.time.sleep(max(0.0, began + 10.5 - hs.time.time()))
        reply = hs.msp(sock, 102)
        imu = struct.unpack("<9h", reply)[:6] if reply is not None and len(reply) == 18 else None
        alignment = hs.msp(sock, 126)
        active = hs.msp2(sock, 0x300D)
        sock.sendall(b"#")
        hs.read_all(sock, 0.8)
        status = hs.cli(sock, "status")
        mask = hs.cli(sock, "get gyro_enabled_bitmask")
    finally:
        hs.stop(proc)
        sock.close()
    return imu, alignment, active, status, mask


def save(image, store, line):
    proc, sock = hs.start(image, store, CHIP)
    try:
        hs.time.sleep(2.5)
        sock.sendall(b"#")
        hs.read_all(sock, 0.8)
        hs.cli(sock, line)
        hs.cli(sock, "save", wait=2.0)
        proc.wait(timeout=10)
    finally:
        hs.stop(proc)
        sock.close()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    image = sys.argv[1]
    with tempfile.TemporaryDirectory() as work:
        store = os.path.join(work, "two-gyro.bin")
        imu, alignment, active, status, mask = readings(image, store)
        hs.check("fresh configuration finds and enables both gyros",
                 "GYRO: (1) ICM20689 enabled, (2) ICM20689 enabled" in status and "gyro_enabled_bitmask = 3" in mask,
                 repr((status[:300], mask[-80:])))
        hs.check("gyro sensor reply lists two gyros with their hardware",
                 active is not None and len(active) == 3 and active[0] == 2 and active[1] == active[2] != 0,
                 repr(active))
        hs.check("rates with both gyros are the mean of their aligned readings",
                 imu is not None and near(imu[3:6], (410, 0, -738)), repr(imu))
        hs.check("acceleration with both gyros follows the first gyro",
                 imu is not None and near(imu[:3], (32, -64, 510)), repr(imu))
        hs.check("sensor alignment reply reports the first gyro with both detected and enabled",
                 alignment is not None and len(alignment) >= 5 and list(alignment[:2]) == [1, 1]
                 and list(alignment[3:5]) == [3, 3], repr(alignment[:5] if alignment else alignment))
        save(image, store, "set gyro_enabled_bitmask = 2")
        imu, alignment, active, status, mask = readings(image, store)
        hs.check("second gyro alone is the one enabled",
                 "GYRO: (1) ICM20689, (2) ICM20689 enabled" in status and "gyro_enabled_bitmask = 2" in mask,
                 repr((status[:300], mask[-80:])))
        hs.check("second gyro's own rates arrive turned by its alignment",
                 imu is not None and near(imu[3:6], (656, -328, -984)), repr(imu))
        hs.check("second gyro's own acceleration arrives when it is the first enabled",
                 imu is not None and near(imu[:3], (-64, -64, 510)), repr(imu))
        hs.check("sensor alignment reply reports the second gyro's alignment",
                 alignment is not None and len(alignment) >= 5 and list(alignment[:2]) == [2, 2]
                 and list(alignment[3:5]) == [3, 2], repr(alignment[:5] if alignment else alignment))
        save(image, store, "set gyro_enabled_bitmask = 1")
        imu, alignment, active, status, mask = readings(image, store)
        hs.check("first gyro alone is the one enabled",
                 "GYRO: (1) ICM20689 enabled, (2) ICM20689" in status and "(2) ICM20689 enabled" not in status
                 and "gyro_enabled_bitmask = 1" in mask, repr((status[:300], mask[-80:])))
        hs.check("rates of the first gyro alone arrive as it reads them",
                 imu is not None and near(imu[3:6], (164, 328, -492)) and near(imu[:3], (32, -64, 510)), repr(imu))
    print("host-two-gyro-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
