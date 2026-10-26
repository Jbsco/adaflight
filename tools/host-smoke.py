#!/usr/bin/env python3
"""The host image's smoke check. Starts the image with an empty configuration store, asks it over MSP
on UART1 (TCP port 5761) for its API version, firmware variant and status, enters the command line and
reads the status and the task list, sets a setting, turns the OSD on with the MAX7456 as its display and
saves, which restarts the image, then feeds CRSF frames on UART3's port, reads the OSD flags, writes a
font character, reads the setting back from the stored configuration, finds the channels in the RC reply
and the link in the arming flags, finds the craft name on the OSD's screen, then opens the menu with the
stick gesture and finds it on the screen with its arming hold.

Usage: host-smoke.py <host image>
"""
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time

PORT = 5761
RX_PORT = 5763


def crc8(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ 0xD5) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc


def crsf_frame(channels):
    """An RC channels frame: sixteen 11-bit values, 172 to 1811, low bits first."""
    bits = 0
    for n, value in enumerate(channels):
        bits |= (value & 0x7FF) << (11 * n)
    payload = bits.to_bytes(22, "little")
    return bytes([0xC8, 24, 0x16]) + payload + bytes([crc8(bytes([0x16]) + payload)])


class Receiver(threading.Thread):
    """Sends CRSF frames on UART3's port at 50 Hz: roll, pitch and yaw at mid, throttle low."""

    def __init__(self):
        super().__init__(daemon=True)
        self.channels = [992, 992, 172, 992] + [992] * 12
        self.stop = threading.Event()

    def set(self, roll, pitch, throttle, yaw):
        self.channels = [roll, pitch, throttle, yaw] + [992] * 12

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
            except OSError:
                time.sleep(0.1)
        while sock is not None and not self.stop.is_set():
            try:
                sock.sendall(crsf_frame(self.channels))
            except OSError:
                break
            time.sleep(0.02)
        if sock is not None:
            sock.close()
failures = []


