#!/usr/bin/env python3
"""The host image's smoke check. Starts the image with an empty configuration store, asks it over MSP
on UART1 (TCP port 5761) for its API version, firmware variant and status, enters the command line and
reads the status and the task list, sets a setting, turns the OSD on with the MAX7456 as its display and
saves, which restarts the image, then feeds CRSF frames on UART3's port and NMEA sentences on UART4's,
reads the OSD flags, writes a font character, reads the setting back from the stored configuration,
finds the channels in the RC reply, the fix in the raw GPS reply, the link and the GPS in the status,
finds the craft name on the OSD's screen, then opens the menu with the stick gesture and finds it on
the screen with its arming hold.

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
VCP_PORT = 5780
RX_PORT = 5763
GPS_PORT = 5764
LOG_PORT = 5766


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


def nmea(body):
    check = 0
    for byte in body.encode():
        check ^= byte
    return f"${body}*{check:02X}\r\n".encode()


class GPS(threading.Thread):
    """Sends a fix on UART4's port at 5 Hz: ten satellites at 48.1173 north, 11.5167 east, 545 m."""

    def __init__(self):
        super().__init__(daemon=True)
        self.stop = threading.Event()

    def frames(self, tick):
        """The fix at a time that advances a fifth of a second per frame, so each solution is new."""
        clock = f"{12 + tick // 18000:02d}{(tick // 300) % 60:02d}{(tick // 5) % 60:02d}.{(tick % 5) * 20:02d}"
        return nmea(f"GPGGA,{clock},4807.03800,N,01131.00000,E,1,10,0.9,545.4,M,46.9,M,,") + nmea(
            f"GPRMC,{clock},A,4807.03800,N,01131.00000,E,022.4,084.4,230394,003.1,W")

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
            except OSError:
                time.sleep(0.1)
        tick = 0
        while sock is not None and not self.stop.is_set():
            try:
                sock.sendall(self.frames(tick))
            except OSError:
                break
            tick += 1
            time.sleep(0.2)
        if sock is not None:
            sock.close()


class Receiver(threading.Thread):
    """Sends CRSF frames on UART3's port at 50 Hz: roll, pitch and yaw at mid, throttle low."""

    def __init__(self):
        super().__init__(daemon=True)
        self.channels = [992, 992, 172, 992] + [992] * 12
        self.stop = threading.Event()
        self.frames = {}
        self.pending = b""

    def count_frames(self, data):
        """Counts the telemetry frames by type in the bytes read back from the port."""
        self.pending += data
        while len(self.pending) >= 2:
            length = self.pending[1]
            if length < 2 or length > 62:
                self.pending = self.pending[1:]
                continue
            if len(self.pending) < length + 2:
                break
            frame = self.pending[:length + 2]
            self.pending = self.pending[length + 2:]
            if crc8(frame[2:-1]) == frame[-1]:
                self.frames[frame[2]] = self.frames.get(frame[2], 0) + 1

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
        if sock is not None:
            sock.settimeout(0.005)
        while sock is not None and not self.stop.is_set():
            try:
                sock.sendall(crsf_frame(self.channels))
            except OSError:
                break
            try:
                self.count_frames(sock.recv(4096))
            except socket.timeout:
                pass
            except OSError:
                break
            time.sleep(0.02)
        if sock is not None:
            sock.close()
def sa_crc(data):
    """The SmartAudio check byte: CRC-8 with the polynomial 0xD5."""
    crc = 0
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = ((crc << 1) ^ 0xD5) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc


