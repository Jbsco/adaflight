#!/usr/bin/env python3
"""Checks a host image built for a board that names a gyro alignment, LUXF4OSD with its gyro turned half a turn
about yaw, over its UART1 TCP port: the readings of the MPU6000 model arrive turned by the board's alignment,
the sensor alignment reply reports it, and a fresh configuration has the board's gyro bus and pins.

usage: host-board-check.py <host image>"""
import importlib.util
import os
import struct
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
        began = hs.time.time()
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "board.bin"), {"ADAFLIGHT_GYRO_CHIP": "MPU6000"})
        try:
            hs.time.sleep(max(0.0, began + 4.0 - hs.time.time()))
            reply = hs.msp(sock, 102)
            still = struct.unpack("<9h", reply)[:3] if reply is not None and len(reply) == 18 else None
            hs.check("board alignment turns the model's acceleration half a turn about yaw",
                     still is not None and all(abs(a - b) <= 2 for a, b in zip(still, (-32, 64, 510))), repr(still))
            reply = hs.msp(sock, 108)
            tilt = struct.unpack("<3h", reply)[:2] if reply is not None and len(reply) == 6 else None
            hs.check("attitude reply shows that acceleration's tilt",
                     tilt is not None and all(abs(a - b) <= 4 for a, b in zip(tilt, (72, 36))), repr(tilt))
            reply = hs.msp(sock, 126)
            hs.check("sensor alignment reply reports the board's gyro alignment",
                     reply is not None and len(reply) >= 2 and reply[0] == 3 and reply[1] == 3,
                     repr(reply[:5] if reply else reply))
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            text = hs.cli(sock, "get gyro_1")
            hs.check("fresh configuration has the board's gyro bus",
                     "gyro_1_bustype = SPI" in text and "gyro_1_spibus = 1" in text, text[-200:])
            text = hs.cli(sock, "resource")
            hs.check("resource lists the board's gyro pins",
                     "resource GYRO_EXTI 1 C04" in text and "resource GYRO_CS 1 A04" in text, text[-300:])
            hs.check("resource lists the board's PPM pin and its first four PWM input pins alone",
                     "resource PPM 1 B14" in text and "resource PWM 1 B14" in text and "resource PWM 2 B15" in text
                     and "resource PWM 3 C06" in text and "resource PWM 4 C07" in text
                     and "resource PWM 5 C08" not in text and "resource PWM 6 C09" not in text, text[-600:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-board-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
