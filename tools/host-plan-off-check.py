#!/usr/bin/env python3
"""Checks a multirotor build of the host image without the flight plan over its UART1 TCP port: the MSP box ids
leave out the autopilot and the waypoint capture and keep the holds, the build options leave the flight plan out,
the command line knows no waypoint command in its help and dumps, and a failsafe with the GPS rescue procedure flies
the rescue flight mode.

usage: host-plan-off-check.py <host image>"""
import importlib.util
import os
import socket
import struct
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("host_smoke", os.path.join(HERE, "host-smoke.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)


# GPS rescue as the failsafe procedure in a build without rescue plans: with the stick packets gone the rescue
# mode comes on without the failsafe mode, outlasts the landing time, stays on when the packets return with
# centred sticks, and ends at a stick movement.
def rescue_failsafe_checks(image, work):
    store = os.path.join(work, "rescuefs.bin")
    sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
    proc, sock = hs.start(image, store, extra=sim_link)
    try:
        time.sleep(2.5)
        sock.sendall(b"#")
        hs.read_all(sock, 0.8)
        for line in ("feature -RX_SERIAL", "feature RX_UDP", "set motor_pwm_protocol = PWM",
                     "aux 0 0 0 1700 2100 0 0", "feature GPS", "set gps_provider = VIRTUAL",
                     "set altitude_source = BARO_ONLY", "set failsafe_landing_time = 3"):
            hs.cli(sock, line)
        text = hs.cli(sock, "set failsafe_procedure = GPS-RESCUE")
        hs.check("GPS rescue set as the failsafe procedure", "failsafe_procedure set to GPS-RESCUE" in text,
              text[-120:])
        hs.cli(sock, "save", wait=2.0)
        proc.wait(timeout=10)
    finally:
        hs.stop(proc)
        sock.close()
    proc, sock = hs.start(image, store, extra=sim_link)
    done = threading.Event()
    with_sticks = threading.Event()
    with_sticks.set()
    pulses = [1500, 1500, 1000, 1500] + [1000] * 12
    place = [-105.25, 40.0, 1600.0]

    def feed():
        out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        tick = 0
        while not done.is_set():
            out.sendto(struct.pack("<18d", tick * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0,
                                   0.0, 0.0, place[0], place[1], place[2], 0.0), ("127.0.0.1", 9003))
            if tick % 2 == 0 and with_sticks.is_set():
                out.sendto(struct.pack("<d16H", tick * 0.01, *pulses), ("127.0.0.1", 9004))
            tick += 1
            time.sleep(0.01)
        out.close()

    def modes():
        status = hs.msp(sock, 150)
        if status is None or len(status) < 16 + status[15]:
            return None
        return int.from_bytes(status[6:10], "little") | int.from_bytes(status[16:16 + status[15]], "little") << 32
    try:
        time.sleep(2.5)
        threading.Thread(target=feed, daemon=True).start()
        time.sleep(7.0)
        hs.msp(sock, 205)
        time.sleep(4.0)
        ids = list(hs.msp(sock, 119) or b"")
        arm, failsafe, rescue = (1 << ids.index(i) if i in ids else 0 for i in (0, 27, 46))
        hs.check("boxes of arming, failsafe and GPS rescue exist", arm and failsafe and rescue, repr(ids))
        pulses[4] = 1800
        armed, value = hs.until(modes, lambda m: m is not None and m & arm, wait=8.0)
        hs.check("craft arms for the rescue failsafe", armed, repr(value))
        # Raised throttle, then a place 111 m from home and 30 m up, for a rescue that has somewhere to go.
        pulses[2] = 1400
        place[1] += 0.001
        place[2] += 30.0
        time.sleep(4.0)
        with_sticks.clear()
        time.sleep(2.5)
        value = modes()
        hs.check("lost link turns the rescue mode on without the failsafe mode",
              value is not None and value & rescue and not value & failsafe and value & arm, repr(value))
        time.sleep(4.5)
        value = modes()
        hs.check("rescue outlasts the failsafe's landing time", value is not None and value & rescue and value & arm,
              repr(value))
        with_sticks.set()
        time.sleep(2.0)
        value = modes()
        hs.check("link's return with centred sticks leaves the rescue on", value is not None and value & rescue,
              repr(value))
        pulses[0] = 1800
        time.sleep(1.5)
        value = modes()
        hs.check("stick movement ends the rescue", value is not None and not value & rescue and value & arm,
              repr(value))
        pulses[0] = 1500
        pulses[4] = 1000
        time.sleep(1.0)
    finally:
        done.set()
        hs.stop(proc)
        sock.close()


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
        rescue_failsafe_checks(sys.argv[1], work)
    print("host-plan-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())
