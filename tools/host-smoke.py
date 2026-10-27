#!/usr/bin/env python3
"""The host image's smoke check. Starts the image with an empty configuration store, asks it over MSP
on UART1 (TCP port 5761) for its API version, firmware variant and status, enters the command line and
reads the status and the task list, sets a setting, turns the OSD on with the MAX7456 as its display and
saves, which restarts the image, then reads the OSD flags, writes a font character and reads the setting
back from the stored configuration.

Usage: host-smoke.py <host image>
"""
import os
import socket
import subprocess
import sys
import tempfile
import time

PORT = 5761
failures = []


def check(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'} {name}{': ' + detail if detail and not ok else ''}")
    if not ok:
        failures.append(name)


def start(image, store):
    env = dict(os.environ, ADAFLIGHT_EEPROM=store)
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
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
            check("save restarts the image", proc.returncode == 0)
        finally:
            if proc.poll() is None:
                proc.kill()
            sock.close()
        check("configuration store written", os.path.exists(store) and os.path.getsize(store) == 8192)
        proc, sock = start(image, store)
        try:
            time.sleep(1.0)
            osd = msp(sock, 84)
            check("MSP OSD flags name the MAX7456 found", osd is not None and len(osd) > 0 and osd[0] & 0x31 == 0x31,
                  repr(osd[:1] if osd else osd))
            glyph = msp(sock, 87, bytes([0x41, 0x00]) + bytes(range(64)))
            check("MSP font character written", glyph == b"", repr(glyph))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "get gyro_lpf1_static_hz")
            check("setting kept across the restart", "gyro_lpf1_static_hz = 321" in text, text[-160:])
            text = cli(sock, "status")
            check("status names the MAX7456 display", "OSD: MAX7456 (30 x 16)" in text,
                  text[text.find("OSD:"):][:40])
        finally:
            proc.kill()
            sock.close()
    print(f"host smoke: {'all checks passed' if not failures else str(len(failures)) + ' failed'}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