class SmartAudio(threading.Thread):
    """A SmartAudio V2 transmitter on UART6's port: it answers the settings request with channel A1 at the
    first power level, the pit mode frequency request with 5584 MHz, and every other command with its
    value, and records each command with its value."""

    def __init__(self):
        super().__init__(daemon=True)
        self.stop = threading.Event()
        self.commands = []
        self.pending = b""

    def take(self, sock):
        while True:
            start = self.pending.find(b"\xaa\x55")
            if start < 0 or len(self.pending) < start + 4:
                return
            length = self.pending[start + 3]
            if len(self.pending) < start + 5 + length:
                return
            code = self.pending[start + 2] >> 1
            payload = self.pending[start + 4:start + 4 + length]
            self.pending = self.pending[start + 5 + length:]
            value = int.from_bytes(payload, "big") if payload else 0
            self.commands.append((code, value))
            if code == 1:
                body = bytes([0x09, 0x05, 0, 0, 0, 0x16, 0xE9])
            elif code == 4:
                freq = (5584 | 0x4000) if value & 0x4000 else value
                body = bytes([0x04, 0x03, freq >> 8, freq & 0xFF, 0x01])
            else:
                body = bytes([code, 0x03, payload[0] if payload else 0, 0x01])
            sock.sendall(b"\xaa\x55" + body + bytes([sa_crc(body)]))

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", LOG_PORT), timeout=1)
            except OSError:
                time.sleep(0.1)
        if sock is not None:
            sock.settimeout(0.05)
        while sock is not None and not self.stop.is_set():
            try:
                data = sock.recv(4096)
            except socket.timeout:
                continue
            except OSError:
                break
            if not data:
                break
            self.pending += data
            try:
                self.take(sock)
            except OSError:
                break
        if sock is not None:
            sock.close()


failures = []