def check(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'} {name}{': ' + detail if detail and not ok else ''}")
    if not ok:
        failures.append(name)


def start(image, store):
    env = dict(os.environ, ADAFLIGHT_EEPROM=store, ADAFLIGHT_OSD_SCREEN=store + ".osd.txt")
    proc = subprocess.Popen([image], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.time() + 15
    while time.time() < deadline:
        try:
            sock = socket.create_connection(("127.0.0.1", PORT), timeout=1)
            sock.settimeout(0.3)
            return proc, sock
        except OSError:
            if proc.poll() is not None:
                break
            time.sleep(0.1)
    proc.kill()
    raise SystemExit("host: the image did not open its UART1 port")


def read_all(sock, wait):
    data = b""
    deadline = time.time() + wait
    while time.time() < deadline:
        try:
            chunk = sock.recv(8192)
        except socket.timeout:
            continue
        except OSError:
            break
        if not chunk:
            break
        data += chunk
    return data


def msp(sock, cmd, payload=b""):
    check = len(payload) ^ cmd
    for b in payload:
        check ^= b
    sock.sendall(b"$M<" + bytes([len(payload), cmd]) + payload + bytes([check]))
    data = read_all(sock, 0.5)
    if len(data) < 6 or data[:3] != b"$M>":
        return None
    if data[3] == 255:
        return data[7:7 + (data[5] | data[6] << 8)]
    return data[5:5 + data[3]]


def cli(sock, line, wait=0.8):
    sock.sendall(line.encode() + b"\r\n")
    return read_all(sock, wait).decode(errors="replace")


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    image = os.path.abspath(sys.argv[1])
    with tempfile.TemporaryDirectory() as work:
        store = os.path.join(work, "eeprom.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(1.0)
            api = msp(sock, 1)
            check("MSP API version 1.x", api is not None and len(api) == 3 and api[1] == 1)
            variant = msp(sock, 2)
            check("MSP firmware variant ADFL", variant == b"ADFL", repr(variant))
            status = msp(sock, 101)
            check("MSP status with the gyro", status is not None and len(status) > 5
                  and (status[4] | status[5] << 8) & 0x20 != 0)
            sock.sendall(b"#")
            banner = read_all(sock, 0.8).decode(errors="replace")
            check("command line entered", "Entering CLI Mode" in banner, banner[:80])
            text = cli(sock, "status")
            check("status names the gyro", "GYRO:" in text)
            check("status holds arming in the command line", "CLI" in text.split("Arming disable flags:")[-1])
            text = cli(sock, "tasks")
            check("tasks run the gyro and the PID loop", "GYRO" in text and "PID" in text)
            text = cli(sock, "set gyro_lpf1_static_hz = 321")
            check("set accepted", "gyro_lpf1_static_hz set to 321" in text, text[-120:])
            text = cli(sock, "feature OSD")
            check("OSD feature on", "Enabled" in text, text[-120:])
            text = cli(sock, "set osd_displayport_device = MAX7456")
            check("OSD display device set", "osd_displayport_device set to MAX7456" in text, text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("receiver port assigned", "rx_uart set to UART3" in text, text[-120:])
            cli(sock, "set craft_name = ADAHOST")
            text = cli(sock, "set osd_craft_name_pos = 2122")
            check("craft name element placed", "osd_craft_name_pos set to 2122" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
            check("save restarts the image", proc.returncode == 0)
        finally:
            if proc.poll() is None:
                proc.kill()
            sock.close()
        check("configuration store written", os.path.exists(store) and os.path.getsize(store) == 8192)
        proc, sock = start(image, store)
        receiver = Receiver()
        receiver.start()
        try:
            time.sleep(1.0)
            osd = msp(sock, 84)
            check("MSP OSD flags name the MAX7456 found", osd is not None and len(osd) > 0 and osd[0] & 0x31 == 0x31,
                  repr(osd[:1] if osd else osd))
            glyph = msp(sock, 87, bytes([0x41, 0x00]) + bytes(range(64)))
            check("MSP font character written", glyph == b"", repr(glyph))
            time.sleep(2.5)
            rc = msp(sock, 105)
            values = [rc[i] | rc[i + 1] << 8 for i in range(0, 8, 2)] if rc and len(rc) >= 8 else []
            check("receiver channels reach the MSP RC reply",
                  len(values) == 4 and all(abs(v - 1500) <= 2 for v in values[:3]) and values[3] <= 1000, repr(values))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "get gyro_lpf1_static_hz")
            check("setting kept across the restart", "gyro_lpf1_static_hz = 321" in text, text[-160:])
            text = cli(sock, "status")
            check("status names the MAX7456 display", "OSD: MAX7456 (30 x 16)" in text,
                  text[text.find("OSD:"):][:40])
            text = cli(sock, "status")
            flags = text.split("Arming disable flags:")[-1]
            check("receiver link clears the signal loss", "RXLOSS" not in flags and "CLI" in flags, flags.strip()[:80])
            time.sleep(5.0)
            try:
                with open(store + ".osd.txt") as f:
                    screen = f.read()
            except OSError:
                screen = ""
            check("OSD draws the craft name", "ADAHOST" in screen, repr(screen[:200]))
            receiver.set(992, 1811, 992, 172)
            time.sleep(1.0)
            receiver.set(992, 992, 172, 992)
            time.sleep(1.5)
            try:
                with open(store + ".osd.txt") as f:
                    screen = f.read()
            except OSError:
                screen = ""
            check("stick gesture opens the menu", "-- QUICK --" in screen or "-- MAIN --" in screen, repr(screen[:300]))
            text = cli(sock, "status")
            flags = text.split("Arming disable flags:")[-1]
            check("open menu holds arming", "CMS" in flags, flags.strip()[:80])
        finally:
            receiver.stop.set()
            proc.kill()
            sock.close()
    print(f"host smoke: {'all checks passed' if not failures else str(len(failures)) + ' failed'}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