def check(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'} {name}{': ' + detail if detail and not ok else ''}")
    if not ok:
        failures.append(name)


def kiss_crc(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ 0x07) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc


class ESC(threading.Thread):
    """The ESCs' telemetry line on UART6's port: a ten byte frame every 30 ms with 42 degrees, 16.10 V,
    2.50 A, 77 mAh and 345 hundred electrical revolutions per minute."""

    FRAME = bytes([42]) + (1610).to_bytes(2, "big") + (250).to_bytes(2, "big") + (77).to_bytes(2, "big") \
        + (345).to_bytes(2, "big")

    def __init__(self):
        super().__init__(daemon=True)
        self.stop = threading.Event()

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", LOG_PORT), timeout=1)
            except OSError:
                time.sleep(0.1)
        if sock is None:
            return
        frame = self.FRAME + bytes([kiss_crc(self.FRAME)])
        while not self.stop.is_set():
            try:
                sock.sendall(frame)
            except OSError:
                break
            time.sleep(0.03)
        sock.close()


class ESCInfo(threading.Thread):
    """The ESC on UART6's port that answers the DShot ESC information command, a frame of 6 to motor 0 in the
    image's DShot log, with a KISS version 2 information frame: serial number 01 to 0C, firmware 1.31b, a
    KISS24A, normal rotation and 3D off."""

    FRAME = bytes(range(1, 13)) + bytes([255, 131, ord("b"), 3, 0, 0, 0, 0])

    def __init__(self, log):
        super().__init__(daemon=True)
        self.stop = threading.Event()
        self.log = log
        self.answers = 0

    def requests(self):
        try:
            with open(self.log) as f:
                return f.read().split().count("0,6,1")
        except OSError:
            return 0

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", LOG_PORT), timeout=1)
            except OSError:
                time.sleep(0.1)
        if sock is None:
            return
        frame = self.FRAME + bytes([kiss_crc(self.FRAME)])
        seen = self.requests()
        while not self.stop.is_set():
            now = self.requests()
            if now > seen:
                seen = now
                try:
                    sock.sendall(frame)
                except OSError:
                    break
                self.answers += 1
            time.sleep(0.0005)
        sock.close()


def fat16_image(path, sectors):
    """A card image: a partition table, then a FAT16 volume of 8-sector clusters from sector 8."""
    start = 8
    volume = sectors - start
    fat_sectors = (volume // 8 * 2 + 511) // 512
    mbr = bytearray(512)
    mbr[446:462] = bytes([0x00, 0x01, 0x01, 0x00, 0x06, 0xFE, 0xFF, 0xFF]) + start.to_bytes(4, "little") \
        + volume.to_bytes(4, "little")
    mbr[510:512] = b"\x55\xAA"
    boot = bytearray(512)
    boot[0:3] = b"\xEB\x3C\x90"
    boot[3:11] = b"ADAFLGHT"
    boot[11:13] = (512).to_bytes(2, "little")
    boot[13] = 8
    boot[14:16] = (1).to_bytes(2, "little")
    boot[16] = 2
    boot[17:19] = (512).to_bytes(2, "little")
    boot[19:21] = volume.to_bytes(2, "little")
    boot[21] = 0xF8
    boot[22:24] = fat_sectors.to_bytes(2, "little")
    boot[24:26] = (63).to_bytes(2, "little")
    boot[26:28] = (255).to_bytes(2, "little")
    boot[28:32] = start.to_bytes(4, "little")
    boot[36] = 0x80
    boot[38] = 0x29
    boot[43:54] = b"ADAFLIGHT  "
    boot[54:62] = b"FAT16   "
    boot[510:512] = b"\x55\xAA"
    fat = bytearray(fat_sectors * 512)
    fat[0:4] = b"\xF8\xFF\xFF\xFF"
    with open(path, "wb") as f:
        f.write(mbr)
        f.write(bytes(512 * (start - 1)))
        f.write(boot)
        f.write(fat)
        f.write(fat)
        f.truncate(sectors * 512)


def fat16_find(data, start, length, name):
    """The directory entry of an 8.3 name in a directory's bytes."""
    for at in range(start, start + length, 32):
        entry = data[at:at + 32]
        if entry[0] == 0:
            return None
        if entry[0:11] == name and entry[11] & 0x08 == 0:
            return entry
    return None


def fat16_log(path):
    """The LOGS directory's first log file's first cluster, from the card image, or the reason there is none."""
    with open(path, "rb") as f:
        data = f.read()
    start = int.from_bytes(data[454:458], "little") * 512
    reserved = int.from_bytes(data[start + 14:start + 16], "little")
    fats = data[start + 16]
    fat_sectors = int.from_bytes(data[start + 22:start + 24], "little")
    root_entries = int.from_bytes(data[start + 17:start + 19], "little")
    cluster_bytes = data[start + 13] * 512
    root = start + (reserved + fats * fat_sectors) * 512
    clusters = root + root_entries * 32
    logs = fat16_find(data, root, root_entries * 32, b"LOGS       ")
    if logs is None or logs[11] & 0x10 == 0:
        return None, "no LOGS directory"
    first = int.from_bytes(logs[26:28], "little")
    at = clusters + (first - 2) * cluster_bytes
    log = fat16_find(data, at, cluster_bytes, b"LOG00001BFL")
    if log is None:
        return None, "no LOG00001.BFL in LOGS"
    first = int.from_bytes(log[26:28], "little")
    if first < 2:
        return None, "log file without a cluster"
    at = clusters + (first - 2) * cluster_bytes
    return data[at:at + cluster_bytes], ""


def stop(proc):
    """The image killed, and its exit waited for, so the next start cannot reach its ports."""
    if proc.poll() is None:
        proc.kill()
    proc.wait(timeout=10)


def start(image, store, extra=None):
    env = dict(os.environ, ADAFLIGHT_EEPROM=store, ADAFLIGHT_OSD_SCREEN=store + ".osd.txt",
               ADAFLIGHT_DSHOT_LOG=store + ".dshot.txt", **(extra or {}))
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


def msp2(sock, cmd, payload=b""):
    body = bytes([0]) + cmd.to_bytes(2, "little") + len(payload).to_bytes(2, "little") + payload
    sock.sendall(b"$X<" + body + bytes([crc8(body)]))
    data = read_all(sock, 0.5)
    if len(data) < 9 or data[:3] != b"$X>":
        return None
    return data[8:8 + (data[6] | data[7] << 8)]


def dshot_frames(store, wait):
    """The DShot command frames the image logged, as (motor, value, request) lines, once they stop
    changing or the wait runs out."""
    lines = []
    deadline = time.time() + wait
    while time.time() < deadline:
        time.sleep(0.3)
        try:
            with open(store + ".dshot.txt") as log:
                now = [tuple(int(f) for f in line.split(",")) for line in log.read().split()]
        except OSError:
            now = []
        if now and now == lines:
            break
        lines = now
    return lines


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
            time.sleep(2.5)
            api = msp(sock, 1)
            check("MSP API version 1.x", api is not None and len(api) == 3 and api[1] == 1)
            variant = msp(sock, 2)
            check("MSP firmware variant ADFL", variant == b"ADFL", repr(variant))
            status = msp(sock, 101)
            vcp = socket.create_connection(("127.0.0.1", VCP_PORT), timeout=1)
            vcp.settimeout(0.3)
            time.sleep(0.2)
            vcp_api = msp(vcp, 1)
            check("MSP over the USB serial port", vcp_api is not None and len(vcp_api) == 3 and vcp_api[1] == 1,
                  repr(vcp_api))
            vcp.close()
            check("MSP status with the gyro", status is not None and len(status) > 5
                  and (status[4] | status[5] << 8) & 0x20 != 0)
            motors = msp(sock, 131)
            check("MSP motor configuration counts the mixer's four motors", motors is not None and len(motors) >= 7
                  and motors[6] == 4, repr(motors))
            outputs = msp(sock, 104)
            check("MSP motor reply holds the DShot stop while disarmed",
                  outputs is not None and len(outputs) == 16 and outputs == (1000).to_bytes(2, "little") * 4 + bytes(8),
                  repr(outputs))
            ack = msp(sock, 214, b"".join(v.to_bytes(2, "little") for v in [1100, 1200, 1300, 1400] + [1000] * 4))
            check("MSP motor test write accepted", ack == b"", repr(ack))
            time.sleep(0.3)
            outputs = msp(sock, 104)
            values = [int.from_bytes(outputs[i:i + 2], "little") for i in range(0, 8, 2)] if outputs else []
            check("motor test values reach the motors while disarmed",
                  len(values) == 4 and all(abs(v - w) <= 1 for v, w in zip(values, [1100, 1200, 1300, 1400])),
                  repr(values))
            ack = msp(sock, 214, (1000).to_bytes(2, "little") * 8)
            check("motor test stopped", ack == b"", repr(ack))
            ack = msp2(sock, 0x3003, bytes([0, 255, 1, 1]))
            check("MSP DShot beacon queued", ack == b"", repr(ack))
            frames = dshot_frames(store, 5.0)
            check("beacon goes out once to each motor with a telemetry request",
                  sorted(frames) == [(m, 1, 1) for m in range(4)], repr(frames))
            sock.sendall(b"#")
            banner = read_all(sock, 0.8).decode(errors="replace")
            check("command line entered", "Entering CLI Mode" in banner, banner[:80])
            text = cli(sock, "status")
            check("status names the gyro", "GYRO:" in text)
            check("status holds arming in the command line", "CLI" in text.split("Arming disable flags:")[-1])
            text = cli(sock, "tasks")
            check("tasks run the gyro and the PID loop", "GYRO" in text and "PID" in text)
            text = cli(sock, "dshotprog 0 7")
            check("dshotprog sends its command", "Using output 0." in text and "Command Sent: 7" in text, text[-120:])
            frames = dshot_frames(store, 3.0)
            check("spin direction goes ten times to motor 0 alone", frames[4:] == [(0, 7, 1)] * 10, repr(frames[4:]))
            text = cli(sock, "set gyro_lpf1_static_hz = 321")
            check("set accepted", "gyro_lpf1_static_hz set to 321" in text, text[-120:])
            text = cli(sock, "feature OSD")
            check("OSD feature on", "Enabled" in text, text[-120:])
            text = cli(sock, "set osd_displayport_device = MAX7456")
            check("OSD display device set", "osd_displayport_device set to MAX7456" in text, text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("receiver port assigned", "rx_uart set to UART3" in text, text[-120:])
            text = cli(sock, "set gps_provider = NMEA")
            check("GPS provider set", "gps_provider set to NMEA" in text, text[-120:])
            text = cli(sock, "set gps_uart = UART4")
            check("GPS port assigned", "gps_uart set to UART4" in text, text[-120:])
            text = cli(sock, "feature GPS")
            check("GPS feature on", "Enabled GPS" in text, text[-120:])
            text = cli(sock, "set blackbox_device = SERIAL")
            check("flight log device set", "blackbox_device set to SERIAL" in text, text[-120:])
            text = cli(sock, "set blackbox_uart = UART6")
            check("flight log port assigned", "blackbox_uart set to UART6" in text, text[-120:])
            text = cli(sock, "set blackbox_mode = ALWAYS")
            check("flight log always on", "blackbox_mode set to ALWAYS" in text, text[-120:])
            cli(sock, "set craft_name = ADAHOST")
            text = cli(sock, "set osd_craft_name_pos = 2122")
            check("craft name element placed", "osd_craft_name_pos set to 2122" in text, text[-120:])
            text = cli(sock, "set osd_rtc_date_time_pos = 2177")
            check("clock element placed", "osd_rtc_date_time_pos set to 2177" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
            check("save restarts the image", proc.returncode == 0)
        finally:
            stop(proc)
            sock.close()
        check("configuration store written", os.path.exists(store) and os.path.getsize(store) == 8192)
        proc, sock = start(image, store)
        vcp = None
        log = None
        deadline = time.time() + 5
        while log is None and time.time() < deadline:
            try:
                log = socket.create_connection(("127.0.0.1", LOG_PORT), timeout=1)
                log.settimeout(0.3)
            except OSError:
                time.sleep(0.01)
        check("flight log port opened", log is not None)
        receiver = Receiver()
        receiver.start()
        gps = GPS()
        gps.start()
        try:
            time.sleep(2.5)
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
            raw = msp(sock, 106)
            lat = int.from_bytes(raw[2:6], "little", signed=True) if raw and len(raw) >= 10 else 0
            lon = int.from_bytes(raw[6:10], "little", signed=True) if raw and len(raw) >= 10 else 0
            check("GPS fix reaches the raw GPS reply",
                  raw is not None and len(raw) >= 10 and raw[0] != 0 and raw[1] == 10 and lat == 481173000
                  and abs(lon - 115166667) <= 10, repr(raw[:10] if raw else raw))
            data = read_all(log, 4.0) if log is not None else b""
            head = data.split(b"\n")
            check("flight log header starts the log", data.startswith(b"H Product:Blackbox flight data recorder by Nicholas Sherlock\nH Data version:2\n"),
                  repr(data[:80]))
            check("flight log names the firmware", b"H Firmware type:Adaflight\n" in data and b"H Firmware revision:Adaflight 0.1.0 (0000000) STM32F405\n" in data,
                  repr([l for l in head if l.startswith(b"H Firmware")][:2]))
            check("flight log names the craft", b"H Craft name:ADAHOST\n" in data, repr([l for l in head if l.startswith(b"H Craft")]))
            check("flight log lists the fields", b"H Field I name:loopIteration,time,axisP[0]" in data, repr([l for l in head if l.startswith(b"H Field I name")][:1])[:120])
            check("flight log writes frames", len(data) > 4000 and b"\nI" in data[data.find(b"H Craft name:"):], f"{len(data)} bytes")
            now = int(time.time())
            ack = msp(sock, 246, now.to_bytes(4, "little") + (500).to_bytes(2, "little"))
            check("MSP sets the clock", ack == b"", repr(ack))
            clock = msp(sock, 247)
            stamp = time.gmtime(now)
            check("MSP clock reply holds the date",
                  clock is not None and len(clock) == 9 and (clock[0] | clock[1] << 8) == stamp.tm_year
                  and clock[2] == stamp.tm_mon and clock[3] == stamp.tm_mday and clock[4] == stamp.tm_hour
                  and clock[5] == stamp.tm_min and stamp.tm_sec <= clock[6] <= stamp.tm_sec + 2, repr(clock))
            vcp = socket.create_connection(("127.0.0.1", VCP_PORT), timeout=1)
            vcp.settimeout(0.3)
            time.sleep(0.2)
            vcp.sendall(b"#")
            banner = read_all(vcp, 0.8).decode(errors="replace")
            check("command line over the USB serial port", "Entering CLI Mode" in banner, banner[:80])
            text = cli(vcp, "get gyro_lpf1_static_hz")
            check("setting kept across the restart", "gyro_lpf1_static_hz = 321" in text, text[-160:])
            text = cli(vcp, "status")
            check("status names the MAX7456 display", "OSD: MAX7456 (30 x 16)" in text,
                  text[text.find("OSD:"):][:40])
            text = cli(vcp, "status")
            flags = text.split("Arming disable flags:")[-1]
            check("receiver link clears the signal loss", "RXLOSS" not in flags and "CLI" in flags, flags.strip()[:80])
            check("status shows the GPS connected", "GPS: connected" in text, text[text.find("GPS:"):][:60])
            time.sleep(5.0)
            try:
                with open(store + ".osd.txt") as f:
                    screen = f.read()
            except OSError:
                screen = ""
            check("OSD draws the craft name", "ADAHOST" in screen, repr(screen[:200]))
            check("OSD draws the date", time.strftime("%Y-%m-%d", stamp) in screen, repr(screen[:200]))
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
            text = cli(vcp, "status")
            flags = text.split("Arming disable flags:")[-1]
            check("open menu holds arming", "CMS" in flags, flags.strip()[:80])
            frames = dict(receiver.frames)
            check("telemetry frames reach the receiver port",
                  frames.get(0x1E, 0) > 5 and frames.get(0x08, 0) > 5 and frames.get(0x21, 0) > 5
                  and frames.get(0x02, 0) > 5, repr(frames))
        finally:
            receiver.stop.set()
            gps.stop.set()
            stop(proc)
            sock.close()
            if vcp is not None:
                vcp.close()
            if log is not None:
                log.close()
        card = os.path.join(work, "sdcard.img")
        fat16_image(card, 40960)
        proc, sock = start(image, store, {"ADAFLIGHT_SD_IMAGE": card})
        try:
            time.sleep(1.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set blackbox_device = SDCARD")
            check("flight log device set to the card", "blackbox_device set to SDCARD" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store, {"ADAFLIGHT_SD_IMAGE": card})
        try:
            time.sleep(6.0)
            summary = msp(sock, 79)
            check("MSP SD card summary reports the card ready",
                  summary is not None and len(summary) == 11 and summary[0] == 1 and summary[1] == 4, repr(summary))
            total = int.from_bytes(summary[7:11], "little") if summary and len(summary) == 11 else 0
            check("MSP SD card summary sizes the card", total == 20480, str(total))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "sd_info")
            check("sd_info names the card", "20480kB" in text and "'ADAFL FS: Ready" in text, text[-160:])
            time.sleep(2.0)
        finally:
            stop(proc)
            sock.close()
        data, why = fat16_log(card)
        check("card image holds the log file", data is not None, why)
        check("log file on the card starts with the header",
              data is not None and data.startswith(b"H Product:Blackbox flight data recorder by Nicholas Sherlock\n"),
              repr(data[:60] if data else data))
        check("log file on the card names the firmware", data is not None and b"H Firmware type:Adaflight\n" in data,
              repr(data[:200] if data else data))
        chip = os.path.join(work, "flash.img")
        with open(chip, "wb") as f:
            f.write(b"\xff" * (16 * 1024 * 1024))
        proc, sock = start(image, store, {"ADAFLIGHT_FLASH_IMAGE": chip})
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set blackbox_device = SPIFLASH")
            check("flight log device set to the flash chip", "blackbox_device set to SPIFLASH" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store, {"ADAFLIGHT_FLASH_IMAGE": chip})
        try:
            time.sleep(4.0)
            deadline = time.time() + 6.0
            while True:
                summary = msp(sock, 70)
                used = int.from_bytes(summary[9:13], "little") if summary and len(summary) == 13 else 0
                if used >= 2048 or time.time() > deadline:
                    break
                time.sleep(0.5)
            sectors = int.from_bytes(summary[1:5], "little") if summary and len(summary) == 13 else 0
            size = int.from_bytes(summary[5:9], "little") if summary and len(summary) == 13 else 0
            used = int.from_bytes(summary[9:13], "little") if summary and len(summary) == 13 else 0
            check("MSP flash summary reports the chip ready",
                  summary is not None and len(summary) == 13 and summary[0] == 3, repr(summary))
            check("MSP flash summary sizes the chip", sectors == 256 and size == 16 * 1024 * 1024, f"{sectors} {size}")
            check("MSP flash summary counts the log's bytes", 2048 <= used < 16 * 1024 * 1024, str(used))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "flash_info", 1.5)
            check("flash_info names the chip", "sectors=256" in text and "FlashFS size=16777216" in text, text[-200:])
            text = cli(sock, "flash_read 0 60", 1.5)
            check("flash_read shows the header", "H Product:Blackbox flight data recorder" in text, text[-200:])
        finally:
            stop(proc)
            sock.close()
        with open(chip, "rb") as f:
            head = f.read(4096)
        check("flash image starts with the log header",
              head.startswith(b"H Product:Blackbox flight data recorder by Nicholas Sherlock\n"), repr(head[:60]))
        check("flash image names the firmware", b"H Firmware type:Adaflight\n" in head, repr(head[:200]))
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set blackbox_uart = NONE")
            check("flight log port released", "blackbox_uart set to NONE" in text, text[-120:])
            text = cli(sock, "set vtx_uart = UART6")
            check("transmitter port assigned", "vtx_uart set to UART6" in text, text[-120:])
            text = cli(sock, "set vtx_type = SMARTAUDIO")
            check("transmitter type set to SmartAudio", "vtx_type set to SMARTAUDIO" in text, text[-120:])
            text = cli(sock, "aux 0 40 1 1700 2100 0 0")
            check("USER1 range set", "aux 0 40 1 1700 2100 0 0" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        vtx = SmartAudio()
        proc, sock = start(image, store)
        vtx.start()
        try:
            time.sleep(4.0)
            config = msp(sock, 88)
            check("MSP VTX config names a ready SmartAudio device",
                  config is not None and len(config) >= 8 and config[0] == 3 and config[7] == 1, repr(config))
            check("SmartAudio settings request reaches the transmitter", any(c == 1 for c, _ in vtx.commands),
                  repr(vtx.commands[:6]))
            ack = msp(sock, 89, (5800).to_bytes(2, "little") + bytes([1, 0]))
            check("MSP VTX config write accepted", ack == b"", repr(ack))
            time.sleep(2.0)
            check("SmartAudio frequency command reaches the transmitter", (4, 5800) in vtx.commands,
                  repr(vtx.commands[-8:]))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "vtx_info")
            check("vtx_info lists the power levels", "level " in text and " mW" in text, text[-160:])
            text = cli(sock, "tasks", 1.5)
            check("PINIO box task runs for the USER1 range", "PINIOBOX" in text, text[-300:])
            text = cli(sock, "set vtx_uart = NONE")
            check("transmitter port released", "vtx_uart set to NONE" in text, text[-120:])
            text = cli(sock, "feature ESC_SENSOR")
            check("ESC sensor feature on", "Enabled" in text, text[-120:])
            text = cli(sock, "set esc_sensor_uart = UART6")
            check("ESC sensor port assigned", "esc_sensor_uart set to UART6" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            vtx.stop.set()
            stop(proc)
            sock.close()
        esc = ESC()
        proc, sock = start(image, store)
        esc.start()
        try:
            time.sleep(7.5)
            data = msp(sock, 134)
            readings = [(data[1 + 3 * m], int.from_bytes(data[2 + 3 * m:4 + 3 * m], "little")) for m in range(4)] \
                if data and len(data) == 13 else []
            check("MSP ESC sensor data reads each motor's temperature and rate",
                  data is not None and len(data) == 13 and data[0] == 4 and readings == [(42, 345)] * 4, repr(data))
            data = msp(sock, 139)
            first = (int.from_bytes(data[1:5], "little"), data[7], int.from_bytes(data[8:10], "little"),
                     int.from_bytes(data[10:12], "little"), int.from_bytes(data[12:14], "little")) \
                if data and len(data) == 53 else None
            check("MSP motor telemetry reads the ESC sensor's values", first == (4929, 42, 1610, 250, 77), repr(first))
            esc.stop.set()
            esc.join(timeout=2)
            info = ESCInfo(store + ".dshot.txt")
            info.start()
            time.sleep(0.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "tasks", 1.5)
            check("ESC sensor task runs", "ESC_SENSOR" in text, text[-300:])
            for _ in range(3):
                text = cli(sock, "dshotprog 0 6", 1.5)
                if "ESC Type: KISS24A" in text:
                    break
            check("dshotprog reads the ESC's information",
                  "ESC Type: KISS24A" in text and "mcu serial no: 0x010203-040506-070809-0a0b0c" in text.lower()
                  and "Firmware Version: 1.31b" in text and "3D: off" in text, text[-400:])
        finally:
            esc.stop.set()
            if "info" in locals():
                info.stop.set()
            stop(proc)
            sock.close()
    print(f"host smoke: {'all checks passed' if not failures else str(len(failures)) + ' failed'}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
