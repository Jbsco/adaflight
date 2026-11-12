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
import calendar
import math
import os
import re
import select
import socket
import struct
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


def msp_pushes(data, command):
    """The payloads of the MSP version 1 replies with the command in a byte stream, each frame's checksum
    checked."""
    found = []
    i = data.find(b"$M>")
    while i != -1 and i + 6 <= len(data):
        size, cmd = data[i + 3], data[i + 4]
        end = i + 5 + size
        if end < len(data):
            check = size ^ cmd
            for b in data[i + 5:end]:
                check ^= b
            if cmd == command and check == data[end]:
                found.append(data[i + 5:end])
        i = data.find(b"$M>", i + 1)
    return found


def crsf_msp_request(payload):
    """An MSP request frame from the radio: the address, the length, the type, the flight controller as the
    destination and the radio as the origin, the MSP tunnel's payload and the CRC8."""
    body = bytes([0x7A, 0xC8, 0xEA]) + payload
    return bytes([0xC8, len(body) + 1]) + body + bytes([crc8(body)])


def crsf_display_command(subcommand, rows=0, cols=0):
    """A display port command frame from the radio: the address, the length, the type, the flight controller as
    the destination and the radio as the origin, the subcommand with the screen's rows and columns for an open,
    and the CRC8."""
    body = bytes([0x7D, 0xC8, 0xEA, subcommand]) + (bytes([rows, cols]) if subcommand == 3 else b"")
    return bytes([0xC8, len(body) + 1]) + body + bytes([crc8(body)])


def crsf_display_screens(frames):
    """The screens that the display port update frames draw, in order: the chunks of one batch from the one with
    the first flag to the one with the last flag, run-length decoded with a count of zero standing for 256."""
    screens, chunks = [], []
    for frame in frames:
        body = frame[2:-1]
        if len(body) < 6 or body[3] != 0x01:
            continue
        if body[4] & 0x80:
            chunks = []
        chunks.append(body[6:])
        if body[4] & 0x40:
            stream, text, k = b"".join(chunks), b"", 0
            while k < len(stream):
                if stream[k] & 0x80 and k + 1 < len(stream):
                    text += bytes([stream[k] & 0x7F]) * (stream[k + 1] or 256)
                    k += 2
                else:
                    text += stream[k:k + 1]
                    k += 1
            screens.append(text.decode("ascii", "replace"))
    return screens


def msp_tunnel_reply(chunks):
    """The MSP reply in a run of MSP tunnel chunks: the command, the declared size, a jumbo size included, the
    data and whether the chunks' sequence numbers follow on from the first, which has the start flag."""
    if not chunks or not chunks[0] or not chunks[0][0] & 0x10:
        return None
    size, command, start = chunks[0][1], chunks[0][2], 3
    if size == 0xFF:
        size, start = chunks[0][3] | chunks[0][4] << 8, 5
    data = chunks[0][start:] + b"".join(c[1:] for c in chunks[1:])
    ordered = all((c[0] & 0x0F) == ((chunks[0][0] + n) & 0x0F) for n, c in enumerate(chunks))
    return command, size, data[:size], ordered


def nmea(body):
    check = 0
    for byte in body.encode():
        check ^= byte
    return f"${body}*{check:02X}\r\n".encode()


class GPS(threading.Thread):
    """Sends a fix on UART4's port at 5 Hz: ten satellites at 48.1173 north, 11.5167 east, 545.4 m or the
    altitude the check sets."""

    def __init__(self):
        super().__init__(daemon=True)
        self.stop = threading.Event()
        self.altitude = 545.4

    def frames(self, tick):
        """The fix at a time that advances a fifth of a second per frame, so each solution is new."""
        clock = f"{12 + tick // 18000:02d}{(tick // 300) % 60:02d}{(tick // 5) % 60:02d}.{(tick % 5) * 20:02d}"
        return nmea(f"GPGGA,{clock},4807.03800,N,01131.00000,E,1,10,0.9,{self.altitude:.1f},M,46.9,M,,") + nmea(
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


class LapGPS(GPS):
    """The fix of GPS at the gate for three frames, then 185 m north of it for seven, in turn: a lap every two
    seconds."""

    def frames(self, tick):
        clock = f"{12 + tick // 18000:02d}{(tick // 300) % 60:02d}{(tick // 5) % 60:02d}.{(tick % 5) * 20:02d}"
        lat = "4807.03800" if tick % 10 < 3 else "4807.13800"
        return nmea(f"GPGGA,{clock},{lat},N,01131.00000,E,1,10,0.9,{self.altitude:.1f},M,46.9,M,,") + nmea(
            f"GPRMC,{clock},A,{lat},N,01131.00000,E,022.4,084.4,230394,003.1,W")


def sbus_frame(channels):
    """An SBUS frame: the begin byte, sixteen eleven-bit channels packed from the low bit, no flags, the end
    byte."""
    bits = 0
    for i, value in enumerate(channels[:16]):
        bits |= (value & 0x7FF) << (11 * i)
    return bytes([0x0F]) + bits.to_bytes(22, "little") + bytes([0x00, 0x00])


def ibus_frame(channels_us):
    """An IBUS frame of the IA6B: length and command, fourteen channels in microseconds little-endian, and the
    checksum from 0xFFFF down."""
    body = bytes([0x20, 0x40]) + b"".join(v.to_bytes(2, "little") for v in channels_us[:14])
    return body + ((0xFFFF - sum(body)) & 0xFFFF).to_bytes(2, "little")


def fport_frame(sbus_channels, rssi=100):
    """An FPORT control frame: between the markers, the length, the control type, the SBUS channel block
    with its flags, the RSSI and the FrSky checksum, with the markers and the escape byte stuffed."""
    body = bytes([0x19, 0x00]) + sbus_frame(sbus_channels)[1:24] + bytes([rssi])
    total = sum(body)
    while total > 0xFF:
        total = (total & 0xFF) + (total >> 8)
    body += bytes([0xFF - total])
    stuffed = b"".join(bytes([0x7D, b ^ 0x20]) if b in (0x7D, 0x7E) else bytes([b]) for b in body)
    return bytes([0x7E]) + stuffed + bytes([0x7E])


def fport_telemetry_request(frame_id=0x10, payload=bytes(6)):
    """An FPORT telemetry request between the markers: the length, the request type, the frame id, the six
    payload bytes of its value id and data, zero unless given, and the FrSky checksum, stuffed like a control
    frame."""
    body = bytes([0x08, 0x01, frame_id]) + payload
    total = sum(body)
    while total > 0xFF:
        total = (total & 0xFF) + (total >> 8)
    body += bytes([0xFF - total])
    stuffed = b"".join(bytes([0x7D, b ^ 0x20]) if b in (0x7D, 0x7E) else bytes([b]) for b in body)
    return bytes([0x7E]) + stuffed + bytes([0x7E])


def fport_replies(data):
    """The FPORT telemetry replies in the bytes the board sent: the length eight and the reply type, then
    the frame id, the value id and the value unstuffed, with the FrSky checksum over all of it reading full."""
    raw = data.replace(bytes([0x7D, 0x5E]), bytes([0x7E])).replace(bytes([0x7D, 0x5D]), bytes([0x7D]))
    replies = []
    i = raw.find(bytes([0x08, 0x81]))
    while i != -1 and i + 10 <= len(raw):
        frame = raw[i:i + 10]
        total = sum(frame)
        while total > 0xFF:
            total = (total & 0xFF) + (total >> 8)
        if total == 0xFF:
            replies.append((frame[2], frame[3] | frame[4] << 8, int.from_bytes(frame[5:9], "little")))
        i = raw.find(bytes([0x08, 0x81]), i + 1)
    return replies


def srxl_frames(data):
    """The SRXL telemetry frames in the bytes the board sent: the sixteen payload bytes behind the two address
    bytes and the length of each frame whose CRC16 over its payload reads back little-endian."""
    frames = []
    i = data.find(bytes([0xA5, 0x80, 0x15]))
    while i != -1 and i + 21 <= len(data):
        frame = data[i:i + 21]
        if crc16_xmodem(frame[3:19]) == int.from_bytes(frame[19:21], "little"):
            frames.append(frame[3:19])
            i = data.find(bytes([0xA5, 0x80, 0x15]), i + 21)
        else:
            i = data.find(bytes([0xA5, 0x80, 0x15]), i + 1)
    return frames


def hub_frames(data):
    """The FrSky hub frames in the bytes the board sent: the id and the unstuffed sixteen-bit value of each
    three-byte run between the header and tail bytes."""
    frames = []
    for part in data.split(bytes([0x5E])):
        raw = part.replace(bytes([0x5D, 0x3E]), bytes([0x5E])).replace(bytes([0x5D, 0x3D]), bytes([0x5D]))
        if len(raw) == 3:
            frames.append((raw[0], raw[1] | raw[2] << 8))
    return frames


def ibus_request(command, address):
    """An iBus telemetry request: the length four, the command over the sensor address, and the checksum
    from 0xFFFF down."""
    body = bytes([0x04, command | address])
    return body + ((0xFFFF - sum(body)) & 0xFFFF).to_bytes(2, "little")


def sport_unescape(data):
    """The bytes the board sent on a SmartPort line with their escapes undone."""
    raw = bytearray()
    escaped = False
    for b in data:
        if escaped:
            raw.append(b ^ 0x20)
            escaped = False
        elif b == 0x7D:
            escaped = True
        else:
            raw.append(b)
    return raw


def sport_checked_frames(data, frame_id):
    """The eight-byte SmartPort frames of one frame id in the bytes the board sent, unescaped, whose FrSky
    checksum agrees."""
    raw = sport_unescape(data)
    frames = []
    i = 0
    while i + 8 <= len(raw):
        frame = raw[i:i + 8]
        total = sum(frame[:7])
        while total > 0xFF:
            total = (total & 0xFF) + (total >> 8)
        if frame[0] == frame_id and frame[7] == 0xFF - total:
            frames.append(bytes(frame))
            i += 8
        else:
            i += 1
    return frames


def sport_frames(data):
    """The SmartPort data frames in the bytes the board sent: the value id and the value of each checked frame
    of the data frame id."""
    return [(f[1] | f[2] << 8, int.from_bytes(f[3:7], "little")) for f in sport_checked_frames(data, 0x10)]


def sport_msp_frames(data):
    """The MSP reply chunks in the bytes the board sent: the six bytes behind the server frame id of each
    checked frame."""
    return [f[1:7] for f in sport_checked_frames(data, 0x32)]


def sport_request(payload):
    """An MSP request from a SmartPort receiver: the start byte, the request sensor id, the client frame id,
    the six payload bytes and the FrSky checksum, escaped past the sensor id."""
    body = bytes([0x30]) + payload
    total = sum(body)
    while total > 0xFF:
        total = (total & 0xFF) + (total >> 8)
    body += bytes([0xFF - total])
    stuffed = b"".join(bytes([0x7D, b ^ 0x20]) if b in (0x7D, 0x7E) else bytes([b]) for b in body)
    return bytes([0x7E, 0x0D]) + stuffed


def crc8_dvb_s2(data):
    """The CRC8 of polynomial 0xD5 from zero."""
    crc = 0
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = ((crc << 1) ^ 0xD5) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc


def ghst_frames(channels_us):
    """Two Ghost frames for the flight controller, each the address, the length, the type, the four
    twelve-bit primary channels in quarter microseconds from 988 us, four more bytes and the CRC8 of the type
    and payload: one with the link quality, the RSSI and the normal RF protocol, one with aux channels 5 to 8."""
    bits = 0
    for i, v in enumerate(channels_us[:4]):
        bits |= ((v - 988) * 4 & 0xFFF) << (12 * i)

    def frame(kind, tail):
        body = bytes([kind]) + bits.to_bytes(6, "little") + bytes(tail)
        return bytes([0x82, 12]) + body + bytes([crc8_dvb_s2(body)])
    return [frame(0x33, [100, 60, 0x05, 20]), frame(0x30, [128, 128, 128, 128])]


def ghst_msp_request(payload):
    """A Ghost MSP request frame for the flight controller: the address, the length, the type, the MSP
    tunnel's payload zero-filled to ten bytes and the CRC8 of the type and payload."""
    body = bytes([0x21]) + payload.ljust(10, b"\0")
    return bytes([0x82, 12]) + body + bytes([crc8_dvb_s2(body)])


def ghst_replies(data):
    """The Ghost telemetry frames in the bytes from the flight controller: the receiver's address, the length
    twelve, the type, ten payload bytes and the CRC8 of the type and payload, which must check."""
    frames = []
    i = 0
    while i + 14 <= len(data):
        if data[i] == 0x89 and data[i + 1] == 12 and crc8_dvb_s2(data[i + 2:i + 13]) == data[i + 13]:
            frames.append((data[i + 2], data[i + 3:i + 13]))
            i += 14
        else:
            i += 1
    return frames


def ghst_msp_exchange(sender, payload, count, wait):
    """The six-byte chunks of the Ghost MSP reply to a request, read until count of them are in or the wait
    runs out. The request goes out again, and the count starts over, when no chunk comes within a second,
    since the receiver keeps only the later of two frames that reach the image together."""
    deadline = time.time() + wait
    while True:
        mark = len(sender.received)
        sender.outbox.append(ghst_msp_request(payload))
        resend = time.time() + 1.0
        while True:
            chunks = [p[:6] for k, p in ghst_replies(sender.received[mark:]) if k == 0x28]
            if len(chunks) >= count or time.time() >= deadline or (not chunks and time.time() >= resend):
                break
            time.sleep(0.05)
        if chunks or time.time() >= deadline:
            break
    time.sleep(0.3)
    return [p[:6] for k, p in ghst_replies(sender.received[mark:]) if k == 0x28]


def jeti_frame(channels_us):
    """A Jeti EX Bus channel frame: the channel header with the frame length, a packet id, the channel data
    id and the data length, the channels in eighths of a microsecond little-endian, and the reflected CRC16
    little-endian, so the CRC over the whole frame reads zero."""
    data = b"".join((v * 8).to_bytes(2, "little") for v in channels_us[:16])
    body = bytes([0x3E, 0x03, 6 + len(data) + 2, 0x01, 0x31, len(data)]) + data
    return body + jeti_crc16(body).to_bytes(2, "little")


def jeti_crc16(data):
    """The EX Bus CRC16 from zero over the reflected CCITT polynomial."""
    crc = 0
    for b in data:
        d = b ^ (crc & 0xFF)
        d ^= (d << 4) & 0xFF
        crc = (((d << 8) | ((crc & 0xFF00) >> 8)) ^ (d >> 4) ^ (d << 3)) & 0xFFFF
    return crc


def jeti_request(packet):
    """An EX Bus telemetry request that lets the flight controller answer: the request header, the frame
    length, the packet id, the telemetry request id with no data, and the CRC16 little-endian."""
    body = bytes([0x3D, 0x01, 8, packet, 0x3A, 0])
    return body + jeti_crc16(body).to_bytes(2, "little")


def jeti_answers(data):
    """The EX Bus telemetry answers in the bytes from the flight controller: the answer header and length, with
    the CRC16 over the whole frame reading zero."""
    frames = []
    i = 0
    while i + 8 <= len(data):
        n = data[i + 2]
        if data[i] == 0x3B and data[i + 1] == 0x01 and 8 <= n <= len(data) - i and jeti_crc16(data[i:i + n]) == 0:
            frames.append(data[i:i + n])
            i += n
        else:
            i += 1
    return frames


def crc16_xmodem(data):
    """The CRC16 of polynomial 0x1021 from zero, most significant bit first."""
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def sumd_frame(channels_us):
    """A SUMD frame: the sync byte, the valid state, the channel count, the channels in eighths of a
    microsecond big-endian, and the CRC16 over all of it."""
    body = bytes([0xA8, 0x01, len(channels_us)]) + b"".join((v * 8).to_bytes(2, "big") for v in channels_us)
    return body + crc16_xmodem(body).to_bytes(2, "big")


def sumh_frame(channels_us):
    """A SUMH frame: the sync byte, two bytes the receiver skips, eight channels big-endian as
    (us + 375) * 6.4, the zero before the last byte, and a last byte it skips."""
    words = b"".join(round((v + 375) * 6.4).to_bytes(2, "big") for v in channels_us[:8])
    return bytes([0xA8, 0x00, 0x00]) + words + bytes([0x00, 0x00])


def srxl2_frame(channels_us, reply=0):
    """An SRXL2 control data packet of channel data: the device asked to reply, full RSSI, no frame losses, a
    mask over the first channels and a word per channel little-endian in 1/64 us from 988 us, then the CRC-16
    high byte first."""
    ch = channels_us[:16]
    body = bytes([0xA6, 0xCD, 12 + 2 * len(ch) + 2, 0x00, reply, 100, 0, 0]) + ((1 << len(ch)) - 1).to_bytes(4, "little") \
        + b"".join(((v - 988) * 64).to_bytes(2, "little") for v in ch)
    return body + crc16_xmodem(body).to_bytes(2, "big")


def spektrum_frame(channels_us):
    """A Spektrum 2048 frame: the fade count and the DSMX 11 ms system byte, then seven channel words
    big-endian, each the channel number above an eleven-bit value in half microseconds from 988 us."""
    words = b"".join(((ch << 11) | ((v - 988) * 2 & 0x7FF)).to_bytes(2, "big") for ch, v in enumerate(channels_us[:7]))
    return bytes([0x00, 0xB2]) + words


def xbus_frame(channels_us):
    """An XBUS mode B frame of twelve channels: the start byte, the channels big-endian in steps of
    1400/4096 us from 800 us, and the CRC16 over the rest."""
    body = bytes([0xA1]) + b"".join((round((v - 800) * 4096 / 1400)).to_bytes(2, "big") for v in channels_us[:12])
    return body + crc16_xmodem(body).to_bytes(2, "big")


class SerialReceiver(threading.Thread):
    """Sends a receiver protocol's frames on UART3's port about every 14 ms: roll and yaw at mid, pitch at
    1599 us, throttle low, in the protocol's frame."""

    def __init__(self, frame):
        super().__init__(daemon=True)
        self.frames = frame if isinstance(frame, list) else [frame]
        self.stop = threading.Event()
        self.received = b""
        self.outbox = []

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            except OSError:
                time.sleep(0.1)
        turn = 0
        while sock is not None and not self.stop.is_set():
            try:
                sock.sendall(self.outbox.pop(0) if self.outbox else self.frames[turn % len(self.frames)])
            except OSError:
                break
            turn += 1
            time.sleep(0.014)
            if select.select([sock], [], [], 0)[0]:
                try:
                    self.received += sock.recv(4096)
                except OSError:
                    break
        if sock is not None:
            sock.close()


def tofsense_frame(distance_mm):
    """A Nooploop TOFSense frame: the two sync bytes, the id, the system time, the distance in millimetres in
    three bytes, a valid status, the signal strength, a reserved byte and the sum of the first fifteen bytes."""
    body = (bytes([0x57, 0x00, 0xFF, 0x00]) + (1000).to_bytes(4, "little") + distance_mm.to_bytes(3, "little")
            + bytes([0x00]) + (300).to_bytes(2, "little") + bytes([0x00]))
    return body + bytes([sum(body) & 0xFF])


def upt1_frame(distance_mm, flow_x=100, flow_y=-50, span_us=10000, confidence=90):
    """A UP-T1 frame: header, length, flow integrals in radians times ten thousand, integration span, distance
    in millimetres, laser status available, confidence, exclusive-or of the ten data bytes and footer."""
    data = (flow_x.to_bytes(2, "little", signed=True) + flow_y.to_bytes(2, "little", signed=True)
            + span_us.to_bytes(2, "little") + distance_mm.to_bytes(2, "little") + bytes([0xF5, confidence]))
    x = 0
    for b in data:
        x ^= b
    return bytes([0xFE, 0x0A]) + data + bytes([x, 0x55])


def gimbal_frame(roll, pitch, yaw, mode=0, sens=15):
    """A head tracker command frame: the opcode 0x5AA5, the mode and sensitivity, four padding bits, the
    12-bit roll, pitch and yaw, and the CRC16 of the first eight bytes, high byte first."""
    bits = (roll & 0xFFF) << 4 | (pitch & 0xFFF) << 16 | (yaw & 0xFFF) << 28
    body = bytes([0xA5, 0x5A, (mode & 7) | (sens & 0x1F) << 3]) + bits.to_bytes(5, "little")
    crc = crc16_xmodem(body)
    return body + bytes([crc >> 8, crc & 0xFF])


def gimbal_frames(data):
    """The command frames in data whose CRC checks, as mode, sensitivity, roll, pitch and yaw."""
    def signed(value, width):
        return value - (1 << width) if value >> (width - 1) & 1 else value
    frames = []
    i = 0
    while i + 10 <= len(data):
        f = data[i:i + 10]
        crc = crc16_xmodem(f[:8])
        if f[:2] == b"\xa5\x5a" and f[8] == crc >> 8 and f[9] == crc & 0xFF:
            bits = int.from_bytes(f[3:8], "little")
            frames.append((f[2] & 7, signed(f[2] >> 3, 5), signed(bits >> 4 & 0xFFF, 12),
                           signed(bits >> 16 & 0xFFF, 12), signed(bits >> 28 & 0xFFF, 12)))
            i += 10
        else:
            i += 1
    return frames


class Lidar(threading.Thread):
    """A rangefinder on UART4's port sending a frame every 10 ms: by default a TFmini's two sync bytes, 150 cm,
    a strength of 500, the short integral time, a reserved byte and the checksum of the first eight bytes."""

    def __init__(self, frame=None, prefix=b""):
        super().__init__(daemon=True)
        self.stop = threading.Event()
        self.frame = frame
        self.prefix = prefix

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
            except OSError:
                time.sleep(0.1)
        body = bytes([0x59, 0x59]) + (150).to_bytes(2, "little") + (500).to_bytes(2, "little") + bytes([0x02, 0x00])
        frame = self.frame if self.frame is not None else body + bytes([sum(body) & 0xFF])
        if sock is not None and self.prefix:
            try:
                sock.sendall(self.prefix)
            except OSError:
                sock = None
        while sock is not None and not self.stop.is_set():
            try:
                sock.sendall(frame)
            except OSError:
                break
            time.sleep(0.01)
        if sock is not None:
            sock.close()


class Camera(threading.Thread):
    """A RunCam camera on UART4's port: answers each device information request with protocol 1.0 and the
    power, WiFi and mode buttons, and keeps every packet the flight controller sends."""

    def __init__(self):
        super().__init__(daemon=True)
        self.stop = threading.Event()
        self.received = b""

    def run(self):
        sock = None
        deadline = time.time() + 10
        while sock is None and time.time() < deadline and not self.stop.is_set():
            try:
                sock = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
            except OSError:
                time.sleep(0.1)
        if sock is not None:
            sock.settimeout(0.02)
        info = bytes([0xCC, 0x00, crc8_dvb_s2(bytes([0xCC, 0x00]))])
        answered = 0
        while sock is not None and not self.stop.is_set():
            try:
                self.received += sock.recv(4096)
            except socket.timeout:
                pass
            except OSError:
                break
            if self.received.count(info) > answered:
                answered += 1
                reply = bytes([0xCC, 0x01, 0x07, 0x00])
                sock.sendall(reply + bytes([crc8_dvb_s2(reply)]))
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
        self.outbox = []
        self.msp_replies = []
        self.display_frames = []

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
                if frame[2] == 0x7B:
                    self.msp_replies.append(frame)
                if frame[2] == 0x7D:
                    self.display_frames.append(frame)

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
                if self.outbox:
                    sock.sendall(self.outbox.pop(0))
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
features = None


def build_features(image):
    """The features the image's build contains, from the feature package generated beside its bin directory,
    or None for a build without one, which counts as every feature."""
    path = os.path.join(os.path.dirname(os.path.dirname(image)), "gen", "adaflight-build_features.ads")
    try:
        with open(path) as f:
            text = f.read()
    except OSError:
        return None
    return {m.group(1): m.group(2) == "True"
            for m in re.finditer(r"^\s*(\w+)\s*: constant Boolean := (\w+);", text, re.M)}


def built(feature):
    """Whether the image contains the feature, with a SKIP line for the checks that need a feature it leaves
    out."""
    if features is None or features.get(feature, True):
        return True
    print(f"SKIP the checks that need {feature}: the build leaves it out")
    return False


def contains(feature):
    """Whether the image contains the feature."""
    return features is None or features.get(feature, True)


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
    2.50 A, 77 mAh and 345 hundred electrical revolutions per minute, the charge growing by one mAh every
    tenth frame when growing is set."""

    FRAME = bytes([42]) + (1610).to_bytes(2, "big") + (250).to_bytes(2, "big") + (77).to_bytes(2, "big") \
        + (345).to_bytes(2, "big")

    def __init__(self, growing=False):
        super().__init__(daemon=True)
        self.stop = threading.Event()
        self.growing = growing

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
        sent = 0
        while not self.stop.is_set():
            body = self.FRAME[:5] + (77 + sent // 10).to_bytes(2, "big") + self.FRAME[7:] if self.growing else self.FRAME
            try:
                sock.sendall(body + bytes([kiss_crc(body)]))
            except OSError:
                break
            sent += 1
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


def ltm_frames(data):
    """The LTM frames in a byte stream with good checksums, as (letter, payload) pairs."""
    sizes = {ord("A"): 6, ord("S"): 7, ord("G"): 14, ord("O"): 14}
    frames = []
    i = data.find(b"$T")
    while 0 <= i and i + 3 <= len(data):
        size = sizes.get(data[i + 2])
        if size is not None and i + 3 + size < len(data):
            payload = data[i + 3:i + 3 + size]
            check = 0
            for b in payload:
                check ^= b
            if check == data[i + 3 + size]:
                frames.append((chr(data[i + 2]), payload))
        i = data.find(b"$T", i + 2)
    return frames


MAVLINK_CRC_EXTRA = {0: 50, 30: 39, 42: 28, 44: 221, 46: 11, 47: 153, 51: 196, 73: 38, 77: 143, 148: 178}


def x25(data, crc=0xFFFF):
    for byte in data:
        tmp = (byte ^ crc) & 0xFF
        tmp = (tmp ^ (tmp << 4)) & 0xFF
        crc = ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF
    return crc


def mavlink_frames(data):
    """The MAVLink 2 frames in a byte stream with good checksums among the known messages, as (id, payload)."""
    frames = []
    i = data.find(b"\xfd")
    while 0 <= i and i + 12 <= len(data):
        length = data[i + 1]
        end = i + 10 + length + 2 + (13 if data[i + 2] & 1 else 0)
        msg = data[i + 7] | data[i + 8] << 8 | data[i + 9] << 16
        if msg in MAVLINK_CRC_EXTRA and end <= len(data):
            crc = x25(bytes(data[i + 1:i + 10 + length]) + bytes([MAVLINK_CRC_EXTRA[msg]]))
            if crc == data[i + 10 + length] | data[i + 11 + length] << 8:
                frames.append((msg, data[i + 10:i + 10 + length]))
        i = data.find(b"\xfd", i + 1)
    return frames


def mavlink_sequences(data):
    """The sequence numbers of the MAVLink 2 frames that follow one another in a byte stream, from its first frame
    with a good checksum among the known messages."""
    seqs = []
    i = data.find(b"\xfd")
    while 0 <= i and i + 12 <= len(data):
        length = data[i + 1]
        end = i + 12 + length + (13 if data[i + 2] & 1 else 0)
        msg = data[i + 7] | data[i + 8] << 8 | data[i + 9] << 16
        if seqs or (msg in MAVLINK_CRC_EXTRA and end <= len(data)
                    and x25(bytes(data[i + 1:i + 10 + length]) + bytes([MAVLINK_CRC_EXTRA[msg]]))
                    == data[i + 10 + length] | data[i + 11 + length] << 8):
            if end > len(data):
                break
            seqs.append(data[i + 4])
            i = end if end < len(data) and data[end] == 0xFD else -1
        else:
            i = data.find(b"\xfd", i + 1)
    return seqs


def mavlink_command_long(command, param1):
    """A COMMAND_LONG from a ground station (system 255) to system 1, component 1."""
    payload = struct.pack("<7fHBBB", param1, 0, 0, 0, 0, 0, 0, command, 1, 1, 0)
    header = bytes([len(payload), 0, 0, 0, 255, 190]) + (76).to_bytes(3, "little")
    crc = x25(header + payload + bytes([152]))
    return b"\xfd" + header + payload + crc.to_bytes(2, "little")


def mavlink_frame(msg, payload, extra):
    """A MAVLink 2 frame from a ground station (system 255, component 190) with the message's CRC extra."""
    header = bytes([len(payload), 0, 0, 0, 255, 190]) + msg.to_bytes(3, "little")
    crc = x25(header + payload + bytes([extra]))
    return b"\xfd" + header + payload + crc.to_bytes(2, "little")


def mavlink_exchange(mav, frame, wait=0.6):
    """The frames a ground station's frame is answered with, each payload padded to its full length."""
    mav.sendall(frame)
    return [(m, bytes(p) + bytes(40)) for m, p in mavlink_frames(read_all(mav, wait))]


def mavlink_first(frames, msg):
    return next((p for m, p in frames if m == msg), None)


MISSION_POINTS = [(407000000, -1050000000, 30.0), (407010000, -1050010000, 45.0)]


def mavlink_mission_upload(mav):
    """A ground station uploads two waypoints: the count, then each item as it is asked for."""
    got = mavlink_exchange(mav, mavlink_frame(44, struct.pack("<HBBBI", 2, 1, 1, 0, 0), 221))
    asked = mavlink_first(got, 51)
    check("mission count answered with a request for item 0", asked is not None and asked[0] | asked[1] << 8 == 0,
          repr([m for m, _ in got]))
    for seq, (lat, lon, alt) in enumerate(MISSION_POINTS):
        item = struct.pack("<4fiifHHBBBBBB", 0, 0, 0, 0, lat, lon, alt, seq, 16, 1, 1, 5, 0, 1, 0)
        got = mavlink_exchange(mav, mavlink_frame(73, item, 38))
        if seq == 0:
            asked = mavlink_first(got, 51)
            check("first mission item answered with a request for item 1",
                  asked is not None and asked[0] | asked[1] << 8 == 1, repr([m for m, _ in got]))
        else:
            ack = mavlink_first(got, 47)
            check("last mission item acknowledged as accepted", ack is not None and ack[2] == 0,
                  repr([m for m, _ in got]))
    current = [p for m, p in mavlink_exchange(mav, b"", 2.5) if m == 42]
    check("mission current reports two stored items", any(p[2] | p[3] << 8 == 2 for p in current),
          repr([bytes(p[:6]).hex() for p in current]))


def mavlink_mission_readback(mav):
    """After a restart the station reads both waypoints back, sets the current item and clears the plan."""
    got = mavlink_exchange(mav, mavlink_frame(43, struct.pack("<BBB", 1, 1, 0), 132))
    count = mavlink_first(got, 44)
    check("stored mission survives a restart with its two items", count is not None and count[0] | count[1] << 8 == 2,
          repr([m for m, _ in got]))
    for seq, (lat, lon, alt) in enumerate(MISSION_POINTS):
        got = mavlink_exchange(mav, mavlink_frame(51, struct.pack("<HBBB", seq, 1, 1, 0), 196))
        item = mavlink_first(got, 73)
        fields = struct.unpack("<4fiifHHBBBBBB", item[:38]) if item else None
        check(f"mission item {seq} read back with its position and altitude",
              fields is not None and fields[4] == lat and fields[5] == lon and abs(fields[6] - alt) < 0.01
              and fields[7] == seq and fields[8] == 16, repr(fields))
    mav.sendall(mavlink_frame(47, struct.pack("<BBBBI", 1, 1, 0, 0, 0), 153))
    got = mavlink_exchange(mav, mavlink_frame(41, struct.pack("<HBB", 9, 1, 1), 28))
    ack = mavlink_first(got, 47)
    check("set current past the plan answered with an error", ack is not None and ack[2] == 1,
          repr([m for m, _ in got]))
    got = mavlink_exchange(mav, mavlink_frame(41, struct.pack("<HBB", 1, 1, 1), 28))
    check("set current inside the plan answered with the current item and no error",
          mavlink_first(got, 42) is not None and mavlink_first(got, 47) is None, repr([m for m, _ in got]))
    got = mavlink_exchange(mav, mavlink_frame(45, struct.pack("<BBB", 1, 1, 0), 232))
    ack = mavlink_first(got, 47)
    check("mission clear acknowledged as accepted", ack is not None and ack[2] == 0, repr([m for m, _ in got]))
    got = mavlink_exchange(mav, mavlink_frame(43, struct.pack("<BBB", 1, 1, 0), 132))
    count = mavlink_first(got, 44)
    check("cleared mission lists no item", count is not None and count[0] | count[1] << 8 == 0,
          repr([m for m, _ in got]))
    # A home set over the link and a mission count in one write: the item after them gives its altitude above
    # that home, which no GPS has set here.
    home = struct.pack("<7fHBBB", 0, 0, 0, 0, 40.7, -105.0, 100.0, 179, 1, 1, 0)
    got = mavlink_exchange(mav, mavlink_frame(76, home, 152)
                           + mavlink_frame(44, struct.pack("<HBBBI", 1, 1, 1, 0, 0), 221))
    ack = mavlink_first(got, 77)
    check("home set over MAVLink acknowledged as accepted", ack is not None and ack[2] == 0,
          repr([m for m, _ in got]))
    check("mission count after it answered with a request for item 0", mavlink_first(got, 51) is not None,
          repr([m for m, _ in got]))
    item = struct.pack("<4fiifHHBBBBBB", 0, 0, 0, 0, 407000000, -1050000000, 20.0, 0, 16, 1, 1, 6, 0, 1, 0)
    got = mavlink_exchange(mav, mavlink_frame(73, item, 38))
    ack = mavlink_first(got, 47)
    check("mission item above home accepted once the link set a home", ack is not None and ack[2] == 0,
          repr([(m, bytes(p[:4]).hex()) for m, p in got if m == 47]))
    mavlink_exchange(mav, mavlink_frame(43, struct.pack("<BBB", 1, 1, 0), 132))
    got = mavlink_exchange(mav, mavlink_frame(51, struct.pack("<HBBB", 0, 1, 1, 0), 196))
    item = mavlink_first(got, 73)
    fields = struct.unpack("<4fiifHHBBBBBB", item[:38]) if item else None
    check("that item reads back at its altitude plus the home's", fields is not None and abs(fields[6] - 120.0) < 0.01,
          repr(fields))
    mav.sendall(mavlink_frame(47, struct.pack("<BBBBI", 1, 1, 0, 0, 0), 153))
    read_all(mav, 0.3)
    mav.sendall(mavlink_frame(43, struct.pack("<BBB", 1, 1, 0), 132))
    seqs = mavlink_sequences(read_all(mav, 1.5))
    check("mission replies take their own sequence numbers on the link",
          len(seqs) >= 5 and all((b - a) % 256 == 1 for a, b in zip(seqs, seqs[1:])), repr(seqs[:24]))
    mav.sendall(mavlink_frame(47, struct.pack("<BBBBI", 1, 1, 0, 0, 0), 153))


def mavlink_override(channels_us):
    """A MAVLink 2 RC channels override from a ground station: channels one to eight, target system and
    component, then channels nine to eighteen, little-endian, with the message's CRC extra 124."""
    ch = (list(channels_us) + [0] * 18)[:18]
    payload = struct.pack("<8H", *ch[:8]) + bytes([1, 1]) + struct.pack("<10H", *ch[8:])
    header = bytes([len(payload), 0, 0, 0, 255, 190]) + (70).to_bytes(3, "little")
    crc = x25(header + payload + bytes([124]))
    return b"\xfd" + header + payload + crc.to_bytes(2, "little")


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


def start(image, store, extra=None, port=PORT):
    env = dict(os.environ, ADAFLIGHT_EEPROM=store, ADAFLIGHT_OSD_SCREEN=store + ".osd.txt",
               ADAFLIGHT_DSHOT_LOG=store + ".dshot.txt", ADAFLIGHT_SERVO_LOG=store + ".servo.txt",
               ADAFLIGHT_PWM_LOG=store + ".pwm.txt", ADAFLIGHT_LED_LOG=store + ".led.txt",
               ADAFLIGHT_CAMERA_LOG=store + ".camera.txt", ADAFLIGHT_BEEPER_LOG=store + ".beeper.txt",
               **(extra or {}))
    proc = subprocess.Popen([image], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.time() + 15
    while time.time() < deadline:
        try:
            sock = socket.create_connection(("127.0.0.1", port), timeout=1)
            sock.settimeout(0.3)
            return proc, sock
        except OSError:
            if proc.poll() is not None:
                break
            time.sleep(0.1)
    proc.kill()
    raise SystemExit(f"host: the image did not open its port {port}")


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


def until(probe, ok, wait=10.0):
    """Reads the probe until ok accepts its value or the wait runs out, and returns the verdict with the last
    value, so a check keeps reading while a loaded host slows the image down."""
    deadline = time.time() + wait
    value = probe()
    while not ok(value) and time.time() < deadline:
        time.sleep(0.25)
        value = probe()
    return ok(value), value


def collect(sock, want, wait):
    """The bytes a socket gives until they hold the wanted text or the wait runs out."""
    data = b""
    deadline = time.time() + wait
    while want not in data and time.time() < deadline:
        data += read_all(sock, 0.2)
    return data


def rc_values(sock):
    """The first four channels of the MSP RC reply, none without a reply."""
    rc = msp(sock, 105)
    return [rc[i] | rc[i + 1] << 8 for i in range(0, 8, 2)] if rc and len(rc) >= 8 else []


def msp_frame(cmd, payload=b""):
    check = len(payload) ^ cmd
    for b in payload:
        check ^= b
    return b"$M<" + bytes([len(payload), cmd]) + payload + bytes([check])


def rc_stream(sock, channels, count):
    """Sends an MSP raw RC frame of the channels at 50 Hz with an RC read after each tenth one, and returns
    the first eight channels of each RC reply."""
    payload = struct.pack(f"<{len(channels)}H", *channels)
    for k in range(count):
        sock.sendall(msp_frame(200, payload))
        if k % 10 == 9:
            sock.sendall(msp_frame(105))
        time.sleep(0.02)
    data = read_all(sock, 0.3)
    seen = []
    i = data.find(b"$M>")
    while 0 <= i and i + 6 <= len(data):
        size, cmd = data[i + 3], data[i + 4]
        body = data[i + 5:i + 5 + size]
        if cmd == 105 and len(body) >= 16:
            seen.append([body[k] | body[k + 1] << 8 for k in range(0, 16, 2)])
        i = data.find(b"$M>", i + 5 + size)
    return seen


def debug_values(sock):
    """The eight debug values of the MSP debug reply, none without a reply."""
    reply = msp(sock, 254)
    return list(struct.unpack("<8h", reply[:16])) if reply and len(reply) >= 16 else []


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


def servo_lines(store):
    """The setup and pulse lines of the image's servo log, as lists of their fields."""
    try:
        with open(store + ".servo.txt") as log:
            return [line.split(",") for line in log.read().split()]
    except OSError:
        return []


def pwm_lines(store):
    """The setup and pulse lines of the image's analog motor log, as lists of their fields."""
    try:
        with open(store + ".pwm.txt") as log:
            return [line.split(",") for line in log.read().split()]
    except OSError:
        return []


def camera_lines(store):
    """The setup, key and idle lines of the image's camera control log, as lists of their fields."""
    try:
        with open(store + ".camera.txt") as log:
            return [line.split(",") for line in log.read().split()]
    except OSError:
        return []


def led_lines(store):
    """The color lines of the image's LED strip log, as lists of their fields."""
    try:
        with open(store + ".led.txt") as log:
            return [line.split(",") for line in log.read().split()]
    except OSError:
        return []


def servo_values(sock):
    """The eight servo values of the MSP servo reply, none without a reply."""
    reply = msp(sock, 103)
    return [reply[i] | reply[i + 1] << 8 for i in range(0, 16, 2)] if reply and len(reply) >= 16 else []


def cli(sock, line, wait=0.8):
    sock.sendall(line.encode() + b"\r\n")
    return read_all(sock, wait).decode(errors="replace")


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    image = os.path.abspath(sys.argv[1])
    global features
    features = build_features(image)
    with tempfile.TemporaryDirectory() as work:
        store = os.path.join(work, "eeprom.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            api = msp(sock, 1)
            check("MSP API version 1.x", api is not None and len(api) == 3 and api[1] == 1)
            # The default camera control: hardware PWM on the board's camera pin, ENTER at 63 of 128 (1.61 V of
            # 3.3 V through 4.5 k over 4.7 k), a key past the five ignored.
            enter = msp(sock, 98, bytes([0]))
            keys = [line for line in camera_lines(store) if line[0] == "key"]
            check("camera control ENTER key sets the hardware PWM duty while disarmed",
                  enter == b"" and len(keys) == 1 and keys[0][1:5] == ["0", "0", "63", "0"], repr(keys))
            past = msp(sock, 98, bytes([7]))
            check("camera control ignores a key past the five",
                  past == b"" and len([line for line in camera_lines(store) if line[0] == "key"]) == 1)
            variant = msp(sock, 2)
            check("MSP firmware variant ADFL", variant == b"ADFL", repr(variant))
            taken = msp(sock, 186, bytes([200]))
            analog = msp(sock, 110)
            link = msp(sock, 187)
            check("an RSSI over MSP becomes the RSSI source while no receiver gives one",
                  taken == b"" and link is not None and len(link) == 2 and link[0] == 4, repr(link))
            check("an RSSI over MSP stays in the analog reply past the RSSI updates that follow",
                  analog is not None and len(analog) >= 5 and analog[3] | analog[4] << 8 == 800, repr(analog))
            time.sleep(1.2)
            analog = msp(sock, 110)
            check("an RSSI over MSP reads zero once its timeout passes",
                  analog is not None and len(analog) >= 5 and analog[3] | analog[4] << 8 == 0, repr(analog))
            log_rates = msp(sock, 80)
            check("MSP blackbox reply says whether the build contains a recorder",
                  log_rates is not None and len(log_rates) >= 7 and log_rates[0] == int(contains("Blackbox")),
                  repr(log_rates))
            if contains("Blackbox"):
                check("MSP blackbox reply gives the log's delta frame interval and its intra frame ratio",
                      log_rates is not None and len(log_rates) >= 7 and log_rates[3] == 1 << log_rates[6]
                      and int.from_bytes(log_rates[4:6], "little") == 32 // log_rates[3], repr(log_rates))
            answered = {name: msp(sock, code) is not None
                        for name, code in (("GPS", 132), ("Compass", 133), ("Servos", 120), ("LED_Strip", 48))}
            check("MSP replies of the GPS, the compass, the servos and the LED strip exist where the build contains them",
                  all(answered[name] == contains(name) for name in answered), repr(answered))
            sliders = msp(sock, 140)
            gains = msp(sock, 112)
            raised = bytearray(sliders or bytes(53))
            raised[1] = 120
            stored = msp(sock, 141, bytes(raised))
            tuned = msp(sock, 112)
            check("MSP simplified tuning write stores a slider set and applies it",
                  stored == b"" and msp(sock, 140) == bytes(raised) and gains is not None and tuned is not None
                  and tuned[0] == round(gains[0] * 1.2) and msp(sock, 145) == bytes([1, 1, 1]),
                  f"{stored!r} {gains!r} {tuned!r}")
            refused = msp(sock, 141, bytes([3]) + bytes(raised[1:]))
            check("MSP simplified tuning write refuses a mode past the three",
                  refused is None and msp(sock, 140) == bytes(raised), repr(refused))
            restored = msp(sock, 141, sliders or b"")
            check("MSP simplified tuning write of the first slider set brings the gains back",
                  restored == b"" and msp(sock, 112) == gains, repr(restored))
            info = msp(sock, 5)
            options = [int.from_bytes(info[i:i + 2], "little") for i in range(26, len(info) - 1, 2)] if info else []
            check("MSP build info lists the GPS and the DShot protocol", {16412, 8231} <= set(options), repr(options))
            status = msp(sock, 101)
            if contains("Barometer"):
                check("MSP status with the barometer", status is not None and len(status) > 5
                      and (status[4] | status[5] << 8) & 0x02 != 0)
            time.sleep(1.5)
            altitude = msp(sock, 109)
            check("MSP altitude near the calibrated ground",
                  altitude is not None and len(altitude) >= 4
                  and abs(int.from_bytes(altitude[0:4], "little", signed=True)) < 2000, repr(altitude))
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
            names = msp(sock, 116)
            ids = msp(sock, 119)
            more = msp(sock, 119, bytes([1]))
            check("MSP box names and ids list the boxes the image offers, thirty-two to a page",
                  names is not None and bytes(names).startswith(b"ARM;ANGLE;HORIZON;ALTHOLD;HEADFREE;")
                  and b"AIR MODE" not in names and ids is not None and len(ids) == 32
                  and list(ids[:4]) == [0, 1, 2, 3] and more is not None and list(more) == [54, 57],
                  repr((names, ids, more)))
            motors = msp(sock, 131)
            check("MSP motor configuration counts the mixer's four motors", motors is not None and len(motors) >= 7
                  and motors[6] == 4, repr(motors))
            check("MSP motor configuration shows no DShot telemetry in use", motors is not None and len(motors) >= 9
                  and motors[8] == 0, repr(motors))
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
            check("status keeps the motor protocol reason off with the DShot outputs driven",
                  "Arming disable flags:" in text and "MOTOR_PROTO" not in text.split("Arming disable flags:")[-1],
                  text.split("Arming disable flags:")[-1].strip()[:80])
            text = cli(sock, "tasks")
            check("tasks run the gyro and the PID loop", "GYRO" in text and "PID" in text)
            text = cli(sock, "status")
            if contains("Barometer"):
                check("status names the barometer on its bus", "BARO" in text and "BMP280" in text, text[:200])
            text = cli(sock, "options")
            numbers = {int(w) for w in text.split() if w.isdigit()}
            check("options list the GPS, the OSD chip, the servos and the motor protocols",
                  {16412, 16416, 16420, 8230, 8231, 8232, 8233, 8235} <= numbers, text[-160:])
            check("options list the SRXL2 receiver", 4105 in numbers, text[-160:])
            for feature, number in (("LTM_Telemetry", 12304), ("MAVLink_Telemetry", 12305), ("IBus_Telemetry", 12303),
                                    ("Rangefinder", 16429), ("Jeti_EX_Bus", 4101), ("SUMD", 4106),
                                    ("SUMH", 4107), ("MAVLink_Receiver", 4109), ("Wing", 16424)):
                check(f"options list {feature} as the build contains it", (number in numbers) == contains(feature),
                      f"{number} {'in' if number in numbers else 'not in'} the list")
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
            text = cli(sock, "set vcd_video_system = PAL")
            check("analog video system set", "vcd_video_system set to PAL" in text, text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("receiver port assigned", "rx_uart set to UART3" in text, text[-120:])
            text = cli(sock, "set gps_provider = NMEA")
            check("GPS provider set", "gps_provider set to NMEA" in text, text[-120:])
            text = cli(sock, "set gps_uart = UART4")
            check("GPS port assigned", "gps_uart set to UART4" in text, text[-120:])
            text = cli(sock, "set altitude_source = GPS_ONLY")
            check("altitude from GPS alone for its checks", "altitude_source set to GPS_ONLY" in text, text[-120:])
            text = cli(sock, "feature GPS")
            check("GPS feature on", "Enabled GPS" in text, text[-120:])
            text = cli(sock, "set failsafe_procedure = GPS-RESCUE")
            check("GPS rescue as the failsafe procedure", "failsafe_procedure set to GPS-RESCUE" in text, text[-120:])
            text = cli(sock, "set blackbox_device = SERIAL")
            check("flight log device set", "blackbox_device set to SERIAL" in text, text[-120:])
            text = cli(sock, "set blackbox_uart = UART6")
            check("flight log port assigned", "blackbox_uart set to UART6" in text, text[-120:])
            text = cli(sock, "set blackbox_mode = ALWAYS")
            check("flight log always on", "blackbox_mode set to ALWAYS" in text, text[-120:])
            text = cli(sock, "set debug_mode = ANGLERATE")
            check("debug mode set to the rate setpoints", "debug_mode set to ANGLERATE" in text, text[-120:])
            text = cli(sock, "adjrange 0 0 0 900 2100 1 0 0 0")
            check("RC rate adjustment on AUX1 set", "adjrange 0 0 0 900 2100 1 0 0 0" in text, text[-120:])
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
            check("MSP OSD configuration lists every element in a build with the flight plan",
                  osd is not None and len(osd) > 7 and osd[7] == 99, repr(osd[:8] if osd else osd))
            glyph = msp(sock, 87, bytes([0x41, 0x00]) + bytes(range(64)))
            check("MSP font character written", glyph == b"", repr(glyph))
            time.sleep(2.5)
            rc = msp(sock, 105)
            values = [rc[i] | rc[i + 1] << 8 for i in range(0, 8, 2)] if rc and len(rc) >= 8 else []
            check("receiver channels reach the MSP RC reply",
                  len(values) == 4 and all(abs(v - 1500) <= 2 for v in values[:3]) and values[3] <= 1000, repr(values))
            fallbacks = msp(sock, 77)
            check("MSP failsafe channel reply has an entry for each receiver channel",
                  rc is not None and fallbacks is not None and len(rc) >= 8 and len(fallbacks) == 3 * (len(rc) // 2),
                  f"{len(rc or b'')} {len(fallbacks or b'')}")
            link = msp(sock, 187)
            check("MSP transmitter information names the CRSF protocol as the RSSI source",
                  link is not None and len(link) == 2 and link[0] == 6, repr(link))
            receiver.channels[0] = 1811
            full, fast = until(lambda: debug_values(sock), lambda d: len(d) == 8 and d[0] >= 600)
            rates = msp(sock, 111)
            slower = bytearray(rates or bytes(24))
            slower[2] = 40
            sent = msp(sock, 204, bytes(slower))
            taken, slow = until(lambda: debug_values(sock), lambda d: len(d) == 8 and 380 <= d[0] <= 420, wait=5.0)
            check("a roll rate from the configurator changes the running setpoint without a save",
                  full and sent == b"" and taken, f"{fast} {slow}")
            msp(sock, 204, bytes(rates or b""))
            receiver.channels[0] = 992
            until(lambda: debug_values(sock), lambda d: len(d) == 8 and abs(d[0]) <= 5, wait=5.0)
            raw = msp(sock, 106)
            lat = int.from_bytes(raw[2:6], "little", signed=True) if raw and len(raw) >= 10 else 0
            lon = int.from_bytes(raw[6:10], "little", signed=True) if raw and len(raw) >= 10 else 0
            check("GPS fix reaches the raw GPS reply",
                  raw is not None and len(raw) >= 10 and raw[0] != 0 and raw[1] == 10 and lat == 481173000
                  and abs(lon - 115166667) <= 10, repr(raw[:10] if raw else raw))
            att = msp(sock, 108)
            yaw = int.from_bytes(att[4:6], "little", signed=True) if att and len(att) >= 6 else None
            check("first GPS fix past 1 m/s turns the heading to the 84.4 degree course",
                  yaw is not None and 83 <= yaw <= 85, repr(att))
            gps.altitude = 555.4
            time.sleep(6.0)
            alt = msp(sock, 109)
            estimate = int.from_bytes(alt[0:4], "little", signed=True) if alt and len(alt) >= 6 else None
            check("position estimate follows a 10 m GPS climb in the MSP altitude reply",
                  estimate is not None and 700 <= estimate <= 1300, repr(alt))
            gps.altitude = 545.4
            tuning = msp(sock, 111)
            before = tuning[0] if tuning else None
            receiver.channels[4] = 1811
            time.sleep(2.5)
            receiver.channels[4] = 992
            time.sleep(0.5)
            tuning = msp(sock, 111)
            after = tuning[0] if tuning else None
            check("AUX1 high steps the RC rate up by the adjustment", before is not None and after is not None
                  and 3 <= after - before <= 7, f"{before} {after}")
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
            read = (calendar.timegm((clock[0] | clock[1] << 8, clock[2], clock[3], clock[4], clock[5], clock[6]))
                    if clock is not None and len(clock) == 9 else None)
            check("MSP clock reply holds the date", read is not None and now <= read <= now + 2, repr(clock))
            stamp = time.gmtime(now)
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
            text = cli(vcp, "tasks", 1.5)
            for task, name in (("ALTHOLD", "altitude hold task runs on the position estimate's updates"),
                               ("POSHOLD", "position hold task runs on the position estimate's updates"),
                               ("GPS_RESCUE", "GPS rescue task runs with the rescue as the failsafe procedure")):
                line = next((l for l in text.splitlines() if task in l), "")
                fields = line.split(")")[-1].split()
                rate = int(fields[0]) if fields and fields[0].isdigit() else 0
                check(name, 80 <= rate <= 120, line.strip()[:100])
            time.sleep(5.0)
            try:
                with open(store + ".osd.txt") as f:
                    screen = f.read()
            except OSError:
                screen = ""
            check("OSD draws the craft name", "ADAHOST" in screen, repr(screen[:200]))
            check("OSD draws the date", time.strftime("%Y-%m-%d", stamp) in screen, repr(screen[:200]))
            if built("Menus"):
                receiver.set(992, 1811, 992, 172)
                time.sleep(0.3)
                receiver.set(992, 992, 172, 992)
                time.sleep(1.5)
                try:
                    with open(store + ".osd.txt") as f:
                        screen = f.read()
                except OSError:
                    screen = ""
                check("stick gesture opens the menu", "-- QUICK --" in screen or "-- MAIN --" in screen,
                      repr(screen[:300]))
                # Throttle low with yaw left and pitch down starts a gyro calibration outside a menu, which shows as
                # the calibrating reason among the arming disable flags.
                def calibrating():
                    status = msp(sock, 150)
                    if status is None or len(status) < 21 + status[15]:
                        return False
                    at = 16 + status[15]
                    return bool(int.from_bytes(status[at + 1:at + 5], "little") & 0x1000)
                receiver.set(992, 172, 172, 172)
                started = False
                deadline = time.time() + 2.0
                while time.time() < deadline:
                    started = started or calibrating()
                receiver.set(992, 992, 172, 992)
                time.sleep(0.3)
                check("stick command with the menu open starts no gyro calibration", not started)
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
        # Barometer and compass in the arming logic: the calibrating reason lasts through the barometer's
        # calibration after a start, the gyro calibration sticks level its altitude again, and a compass
        # calibration raises that reason.
        def barometer_arming_checks():
            def disable_flags(link):
                status = msp(link, 150)
                if status is None or len(status) < 21 + status[15]:
                    return None
                at = 16 + status[15]
                return int.from_bytes(status[at + 1:at + 5], "little")

            def calibrating_end(store):
                proc, sock = start(image, store)
                began, last = time.monotonic(), None
                try:
                    while time.monotonic() - began < 6.0:
                        value = disable_flags(sock)
                        if value is not None and value & 0x1000:
                            last = time.monotonic() - began
                        time.sleep(0.1)
                finally:
                    stop(proc)
                    sock.close()
                return last
            store = os.path.join(work, "barocal.bin")
            with_baro = calibrating_end(store)
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set baro_hardware = NONE")
                check("barometer turned off", "baro_hardware set to NONE" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            without = calibrating_end(store)
            check("calibrating reason lasts through the barometer's calibration",
                  with_baro is not None and without is not None and with_baro - without > 0.8,
                  repr((with_baro, without)))
            store = os.path.join(work, "barolevel.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("rx_uart = UART3", "altitude_source = BARO_ONLY"):
                    text = cli(sock, f"set {line}")
                    check(f"barometer levelling setting {line}", line.replace(" = ", " set to ") in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra=sim_link)
            receiver = Receiver()
            receiver.start()
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sim.bind(("127.0.0.1", 9002))
            sim.settimeout(0.5)
            fed = [0]

            def feed_level(seconds):
                # A level craft at rest at 1600 m, in the Gazebo bridge's order.
                for _ in range(int(seconds * 100)):
                    sim.sendto(struct.pack("<18d", fed[0] * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0,
                                           0.0, 0.0, 0.0, -105.25, 40.0, 1600.0, 0.0), ("127.0.0.1", 9003))
                    fed[0] += 1
                    time.sleep(0.01)

            def altitude_cm():
                reply = msp(sock, 109)
                return int.from_bytes(reply[0:4], "little", signed=True) if reply and len(reply) >= 4 else None
            try:
                time.sleep(2.5)
                receiver.set(992, 992, 172, 992)
                feed_level(7.0)
                level = altitude_cm()
                check("virtual barometer reads a fed 1600 m before the stick command",
                      level is not None and abs(level - 160000) <= 500, repr(level))
                receiver.set(992, 172, 172, 172)
                feed_level(0.6)
                receiver.set(992, 992, 172, 992)
                trace = []
                for _ in range(24):
                    feed_level(0.5)
                    level = altitude_cm()
                    trace.append(level)
                    if level is not None and abs(level) <= 500:
                        break
                check("gyro calibration sticks level the barometer's altitude again",
                      level is not None and abs(level) <= 500, repr(trace))
                if built("Compass"):
                    value = disable_flags(sock)
                    check("no calibrating reason before a compass calibration",
                          value is not None and not value & 0x1000, repr(value))
                    msp(sock, 206)
                    feed_level(1.5)
                    value = disable_flags(sock)
                    check("compass calibration raises the calibrating reason",
                          value is not None and bool(value & 0x1000), repr(value))
            finally:
                receiver.stop.set()
                stop(proc)
                sock.close()
                sim.close()
        if built("Barometer"):
            barometer_arming_checks()
        # GPS satellite count on the beeper: with a fix from the virtual GPS, the count's switch sounds one short
        # beep per satellite, which the host's beeper log shows as a group of pulses.
        def satellite_beep_checks():
            store = os.path.join(work, "beepgps.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("feature GPS", "set gps_provider = VIRTUAL", "set rx_uart = UART3",
                             "aux 0 37 1 1700 2100 0 0"):
                    cli(sock, line)
                text = cli(sock, "aux")
                check("satellite count switch set on AUX2", "aux 0 37 1 1700 2100 0 0" in text, text[:200])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra=sim_link)
            receiver = Receiver()
            receiver.start()
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sim.bind(("127.0.0.1", 9002))
            sim.settimeout(0.5)
            sent = [0]

            def feed_fix(seconds):
                for _ in range(int(seconds * 100)):
                    sim.sendto(struct.pack("<18d", sent[0] * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0,
                                           0.0, 0.0, 0.0, -105.25, 40.0, 1600.0, 0.0), ("127.0.0.1", 9003))
                    sent[0] += 1
                    time.sleep(0.01)

            def beeper_log():
                try:
                    with open(store + ".beeper.txt") as f:
                        return [tuple(int(v) for v in line.split(",")) for line in f.read().split()]
                except (OSError, ValueError):
                    return []
            try:
                time.sleep(2.5)
                feed_fix(6.0)
                gps = msp(sock, 106)
                sats = gps[1] if gps and len(gps) > 1 else None
                check("virtual GPS gives twelve satellites for the beeper", gps is not None and gps[0] != 0
                      and sats == 12, repr(gps[:2] if gps else gps))
                before = len(beeper_log())
                receiver.channels = [992, 992, 172, 992, 992, 1811] + [992] * 10
                feed_fix(6.0)
                receiver.channels = [992, 992, 172, 992] + [992] * 12
                feed_fix(1.0)
                starts = [ms for ms, on in beeper_log()[before:] if on == 1]
                groups = []
                for ms in starts:
                    if groups and ms - groups[-1][-1] <= 300:
                        groups[-1].append(ms)
                    else:
                        groups.append([ms])
                sizes = [len(g) for g in groups]
                check("satellite count switch sounds one beep per satellite",
                      len(sizes) >= 2 and all(n == 12 for n in sizes[:-1]), repr(sizes))
            finally:
                receiver.stop.set()
                stop(proc)
                sock.close()
                sim.close()
        if built("GPS"):
            satellite_beep_checks()
        # Headfree offset on the beeper: its switch sets the offset and sounds the beeper with the craft
        # within 45 degrees of level, and stays silent with it rolled further.
        def headfree_offset_checks():
            store = os.path.join(work, "headadj.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("set rx_uart = UART3", "aux 0 7 1 1700 2100 0 0"):
                    cli(sock, line)
                text = cli(sock, "aux")
                check("headfree offset switch set on AUX2", "aux 0 7 1 1700 2100 0 0" in text, text[:200])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra=sim_link)
            receiver = Receiver()
            receiver.start()
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sim.bind(("127.0.0.1", 9002))
            sim.settimeout(0.5)
            sent = [0]

            def feed_roll(seconds, degrees):
                half = math.radians(degrees / 2.0)
                for _ in range(int(seconds * 100)):
                    sim.sendto(struct.pack("<18d", sent[0] * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, math.cos(half),
                                           math.sin(half), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
                               ("127.0.0.1", 9003))
                    sent[0] += 1
                    time.sleep(0.01)

            def beeps():
                try:
                    with open(store + ".beeper.txt") as f:
                        return sum(1 for line in f.read().split() if line.endswith(",1"))
                except OSError:
                    return 0

            def roll_deci():
                reply = msp(sock, 108)
                return int.from_bytes(reply[0:2], "little", signed=True) if reply and len(reply) >= 2 else None
            switch_on = [992, 992, 172, 992, 992, 1811] + [992] * 10
            switch_off = [992, 992, 172, 992] + [992] * 12
            try:
                time.sleep(2.5)
                feed_roll(3.0, 60.0)
                roll = roll_deci()
                check("simulator attitude gives sixty degrees of roll", roll is not None and abs(roll - 600) <= 5,
                      repr(roll))
                before = beeps()
                receiver.channels = switch_on
                feed_roll(2.0, 60.0)
                receiver.channels = switch_off
                feed_roll(0.5, 60.0)
                check("headfree offset switch stays silent beyond 45 degrees", beeps() == before,
                      repr((before, beeps())))
                feed_roll(1.0, 0.0)
                before = beeps()
                receiver.channels = switch_on
                feed_roll(2.0, 0.0)
                receiver.channels = switch_off
                check("headfree offset switch sounds the beeper near level", beeps() > before,
                      repr((before, beeps())))
            finally:
                receiver.stop.set()
                stop(proc)
                sock.close()
                sim.close()
        headfree_offset_checks()
        # DShot beacon before arming: while the beeper switch sends beacon commands, the arm switch arms the
        # craft only 1.2 s after the last one, which the DShot log shows as the time to the first spin direction
        # command.
        def beacon_guard_checks():
            store = os.path.join(work, "beacon.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("set rx_uart = UART3", "aux 0 0 0 1700 2100 0 0", "aux 1 13 1 1700 2100 0 0",
                             "beacon RX_SET"):
                    cli(sock, line)
                text = cli(sock, "beacon")
                check("beacon set for the beeper switch", "RX_SET" not in text.split("Disabled:")[-1], text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra=sim_link)
            receiver = Receiver()
            receiver.start()
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sim.bind(("127.0.0.1", 9002))
            sim.settimeout(0.5)
            done = threading.Event()

            def feed_level():
                tick = 0
                while not done.is_set():
                    sim.sendto(struct.pack("<18d", tick * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0,
                                           0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0), ("127.0.0.1", 9003))
                    tick += 1
                    time.sleep(0.01)

            def counts():
                # Beacon commands of tone 1 and spin direction commands in the DShot log.
                try:
                    with open(store + ".dshot.txt") as f:
                        values = [line.split(",")[1] for line in f.read().split()]
                except (OSError, IndexError):
                    values = []
                return values.count("1"), values.count("20")
            threading.Thread(target=feed_level, daemon=True).start()
            sticks = [992, 992, 172, 992]
            try:
                time.sleep(8.0)
                receiver.channels = sticks + [992, 1811] + [992] * 10
                time.sleep(3.0)
                beacons, spins = counts()
                check("beeper switch sends beacon commands", beacons >= 8, repr(beacons))
                last_beacon, switched, first_spin = None, None, None
                began = time.monotonic()
                while time.monotonic() - began < 6.0 and first_spin is None:
                    now_beacons, now_spins = counts()
                    if now_beacons != beacons:
                        beacons = now_beacons
                        last_beacon = time.monotonic()
                    if switched is not None and now_spins != spins:
                        first_spin = time.monotonic()
                    if switched is None and last_beacon is not None and time.monotonic() - began > 1.0 \
                            and time.monotonic() - last_beacon < 0.03:
                        receiver.channels = sticks + [1811, 1811] + [992] * 10
                        switched = time.monotonic()
                    time.sleep(0.005)
                waited = None if first_spin is None or last_beacon is None else first_spin - last_beacon
                check("arming waits 1.2 s after the last beacon", waited is not None and waited > 1.0, repr(waited))
                time.sleep(0.7)
                status = msp(sock, 150)
                check("craft arms after the beacon guard", status is not None and len(status) > 6 and status[6] & 1 == 1,
                      repr(status))
                receiver.channels = sticks + [992] * 12
                time.sleep(1.0)
            finally:
                done.set()
                receiver.stop.set()
                stop(proc)
                sock.close()
                sim.close()
        beacon_guard_checks()
        # A stall at the start: paused 50 ms between its start-up and its first scheduler pass, as a busy
        # host pauses it, the image still runs its gyro task.
        def start_stall_checks():
            store = os.path.join(work, "stall.bin")
            proc, sock = start(image, store, extra={"ADAFLIGHT_START_STALL_MS": "50"})
            try:
                time.sleep(4.0)
                sock.sendall(b"#")
                read_all(sock, 0.8)

                def gyro_runs():
                    text = cli(sock, "tasks", 1.5)
                    line = next((entry for entry in text.splitlines() if "GYRO)" in entry), "")
                    fields = line.split(")")[-1].split()
                    return (int(fields[7]) if len(fields) > 7 and fields[7].isdigit() else None), line
                first, line = gyro_runs()
                time.sleep(1.0)
                second, line = gyro_runs()
                ran = None if first is None or second is None else (second - first if second >= first else second)
                check("gyro task runs after a stall at the start", ran is not None and ran >= 500, line.strip()[:100])
            finally:
                stop(proc)
                sock.close()
        start_stall_checks()
        # Accelerometer need of the OSD: with no accelerometer calibration stored, a visible artificial horizon
        # or the max G force statistic keeps the craft from arming until one is made.
        def osd_accelerometer_checks():
            store = os.path.join(work, "osdacc.bin")

            def reasons_then(lines):
                # The arming disable reasons of this start, then the settings for the next one.
                proc, sock = start(image, store)
                try:
                    time.sleep(5.0)
                    sock.sendall(b"#")
                    read_all(sock, 0.8)
                    text = cli(sock, "status", 1.5)
                    for line in lines:
                        reply = cli(sock, f"set {line}")
                        check(f"OSD accelerometer setting {line}", line.replace(" = ", " set to ") in reply, reply[-120:])
                    if lines:
                        cli(sock, "save", wait=2.0)
                        proc.wait(timeout=10)
                    return text.split("Arming disable flags:")[-1]
                finally:
                    stop(proc)
                    sock.close()
            reasons = reasons_then(["osd_ah_pos = 2177"])
            check("no accelerometer calibration reason on a fresh configuration", "NO_ACC_CAL" not in reasons,
                  reasons.strip()[:80])
            reasons = reasons_then(["osd_ah_pos = 234", "osd_stat_bitmask = 16384"])
            check("visible artificial horizon asks for an accelerometer calibration", "NO_ACC_CAL" in reasons,
                  reasons.strip()[:80])
            reasons = reasons_then(["osd_stat_bitmask = 0"])
            check("max G force statistic asks for an accelerometer calibration", "NO_ACC_CAL" in reasons,
                  reasons.strip()[:80])
            reasons = reasons_then([])
            check("no accelerometer calibration reason without that element and statistic",
                  "NO_ACC_CAL" not in reasons, reasons.strip()[:80])
        osd_accelerometer_checks()
        # OSD warnings from the beeper: its visual mark while the beeper switch beeps and no mark after it, then
        # the beacon notice and the time to arming while the arming guard after a beacon runs.
        def osd_beeper_warning_checks():
            store = os.path.join(work, "osdbeep.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("set rx_uart = UART3", "aux 0 0 0 1700 2100 0 0", "aux 1 13 1 1700 2100 0 0",
                             "beacon RX_SET", "set osd_displayport_device = MAX7456", "set vcd_video_system = PAL"):
                    cli(sock, line)
                text = cli(sock, "set osd_warnings_pos = 2314")
                check("warnings line placed on a free row", "osd_warnings_pos set to 2314" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra=sim_link)
            receiver = Receiver()
            receiver.start()
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sim.bind(("127.0.0.1", 9002))
            sim.settimeout(0.5)
            done = threading.Event()

            def feed_level():
                tick = 0
                while not done.is_set():
                    sim.sendto(struct.pack("<18d", tick * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0,
                                           0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0), ("127.0.0.1", 9003))
                    tick += 1
                    time.sleep(0.01)

            def warnings_row():
                try:
                    with open(store + ".osd.txt") as f:
                        lines = f.read().splitlines()
                except OSError:
                    lines = []
                return lines[8].strip() if len(lines) > 8 else ""

            def row_states(seconds):
                seen = []
                end = time.monotonic() + seconds
                while time.monotonic() < end:
                    now = warnings_row()
                    if now and now not in seen:
                        seen.append(now)
                    time.sleep(0.02)
                return seen
            threading.Thread(target=feed_level, daemon=True).start()
            sticks = [992, 992, 172, 992]
            try:
                time.sleep(8.0)
                receiver.channels = sticks + [992, 1811] + [992] * 10
                states = row_states(3.0)
                check("warnings line shows the visual beeper's whole mark", any("* * * *" in s for s in states),
                      repr(states))
                check("screen file never shows a part of that mark", all("* * * *" in s for s in states if "*" in s),
                      repr(states))
                receiver.channels = sticks + [992] * 12
                time.sleep(0.5)
                check("visual beeper's mark clears after the beeps", "*" not in warnings_row(), repr(warnings_row()))
                # A loaded host can starve the image or the stick frames for a moment, which blocks the arming for
                # another reason, so the attempt repeats, up to three times, until both of the guard's lines show.
                for attempt in range(3):
                    receiver.channels = sticks + [992, 1811] + [992] * 10
                    time.sleep(2.0)
                    receiver.channels = sticks + [1811, 1811] + [992] * 10
                    states = row_states(2.5)
                    receiver.channels = sticks + [992] * 12
                    time.sleep(1.0)
                    if (any("BEACON ON" in s for s in states)
                            and any(re.search(r"ARM IN 0\.[1-9]", s) for s in states)):
                        break
                check("warnings line shows the beacon notice during the arming guard",
                      any("BEACON ON" in s for s in states), repr(states))
                check("warnings line counts down to arming",
                      any(re.search(r"ARM IN 0\.[1-9]", s) for s in states), repr(states))
            finally:
                done.set()
                receiver.stop.set()
                stop(proc)
                sock.close()
                sim.close()
        osd_beeper_warning_checks()
        # Simulator rate after a gap: fed exactly two flight dynamics packets, the image still answers MSP.
        def simulator_gap_checks():
            store = os.path.join(work, "simgap.bin")
            proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                time.sleep(2.5)
                for stamp in (0.0, 0.01):
                    sim.sendto(struct.pack("<18d", stamp, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0,
                                           0.0, 0.0, 0.0, 0.0, 0.0, 0.0), ("127.0.0.1", 9003))
                    time.sleep(0.01)
                time.sleep(0.3)
                check("image answers MSP after two simulator packets", msp(sock, 108) is not None)
            finally:
                stop(proc)
                sock.close()
                sim.close()
        simulator_gap_checks()
        # Battery profile on the OSD: the battery profile name element shows the selected profile's number and
        # then its name.
        def osd_battery_profile_checks():
            store = os.path.join(work, "osdbat.bin")

            def element_then(lines):
                # The element's row of this start, then the commands for the next one.
                proc, sock = start(image, store)
                try:
                    time.sleep(5.0)
                    try:
                        with open(store + ".osd.txt") as f:
                            rows = f.read().splitlines()
                    except OSError:
                        rows = []
                    sock.sendall(b"#")
                    read_all(sock, 0.8)
                    for line in lines:
                        cli(sock, line)
                    if lines:
                        cli(sock, "save", wait=2.0)
                        proc.wait(timeout=10)
                    return rows[8].strip() if len(rows) > 8 else ""
                finally:
                    stop(proc)
                    sock.close()
            element_then(["set osd_displayport_device = MAX7456", "set vcd_video_system = PAL",
                          "set osd_battery_profile_name_pos = 2314", "battery_profile 1"])
            shown = element_then(["set battery_profile_name = PACKB"])
            check("battery profile name element shows the second profile's number", shown == "BAT2", repr(shown))
            shown = element_then([])
            check("battery profile name element shows the profile's name", shown == "PACKB", repr(shown))
        osd_battery_profile_checks()
        # Arming disable reasons on the OSD: after a runaway takeoff disarm the warnings line stays in place of
        # the statistics page.
        def osd_runaway_warning_checks():
            store = os.path.join(work, "osdrun.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("set rx_uart = UART3", "aux 0 0 0 1700 2100 0 0", "set osd_displayport_device = MAX7456",
                             "set vcd_video_system = PAL", "set osd_warnings_pos = 2314"):
                    cli(sock, line)
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra=sim_link)
            receiver = Receiver()
            receiver.start()
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            done = threading.Event()
            roll_rate = [0.0]

            def feed_rate():
                tick = 0
                while not done.is_set():
                    sim.sendto(struct.pack("<18d", tick * 0.01, roll_rate[0], 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0,
                                           0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0), ("127.0.0.1", 9003))
                    tick += 1
                    time.sleep(0.01)

            def armed_and_reasons():
                status = msp(sock, 150)
                if status is None or len(status) < 21 + status[15]:
                    return None, 0
                at = 16 + status[15]
                return status[6] & 1, int.from_bytes(status[at + 1:at + 5], "little")
            threading.Thread(target=feed_rate, daemon=True).start()
            sticks = [992, 992, 172, 992]
            try:
                time.sleep(8.0)
                receiver.channels = sticks + [1811] + [992] * 11
                time.sleep(1.5)
                check("craft arms before the runaway", armed_and_reasons()[0] == 1, repr(armed_and_reasons()))
                # Ten radians a second of roll with the sticks centred, as a craft that runs away at takeoff.
                roll_rate[0] = 10.0
                time.sleep(0.6)
                roll_rate[0] = 0.0
                time.sleep(0.4)
                armed, reasons = armed_and_reasons()
                check("runaway takeoff disarms and keeps arming disabled", armed == 0 and reasons & 0x20 != 0,
                      repr((armed, hex(reasons))))
                time.sleep(2.0)
                try:
                    with open(store + ".osd.txt") as f:
                        lines = [entry.strip() for entry in f.read().splitlines() if entry.strip()]
                except OSError:
                    lines = []
                check("warnings line stays in place of the statistics page after a runaway",
                      lines == ["RUNAWAY"], repr(lines))
                receiver.channels = sticks + [992] * 12
                time.sleep(1.0)
            finally:
                done.set()
                receiver.stop.set()
                stop(proc)
                sock.close()
                sim.close()
        osd_runaway_warning_checks()
        # Barometer over iBus telemetry: the temperature and pressure sensors read the barometer's values, and
        # the altitude sensor its altitude, here the virtual barometer's under a simulator link.
        def ibus_barometer_checks():
            store = os.path.join(work, "ibusbaro.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("feature TELEMETRY", "set telemetry_1_protocol = IBUS", "set telemetry_1_uart = UART3"):
                    cli(sock, line)
                text = cli(sock, "set ibus_sensor = 1,65,131,0,0,0,0,0,0,0,0,0,0,0,0")
                check("iBus temperature, pressure and altitude sensors set", "ibus_sensor set to 1,65,131" in text,
                      text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()

            def sensor_value(address):
                line = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
                line.settimeout(0.3)
                try:
                    reply = b""
                    for command in (0x80, 0x90, 0xA0):
                        line.sendall(ibus_request(command, address))
                        reply = read_all(line, 0.3)
                        line.sendall(reply)
                        time.sleep(0.05)
                finally:
                    line.close()
                return int.from_bytes(reply[2:-2], "little") if len(reply) >= 6 else None
            proc, sock = start(image, store)
            try:
                time.sleep(6.0)
                # The host's BMP280 reads 25.08 degrees and 100653 Pa; the sensor adds 40 degrees in tenths.
                value = sensor_value(1)
                check("iBus temperature sensor reads the barometer's temperature", value == 651, repr(value))
                value = sensor_value(2)
                check("iBus pressure sensor reads the barometer's pressure with its temperature",
                      value is not None and abs((value & 0x7FFFF) - 100653) <= 5 and value >> 19 == 651, repr(value))
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                time.sleep(2.5)
                for i in range(600):
                    sim.sendto(struct.pack("<18d", i * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0,
                                           0.0, 0.0, -105.25, 40.0, 1600.0, 0.0), ("127.0.0.1", 9003))
                    time.sleep(0.01)
                # The first address asked becomes the sensors' base, so the first sensor is asked first.
                sensor_value(1)
                value = sensor_value(3)
                check("iBus altitude sensor reads the virtual barometer's 1600 m",
                      value is not None and abs(value - 160000) <= 500, repr(value))
            finally:
                stop(proc)
                sock.close()
                sim.close()
        if built("IBus_Telemetry") and built("Barometer"):
            ibus_barometer_checks()
        # Flight plan executor: with a stored waypoint the autopilot switch engages the executor with the altitude
        # and position holds, a leg flown to the waypoint completes it with its OSD warning, and the switch's release
        # ends the mode. With the policy that flies a mission on, a lost link leaves the mission flying in the
        # failsafe mode, and its end hands over to the failsafe's procedure, which disarms. The simulator's bridge
        # mirrors a fed position about its first packet, so a falling latitude flies north. Each part starts the
        # image afresh, since the executor's debug values stay as its last update left them. The screen shows the
        # plan's elements: the waypoint's number, the distance and the time to it, the flight mode, and the map with
        # the waypoint's marker and the flown trail.
        def flight_plan_flight_checks():
            store = os.path.join(work, "planfly.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                if 16427 not in {int(w) for w in cli(sock, "options").split() if w.isdigit()}:
                    print("SKIP the flight plan's flight checks: the build leaves the flight plan out")
                    return
                for line in ("feature -RX_SERIAL", "feature RX_UDP", "set motor_pwm_protocol = PWM",
                             "aux 0 0 0 1700 2100 0 0", "aux 1 56 1 1700 2100 0 0", "feature GPS",
                             "set gps_provider = VIRTUAL", "set altitude_source = BARO_ONLY",
                             "set osd_warn_bitmask = 0", "set debug_mode = FLIGHT_PLAN",
                             "set osd_displayport_device = MAX7456", "set vcd_video_system = PAL",
                             "set osd_wp_number_pos = 2049", "set osd_wp_distance_pos = 2081",
                             "set osd_wp_direction_pos = 2113", "set osd_wp_eta_pos = 2145",
                             "set osd_flymode_pos = 2177", "set osd_nav_map_pos = 2255"):
                    cli(sock, line)
                text = cli(sock, "set ap_rx_loss_policy = CONTINUE")
                check("policy that flies a mission on under a lost link set",
                      "ap_rx_loss_policy set to CONTINUE" in text, text[-120:])
                text = cli(sock, "waypoint insert 0 40.0002000 -105.2500000 162000 500 FLYOVER 0 NONE")
                check("waypoint 22 m north of the start stored", "waypoint insert 0 40.0002000" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()

            # The image started, armed with a raised throttle, and the autopilot switch on; then the part's own
            # checks, which fly the leg in steps of 1.1 m with a matching northward velocity.
            def flown(part, body, settings):
                proc, sock = start(image, settings, extra=sim_link)
                done = threading.Event()
                with_sticks = threading.Event()
                with_sticks.set()
                pulses = [1500, 1500, 1000, 1500] + [1000] * 12
                place = [-105.25, 40.0, 1600.0]
                north = [0.0]
                turn = [1.0, 0.0]

                def feed():
                    out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    tick = 0
                    while not done.is_set():
                        out.sendto(struct.pack("<18d", tick * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, turn[0], 0.0, 0.0,
                                               turn[1], 0.0, north[0], 0.0, place[0], place[1], place[2], 0.0),
                                   ("127.0.0.1", 9003))
                        if tick % 2 == 0 and with_sticks.is_set():
                            out.sendto(struct.pack("<d16H", tick * 0.01, *pulses), ("127.0.0.1", 9004))
                        tick += 1
                        time.sleep(0.01)
                    out.close()

                def state():
                    status = msp(sock, 150)
                    values = msp(sock, 254)
                    if status is None or len(status) < 21 + status[15] or values is None or len(values) < 6:
                        return None
                    at = 16 + status[15]
                    flags = int.from_bytes(status[6:10], "little")
                    flags |= int.from_bytes(status[16:at], "little") << 32
                    return flags, struct.unpack("<3h", values[:6]), int.from_bytes(status[at + 1:at + 5], "little")

                def screen():
                    try:
                        with open(settings + ".osd.txt") as f:
                            return f.read().splitlines()
                    except OSError:
                        return []

                def fly(first, last):
                    north[0] = 3.7
                    for step in range(first, last + 1):
                        place[1] = 40.0 - 0.00001 * step
                        time.sleep(0.3)
                    north[0] = 0.0
                try:
                    time.sleep(2.5)
                    threading.Thread(target=feed, daemon=True).start()
                    time.sleep(7.0)
                    msp(sock, 205)
                    time.sleep(4.0)
                    ids = list(msp(sock, 119) or b"")
                    arm, alt_hold, pos_hold, failsafe, autopilot = (1 << ids.index(i) if i in ids else 0
                                                                    for i in (0, 3, 11, 27, 56))
                    check(f"boxes of arming, both holds, failsafe and the autopilot exist for the {part}",
                          arm and alt_hold and pos_hold and failsafe and autopilot, repr(ids))
                    pulses[4] = 1800
                    armed, value = until(state, lambda s: s is not None and s[0] & arm, wait=8.0)
                    check(f"craft arms for the {part}", armed, repr(value))
                    pulses[2] = 1400
                    place[2] += 20.0
                    time.sleep(4.0)
                    pulses[5] = 1800
                    holds = arm | alt_hold | pos_hold | autopilot
                    engaged, value = until(state, lambda s: s is not None and s[0] & holds == holds
                                           and s[1] == (1, 0, 0), wait=5.0)
                    check(f"autopilot switch engages the executor with both holds for the {part}", engaged,
                          repr(value))
                    body(sock, state, fly, pulses, with_sticks, arm, failsafe, autopilot, holds, place, screen, turn)
                    pulses[4] = 1000
                    time.sleep(1.0)
                finally:
                    done.set()
                    stop(proc)
                    sock.close()

            def switch_part(sock, state, fly, pulses, with_sticks, arm, failsafe, autopilot, holds, place, screen, turn):
                # The elements' rows: the number at 0, the distance at 1, the direction at 2, the time at 3, the
                # flight mode at 4, and the map from 6 with its inside from column 16.
                def row(n):
                    lines = screen()
                    return lines[n].strip() if len(lines) > n else ""

                def metres():
                    found = re.match(r"(\d+)", row(1))
                    return int(found.group(1)) if found else None
                shown, value = until(lambda: (row(0), metres(), row(4)),
                                     lambda v: v[0] == "WP1/1" and v[1] is not None and 18 <= v[1] <= 24
                                     and v[2] == "POSH", wait=3.0)
                check("screen names the waypoint, its distance of 22 m and the position hold mode", shown, repr(value))
                marked, value = until(lambda: [line[16:28] for line in screen()[7:13]],
                                      lambda rows: any("1" in r for r in rows), wait=3.0)
                check("map marks the plan's waypoint", marked, repr(value))
                frames = set()
                end = time.monotonic() + 2.5
                while time.monotonic() < end:
                    frames.add(any("1" in line[16:28] for line in screen()[7:13]))
                    time.sleep(0.05)
                check("marker of the waypoint under way blinks", frames == {True, False}, repr(frames))
                fly(1, 10)
                value = (metres(), row(2), row(3))
                check("distance, direction and time to the waypoint follow the leg",
                      value[0] is not None and 4 <= value[0] <= 17 and value[1] not in ("", "-")
                      and re.fullmatch(r"\d\d:\d\d", value[2]) is not None, repr(value))

                def craft():
                    for line in screen()[7:13]:
                        for mark in line[16:28]:
                            if mark not in " .+1":
                                return mark
                    return None
                northward = craft()
                fly(11, 20)
                reached, value = until(state, lambda s: s is not None and s[1] == (3, 0, 0), wait=6.0)
                check("leg flown to the waypoint completes the plan", reached, repr(value))
                cleared, value = until(lambda: row(1), lambda r: r == "-", wait=3.0)
                check("screen shows no distance once the plan is complete", cleared, repr(value))
                named, shown = until(lambda: msp2(sock, 0x3005), lambda r: r is not None and b"WP COMPLETE" in r,
                                     wait=4.0)
                check("OSD warning names the completed plan", named, repr(shown))
                value = state()
                check("completed plan leaves the craft armed in the autopilot mode",
                      value is not None and value[0] & holds == holds, repr(value))
                pulses[5] = 1000
                released, value = until(state, lambda s: s is not None and s[0] & arm and not s[0] & autopilot,
                                        wait=3.0)
                check("switch's release ends the autopilot mode", released, repr(value))
                turn[0], turn[1] = 0.7071068, 0.7071068
                for step in range(1, 13):
                    place[0] = -105.25 - 0.0000586 * step
                    time.sleep(0.4)
                trailed, value = until(lambda: screen()[8] if len(screen()) > 8 else "",
                                       lambda r: re.search(r"1\.{3}[^ .] *$", r[16:28]) is not None, wait=4.0)
                check("map draws the trail of a 60 m flight east of the waypoint, up to the craft's mark", trailed,
                      repr(value))
                eastward = craft()
                check("map turns the craft's mark with its heading",
                      northward is not None and eastward is not None and eastward != northward,
                      repr((northward, eastward)))
                pulses[4] = 1000
                until(state, lambda s: s is not None and not s[0] & arm, wait=3.0)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "waypoint status")
                check("waypoint status reports the executor inactive after the switch's release",
                      "Runtime status:" in text and "inactive" in text.split("Runtime status:")[-1], text[-160:])

            def link_part(sock, state, fly, pulses, with_sticks, arm, failsafe, autopilot, holds, place, screen, turn):
                fly(1, 8)
                with_sticks.clear()
                flying = arm | failsafe | autopilot
                kept, value = until(state, lambda s: s is not None and s[0] & flying == flying and s[1] == (1, 0, 0),
                                    wait=5.0)
                check("lost link leaves the mission flying in the failsafe mode", kept, repr(value))
                fly(9, 14)
                value = state()
                check("mission flies on short of its waypoint", value is not None and value[0] & flying == flying,
                      repr(value))
                fly(15, 20)
                dropped, value = until(state, lambda s: s is not None and not s[0] & arm, wait=8.0)
                check("mission's end under a lost link hands over to the failsafe's procedure, which disarms",
                      dropped, repr(value))

            # A second waypoint 22 m past the first: the executor goes on to it, and the screen counts it.
            def advance_part(sock, state, fly, pulses, with_sticks, arm, failsafe, autopilot, holds, place, screen, turn):
                mav = None
                if contains("MAVLink_Telemetry"):
                    mav = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
                    mav.settimeout(0.3)
                fly(1, 20)
                advanced, value = until(state, lambda s: s is not None and s[1] == (1, 0, 1), wait=6.0)
                check("executor goes on to the plan's second waypoint", advanced, repr(value))
                counted, value = until(lambda: screen()[0].strip() if screen() else "", lambda r: r == "WP2/2", wait=3.0)
                check("screen counts the second waypoint of two", counted, repr(value))
                if mav is not None:
                    frames = mavlink_exchange(mav, b"", 2.0)
                    mav.close()
                    check("MAVLink reports the first waypoint reached",
                          any(m == 46 and p[0] | p[1] << 8 == 0 for m, p in frames),
                          repr(sorted({m for m, _ in frames})))
                    check("MAVLink mission current names the second waypoint of an active mission",
                          any(m == 42 and p[0] | p[1] << 8 == 1 and p[5] == 1 for m, p in frames),
                          repr([bytes(p[:6]).hex() for m, p in frames if m == 42][-3:]))

            flown("flight plan", switch_part, store)
            flown("mission under a lost link", link_part, store)
            longer = os.path.join(work, "planfly2.bin")
            with open(store, "rb") as saved, open(longer, "wb") as copy:
                copy.write(saved.read())
            proc, sock = start(image, longer, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "waypoint insert 1 40.0004000 -105.2500000 162000 500 FLYOVER 0 NONE")
                check("second waypoint 22 m past the first stored", "waypoint insert 1 40.0004000" in text, text[-120:])
                if contains("MAVLink_Telemetry"):
                    for line in ("feature TELEMETRY", "set telemetry_1_protocol = MAVLINK",
                                 "set telemetry_1_uart = UART3"):
                        cli(sock, line)
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            flown("plan of two waypoints", advance_part, longer)
        if built("GPS"):
            flight_plan_flight_checks()
        # Rescue plans: with the GPS rescue as the failsafe procedure, lost stick packets stage a rescue plan that
        # the autopilot flies in the failsafe mode past the landing time, the link's return with centred sticks
        # leaves it flying, and a stick movement ends it. The rescue switch flies a rescue plan without the failsafe
        # mode. No waypoint is stored, so an executor that targets one flies a staged rescue plan, and each part
        # starts the image afresh, since the executor's debug values stay as its last update left them.
        def rescue_plan_checks():
            store = os.path.join(work, "rescueplan.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                if 16427 not in {int(w) for w in cli(sock, "options").split() if w.isdigit()}:
                    print("SKIP the rescue plan checks: the build leaves the flight plan out")
                    return
                for line in ("feature -RX_SERIAL", "feature RX_UDP", "set motor_pwm_protocol = PWM",
                             "aux 0 0 0 1700 2100 0 0", "aux 1 46 1 1700 2100 0 0", "feature GPS",
                             "set gps_provider = VIRTUAL", "set altitude_source = BARO_ONLY",
                             "set failsafe_landing_time = 3", "set debug_mode = FLIGHT_PLAN",
                             "set osd_displayport_device = MAX7456", "set vcd_video_system = PAL",
                             "set osd_flymode_pos = 2177"):
                    cli(sock, line)
                text = cli(sock, "set failsafe_procedure = GPS-RESCUE")
                check("GPS rescue set as the failsafe procedure of a build with rescue plans",
                      "failsafe_procedure set to GPS-RESCUE" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()

            # The image started, armed with a raised throttle, at a place 111 m from home and 30 m up, for a rescue
            # that has somewhere to go; then the part's own checks.
            sock_of = [None]
            screen_of = [None]

            def flown(part, body, settings):
                proc, sock = start(image, settings, extra=sim_link)
                sock_of[0] = sock
                screen_of[0] = settings + ".osd.txt"
                done = threading.Event()
                with_sticks = threading.Event()
                with_sticks.set()
                pulses = [1500, 1500, 1000, 1500] + [1000] * 12
                place = [-105.25, 40.0, 1600.0]

                def feed():
                    out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    tick = 0
                    while not done.is_set():
                        out.sendto(struct.pack("<18d", tick * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0,
                                               0.0, 0.0, 0.0, place[0], place[1], place[2], 0.0), ("127.0.0.1", 9003))
                        if tick % 2 == 0 and with_sticks.is_set():
                            out.sendto(struct.pack("<d16H", tick * 0.01, *pulses), ("127.0.0.1", 9004))
                        tick += 1
                        time.sleep(0.01)
                    out.close()

                def state():
                    status = msp(sock, 150)
                    values = msp(sock, 254)
                    if status is None or len(status) < 16 + status[15] or values is None or len(values) < 6:
                        return None
                    flags = int.from_bytes(status[6:10], "little")
                    flags |= int.from_bytes(status[16:16 + status[15]], "little") << 32
                    return flags, struct.unpack("<3h", values[:6])
                try:
                    time.sleep(2.5)
                    threading.Thread(target=feed, daemon=True).start()
                    time.sleep(7.0)
                    msp(sock, 205)
                    time.sleep(4.0)
                    ids = list(msp(sock, 119) or b"")
                    arm, failsafe, rescue, autopilot = (1 << ids.index(i) if i in ids else 0 for i in (0, 27, 46, 56))
                    check(f"boxes of arming, failsafe, GPS rescue and the autopilot exist for the {part}",
                          arm and failsafe and rescue and autopilot, repr(ids))
                    pulses[4] = 1800
                    armed, value = until(state, lambda s: s is not None and s[0] & arm, wait=8.0)
                    check(f"craft arms for the {part}", armed, repr(value))
                    pulses[2] = 1400
                    place[1] -= 0.001
                    place[2] += 30.0
                    time.sleep(4.0)
                    value = state()
                    check(f"executor is idle before the {part}",
                          value is not None and value[1] == (0, 0, 0) and not value[0] & autopilot, repr(value))
                    alt_hold = 1 << ids.index(3) if 3 in ids else 0
                    body(state, pulses, with_sticks, place, arm, failsafe, rescue, autopilot, alt_hold)
                    pulses[4] = 1000
                    time.sleep(1.0)
                finally:
                    done.set()
                    stop(proc)
                    sock.close()

            def failsafe_part(state, pulses, with_sticks, place, arm, failsafe, rescue, autopilot, alt_hold):
                flying = arm | failsafe | autopilot
                with_sticks.clear()
                staged, value = until(state, lambda s: s is not None and s[0] & flying == flying and not s[0] & rescue
                                      and s[1] == (1, 0, 0), wait=5.0)
                check("lost link flies a staged rescue plan in the failsafe mode, without the rescue mode", staged,
                      repr(value))

                def mode_row():
                    try:
                        with open(store + ".osd.txt") as f:
                            lines = f.read().splitlines()
                    except OSError:
                        lines = []
                    return lines[4].strip() if len(lines) > 4 else ""
                named, value = until(mode_row, lambda r: r == "N-RESC", wait=3.0)
                check("screen's flight mode names the rescue plan ahead of the failsafe", named, repr(value))
                time.sleep(4.5)
                value = state()
                check("rescue plan outlasts the failsafe's landing time",
                      value is not None and value[0] & flying == flying, repr(value))
                with_sticks.set()
                time.sleep(2.0)
                value = state()
                check("link's return with centred sticks leaves the rescue plan flying",
                      value is not None and value[0] & autopilot and value[0] & arm, repr(value))
                pulses[0] = 1800
                ended, value = until(state, lambda s: s is not None and s[0] & arm
                                     and not s[0] & (autopilot | failsafe), wait=3.0)
                check("stick movement ends the rescue plan", ended, repr(value))
                pulses[0] = 1500
                time.sleep(0.5)

            def switch_part(state, pulses, with_sticks, place, arm, failsafe, rescue, autopilot, alt_hold):
                pulses[5] = 1800
                switched, value = until(state, lambda s: s is not None and s[0] & arm and s[0] & autopilot
                                        and not s[0] & failsafe and s[1] == (1, 0, 0), wait=4.0)
                check("rescue switch flies a staged rescue plan without the failsafe mode", switched, repr(value))
                pulses[5] = 1000
                released, value = until(state, lambda s: s is not None and s[0] & arm and not s[0] & autopilot,
                                        wait=3.0)
                check("rescue switch's release ends that plan", released, repr(value))

            # A latitude out of range stops the virtual GPS, so the position estimate lapses and the plan aborts.
            # The switch then asks for the descent: the altitude hold alone, with the rescue's failure warning and
            # a target below the craft, which this part reads from the autopilot's altitude debug values.
            def descent_part(state, pulses, with_sticks, place, arm, failsafe, rescue, autopilot, alt_hold):
                pulses[5] = 1800
                switched, value = until(state, lambda s: s is not None and s[0] & autopilot, wait=4.0)
                check("rescue switch flies a rescue plan before the abort", switched, repr(value))
                time.sleep(1.0)
                before = state()
                place[1] = 91.5
                descending, value = until(state, lambda s: s is not None and s[0] & arm and s[0] & alt_hold
                                          and not s[0] & autopilot, wait=8.0)
                check("aborted rescue plan leaves the altitude hold without the autopilot mode", descending,
                      repr(value))
                named, shown = until(lambda: msp2(sock_of[0], 0x3005), lambda r: r is not None and b"RESCUE FAIL" in r,
                                     wait=4.0)
                try:
                    with open(screen_of[0]) as f:
                        rows = [line.rstrip() for line in f.read().splitlines() if line.strip()][:6]
                except OSError:
                    rows = []
                check("OSD warning names the rescue's failure during the descent", named,
                      repr((shown, state(), rows)))
                # The debug values are the throttle, the target and the altitude, in centimetres. The fed altitude
                # never falls, so the target stops a little below it.
                lowered, value = until(state, lambda s: s is not None and s[1][1] < s[1][2] - 100, wait=4.0)
                check("altitude hold's target goes below the craft in the rescue descent",
                      lowered and before is not None and before[1][1] >= before[1][2] - 100, repr((before, value)))
                pulses[5] = 1000
                released, value = until(state, lambda s: s is not None and s[0] & arm and not s[0] & alt_hold,
                                        wait=3.0)
                check("rescue switch's release ends the descent", released, repr(value))

            flown("failsafe's rescue plan", failsafe_part, store)
            flown("rescue switch", switch_part, store)
            altitude_store = os.path.join(work, "rescuedescent.bin")
            with open(store, "rb") as saved, open(altitude_store, "wb") as copy:
                copy.write(saved.read())
            proc, sock = start(image, altitude_store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set debug_mode = AUTOPILOT_ALTITUDE")
                check("debug mode set to the autopilot's altitude for the descent",
                      "debug_mode set to AUTOPILOT_ALTITUDE" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            flown("rescue descent", descent_part, altitude_store)
        if built("GPS"):
            rescue_plan_checks()
        # Waypoint capture: a short press of its switch stores the GPS position as the plan's next waypoint, a
        # press held past a second and a half deletes the last one, and the OSD warning line shows each message
        # for a while, over MSP and on the screen. A switch that the receiver failsafe substitutes during a lost
        # link edits nothing, and neither does a press while the executor flies the plan.
        def waypoint_capture_checks():
            store = os.path.join(work, "capture.bin")
            sim_link = {"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"}
            proc, sock = start(image, store, extra=sim_link)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                if 16427 not in {int(w) for w in cli(sock, "options").split() if w.isdigit()}:
                    print("SKIP the waypoint capture checks: the build leaves the flight plan out")
                    return
                for line in ("feature -RX_SERIAL", "feature RX_UDP", "set motor_pwm_protocol = PWM",
                             "aux 0 57 1 1700 2100 0 0", "aux 1 0 0 1700 2100 0 0", "aux 2 56 2 1700 2100 0 0",
                             "feature GPS", "set gps_provider = VIRTUAL", "set altitude_source = BARO_ONLY",
                             "set osd_warn_bitmask = 0", "set osd_displayport_device = MAX7456",
                             "set vcd_video_system = PAL", "set osd_warnings_pos = 2314",
                             "set debug_mode = FLIGHT_PLAN"):
                    cli(sock, line)
                text = cli(sock, "rxfail 5 s 1800")
                check("receiver failsafe set to substitute the capture switch's channel", "rxfail 5 s 1800" in text,
                      text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()

            def flown(body):
                proc, sock = start(image, store, extra=sim_link)
                done = threading.Event()
                with_sticks = threading.Event()
                with_sticks.set()
                pulses = [1500, 1500, 1000, 1500] + [1000] * 12
                place = [-105.25, 40.0, 1600.0]

                def feed():
                    out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    tick = 0
                    while not done.is_set():
                        out.sendto(struct.pack("<18d", tick * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0,
                                               0.0, 0.0, 0.0, place[0], place[1], place[2], 0.0), ("127.0.0.1", 9003))
                        if tick % 2 == 0 and with_sticks.is_set():
                            out.sendto(struct.pack("<d16H", tick * 0.01, *pulses), ("127.0.0.1", 9004))
                        tick += 1
                        time.sleep(0.01)
                    out.close()

                def warning():
                    return msp2(sock, 0x3005)

                def listed():
                    sock.sendall(b"#")
                    read_all(sock, 0.8)
                    return [line for line in cli(sock, "waypoint").splitlines() if line.startswith("waypoint insert")]
                try:
                    time.sleep(2.5)
                    threading.Thread(target=feed, daemon=True).start()
                    time.sleep(7.0)
                    fix = msp(sock, 106)
                    check("virtual GPS has a fix for the capture", fix is not None and fix[0] != 0,
                          repr(fix and fix[:2]))
                    body(sock, pulses, with_sticks, place, warning, listed)
                finally:
                    done.set()
                    stop(proc)
                    sock.close()

            def press(pulses, seconds):
                pulses[5] = 1800
                time.sleep(seconds)
                pulses[5] = 1000

            def gesture_part(sock, pulses, with_sticks, place, warning, listed):
                def screen_row():
                    try:
                        with open(store + ".osd.txt") as f:
                            lines = f.read().splitlines()
                    except OSError:
                        lines = []
                    return lines[8].strip() if len(lines) > 8 else ""
                press(pulses, 0.5)
                drawn, row = until(screen_row, lambda r: "WP1 SET" in r, wait=3.0)
                check("short press of the capture switch stores a waypoint, named on the screen's warnings row", drawn,
                      repr(row))
                shown, text = until(warning, lambda r: r is not None and b"WP1 SET" in r, wait=2.0)
                check("MSP warnings reply names the stored waypoint too", shown, repr(text))
                gone, text = until(warning, lambda r: r is not None and b"WP1 SET" not in r, wait=5.0)
                check("capture's message leaves the OSD after a while", gone, repr(text))
                press(pulses, 0.5)
                shown, text = until(warning, lambda r: r is not None and b"WP2 SET" in r, wait=3.0)
                check("second press stores a second waypoint", shown, repr(text))
                pulses[5] = 1800
                shown, text = until(warning, lambda r: r is not None and b"WP2 DELETED" in r, wait=4.0)
                check("press held past a second and a half deletes the last waypoint", shown, repr(text))
                pulses[5] = 1000
                until(warning, lambda r: r is not None and b"WP" not in r, wait=5.0)
                with_sticks.clear()
                edited, text = until(warning, lambda r: r is not None and b"WP" in r, wait=3.5)
                with_sticks.set()
                time.sleep(1.0)
                check("capture switch substituted during a lost link edits nothing", not edited, repr(text))
                lines = listed()
                check("plan keeps the first captured waypoint at the GPS position as a fly-by",
                      len(lines) == 1 and lines[0].startswith("waypoint insert 0 40.0000000 -105.2500000 160000 0 FLYBY"),
                      repr(lines))
                cli(sock, "save", wait=2.0)

            # The captured waypoint saved by the part before; the craft armed 22 m north of it and 20 m up, with the
            # autopilot on.
            def flying_part(sock, pulses, with_sticks, place, warning, listed):
                def modes():
                    status = msp(sock, 150)
                    if status is None or len(status) < 16 + status[15]:
                        return None
                    return int.from_bytes(status[6:10], "little") | int.from_bytes(status[16:16 + status[15]], "little") << 32
                def executor():
                    values = msp(sock, 254)
                    return struct.unpack("<3h", values[:6]) if values and len(values) >= 6 else None
                msp(sock, 205)
                time.sleep(4.0)
                ids = list(msp(sock, 119) or b"")
                arm, autopilot = (1 << ids.index(i) if i in ids else 0 for i in (0, 56))
                pulses[4] = 1800
                armed, value = until(modes, lambda m: m is not None and m & arm, wait=8.0)
                check("craft arms for the capture in flight", armed and autopilot, repr((value, ids)))
                pulses[2] = 1400
                place[1] -= 0.0002
                place[2] += 20.0
                time.sleep(4.0)
                pulses[6] = 1800
                engaged, value = until(modes, lambda m: m is not None and m & autopilot, wait=5.0)
                targeting, state = until(executor, lambda e: e == (1, 0, 0), wait=3.0)
                check("autopilot flies the captured plan, saved by the part before", engaged and targeting,
                      repr((value, state)))
                press(pulses, 0.5)
                edited, text = until(warning, lambda r: r is not None and b"SET" in r, wait=2.5)
                check("press while the executor flies the plan edits nothing", not edited, repr(text))
                pulses[6] = 1000
                pulses[4] = 1000
                until(modes, lambda m: m is not None and not m & arm, wait=3.0)
                check("plan still has its one waypoint after that press", len(listed()) == 1, "")

            flown(gesture_part)
            flown(flying_part)
        if built("GPS"):
            waypoint_capture_checks()
        # Flight plan in the build: its boxes, its build option, and its waypoint command in the command line and
        # its help.
        def flight_plan_build_checks():
            store = os.path.join(work, "plan.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                if built("GPS"):
                    ids = (msp(sock, 119) or b"") + (msp(sock, 119, bytes([1])) or b"")
                    check("box ids offer the autopilot", 56 in ids, repr(list(ids)))
                    check("box ids offer waypoint capture", 57 in ids, repr(list(ids)))
                sock.sendall(b"#")
                read_all(sock, 0.8)
                options = {int(w) for w in cli(sock, "options").split() if w.isdigit()}
                check("build options list the flight plan", 16427 in options, repr(sorted(options)))
                text = cli(sock, "waypoint")
                check("command line knows the waypoint command", "UNKNOWN COMMAND" not in text, text[-120:])
                text = cli(sock, "help waypoint")
                check("help lists the waypoint command", "waypoint" in text and "NO MATCHES" not in text, text[-120:])
            finally:
                stop(proc)
                sock.close()
        flight_plan_build_checks()
        if built("SD_Card"):
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
                deadline = time.time() + 15
                while time.time() < deadline:
                    data, why = fat16_log(card)
                    if data is not None and data.startswith(b"H Product:"):
                        break
                    time.sleep(0.5)
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
            started = time.time()
            deadline = started + 24.0
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
            waited = time.time() - started
            sock.sendall(b"#")
            read_all(sock, 0.8)
            status = "" if used >= 2048 else cli(sock, "status", 1.5)[-400:]
            check("MSP flash summary counts the log's bytes", 2048 <= used < 16 * 1024 * 1024,
                  f"{used} after {waited:.1f} s {status}")
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
        proc, sock = start(image, store, {"ADAFLIGHT_FLASH_IMAGE": chip})
        try:
            def flash_used():
                summary = msp(sock, 70)
                return int.from_bytes(summary[9:13], "little") if summary and len(summary) == 13 else -1
            logged, before = until(flash_used, lambda used: used >= 2048, wait=24.0)
            erase = msp(sock, 72)
            emptied, after = until(flash_used, lambda used: 0 <= used < before, wait=10.0)
            check("MSP flash erase empties the flight log's chip", logged and erase == b"" and emptied,
                  f"{before} {after} {erase!r}")
        finally:
            stop(proc)
            sock.close()
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
            text = cli(sock, "set osd_esc_tmp_pos = 2241")
            check("ESC temperature element placed", "osd_esc_tmp_pos set to 2241" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            vtx.stop.set()
            stop(proc)
            sock.close()
        vtx_store = os.path.join(work, "spekvtx.bin")
        proc, sock = start(image, vtx_store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("vtx_uart = UART6", "vtx_type = SMARTAUDIO", "serialrx_provider = SPEK2048", "rx_uart = UART3"):
                text = cli(sock, f"set {line}")
                check(f"Spektrum VTX control setting {line}", line.replace(" = ", " set to ") in text, text[-120:])
            for line in ("vtxtable bands 5", "vtxtable channels 8",
                         "vtxtable band 1 BOSCAM_A A FACTORY 5865 5845 5825 5805 5785 5765 5745 5725",
                         "vtxtable band 2 BOSCAM_B B FACTORY 5733 5752 5771 5790 5809 5828 5847 5866",
                         "vtxtable band 3 BOSCAM_E E FACTORY 5705 5685 5665 5645 5885 5905 5925 5945",
                         "vtxtable band 4 FATSHARK F FACTORY 5740 5760 5780 5800 5820 5840 5860 5880",
                         "vtxtable band 5 RACEBAND R FACTORY 5658 5695 5732 5769 5806 5843 5880 5917",
                         "vtxtable powerlevels 4", "vtxtable powervalues 0 1 2 3",
                         "vtxtable powerlabels 25 200 500 800"):
                cli(sock, line)
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        vtx = SmartAudio()
        frame = spektrum_frame([1500, 1599, 988, 1500] + [1500] * 10)
        sender = SerialReceiver(frame[:12] + bytes([0xE0, 0x23, 0xE0, 0x04]))
        proc, sock = start(image, vtx_store)
        vtx.start()
        sender.start()
        try:
            time.sleep(4.0)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for name, value, what in (("vtx_band", 5, "race band"), ("vtx_channel", 4, "channel 4"),
                                      ("vtx_freq", 5769, "table frequency of race band channel 4"),
                                      ("vtx_power", 2, "SmartAudio power index for 100 to 299 mW")):
                text = cli(sock, f"get {name}")
                check(f"Spektrum VTX control sets the {what}", f"{name} = {value}" in text, text[-120:])
        finally:
            sender.stop.set()
            vtx.stop.set()
            stop(proc)
            sock.close()
        # A table band written over MSP reaches the running table at the next save: band 1, channel 2 looks up
        # the stored table's frequency before the save and the written one after it.
        vtx = SmartAudio()
        proc, sock = start(image, vtx_store)
        vtx.start()
        try:
            time.sleep(4.0)
            name = b"NEWBAND1"
            written = msp(sock, 227, bytes([1, len(name)]) + name + b"N" + bytes([0, 8])
                          + struct.pack("<8H", 5600, 5610, 5620, 5630, 5640, 5650, 5660, 5670))
            msp(sock, 89, struct.pack("<H", 1))
            before = msp(sock, 88)
            saved = msp(sock, 250)
            time.sleep(1.0)
            msp(sock, 89, struct.pack("<H", 1))
            after = msp(sock, 88)
            def frequency(reply):
                return int.from_bytes(reply[5:7], "little") if reply is not None and len(reply) >= 7 else None
            check("a VTX table band written over MSP waits for a save",
                  written == b"" and frequency(before) == 5845, repr(before))
            check("a save loads a VTX table band written over MSP into the running table",
                  saved == b"" and frequency(after) == 5610, repr(after))
        finally:
            vtx.stop.set()
            stop(proc)
            sock.close()
        msp_vtx_store = os.path.join(work, "mspvtx.bin")
        proc, sock = start(image, msp_vtx_store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("vtx_type = MSP", "osd_displayport_device = MSP", "osd_uart = UART3"):
                text = cli(sock, f"set {line}")
                check(f"MSP transmitter setting {line}", line.replace(" = ", " set to ") in text, text[-120:])
            for line in ("vtxtable bands 1", "vtxtable channels 8",
                         "vtxtable band 1 BOSCAM_A A FACTORY 5865 5845 5825 5805 5785 5765 5745 5725",
                         "vtxtable powerlevels 2", "vtxtable powervalues 25 200", "vtxtable powerlabels 25 200"):
                cli(sock, line)
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, msp_vtx_store)
        try:
            time.sleep(2.5)
            goggle = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
            goggle.settimeout(0.3)
            read_all(goggle, 0.5)
            goggle.sendall(b"$M<\x00\x58\x58")
            reply = read_all(goggle, 0.6)
            body = bytes([4, 89]) + (3).to_bytes(2, "little") + bytes([2, 0])
            check_byte = 0
            for b in body:
                check_byte ^= b
            goggle.sendall(b"$M<" + body + bytes([check_byte]))
            pushed = read_all(goggle, 2.0)
            goggle.close()
            check("MSP transmitter answers the VTX configuration request with its type", b"$M>\x0f\x58\x05" in reply,
                  repr(reply[:40]))
            check("MSP transmitter pushes its configuration after a goggle's write",
                  b"$X>\x00\x58\x00\x0f\x00\x05\x01\x04\x02" in pushed, repr(pushed[:80]))
        finally:
            stop(proc)
            sock.close()
        crsf_vtx_store = os.path.join(work, "crsfvtx.bin")
        proc, sock = start(image, crsf_vtx_store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("vtx_type = MSP", "vtx_uart = UART3", "rx_uart = UART3", "osd_uart = UART1"):
                text = cli(sock, f"set {line}")
                check(f"CRSF port MSP transmitter setting {line}", line.replace(" = ", " set to ") in text,
                      text[-120:])
            for line in ("vtxtable bands 1", "vtxtable channels 8",
                         "vtxtable band 1 BOSCAM_A A FACTORY 5865 5845 5825 5805 5785 5765 5745 5725",
                         "vtxtable powerlevels 2", "vtxtable powervalues 25 200", "vtxtable powerlabels 25 200"):
                cli(sock, line)
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, crsf_vtx_store)
        receiver = Receiver()
        receiver.start()
        try:
            time.sleep(3.0)
            receiver.outbox.append(crsf_msp_request(bytes([0x30, 4, 89, 3, 0, 2, 0])))
            time.sleep(2.0)
            pushes = [f for f in receiver.msp_replies
                      if f[3:5] == bytes([0xEC, 0xC8]) and f[5:11] == bytes([0x50, 0, 0x58, 0, 0x0F, 0])]
            check("MSP transmitter on the CRSF port pushes its configuration over the CRSF link",
                  len(pushes) >= 1 and pushes[0][11:15] == bytes([5, 1, 4, 2]), repr(receiver.msp_replies[:3]))
        finally:
            receiver.stop.set()
            stop(proc)
            sock.close()
        shared_store = os.path.join(work, "crsfdisplay.bin")
        proc, sock = start(image, shared_store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("vtx_type = MSP", "vtx_uart = UART3", "rx_uart = UART3"):
                text = cli(sock, f"set {line}")
                check(f"display port fallback setting {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, shared_store)
        receiver = Receiver()
        receiver.start()
        try:
            time.sleep(3.0)
            receiver.outbox.append(crsf_msp_request(bytes([0x30, 0, 1])))
            time.sleep(2.0)
            check("MSP display port leaves a CRSF receiver's line alone",
                  receiver.frames.get(0x08, 0) >= 30 and len(receiver.msp_replies) >= 1, repr(receiver.frames))
        finally:
            receiver.stop.set()
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
            try:
                with open(store + ".osd.txt") as f:
                    rows = f.read().splitlines()
            except OSError:
                rows = []
            check("OSD draws the ESC temperature", len(rows) > 6 and re.match(r"^.E. 42", rows[6]) is not None,
                  repr(rows[6] if len(rows) > 6 else rows))
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
        if built("LTM_Telemetry"):
            store = os.path.join(work, "ltm.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "feature TELEMETRY")
                check("telemetry feature on", "Enabled" in text, text[-120:])
                text = cli(sock, "set telemetry_1_protocol = LTM")
                check("telemetry provider set to LTM", "telemetry_1_protocol set to LTM" in text, text[-120:])
                text = cli(sock, "set telemetry_1_uart = UART3")
                check("LTM port assigned", "telemetry_1_uart set to UART3" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                ltm = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
                ltm.settimeout(0.3)
                frames = ltm_frames(read_all(ltm, 1.5))
                ltm.close()
                letters = "".join(f for f, _ in frames)
                check("LTM sends attitude frames ten times a second", 10 <= letters.count("A") <= 20, letters)
                status = [p for f, p in frames if f == "S"]
                check("LTM status frames report disarmed in rate mode", bool(status) and status[-1][6] == 1 << 2,
                      repr(status[-1:]))
                check("LTM sends an origin frame every tenth cycle", 1 <= letters.count("O") <= 3, letters)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                sock.sendall(b"bl\r\n")
                read_all(sock, 0.8)
                try:
                    code = proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    code = None
                check("bl restarts into the bootloader", code == 2, repr(code))
            finally:
                stop(proc)
                sock.close()
        if built("MAVLink_Telemetry"):
            store = os.path.join(work, "mavlink.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                mission = 16427 in {int(w) for w in cli(sock, "options").split() if w.isdigit()}
                text = cli(sock, "feature TELEMETRY")
                check("telemetry feature on for MAVLink", "Enabled" in text, text[-120:])
                text = cli(sock, "set telemetry_1_protocol = MAVLINK")
                check("telemetry provider set to MAVLink", "telemetry_1_protocol set to MAVLINK" in text, text[-120:])
                text = cli(sock, "set telemetry_1_uart = UART3")
                check("MAVLink port assigned", "telemetry_1_uart set to UART3" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                mav = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
                mav.settimeout(0.3)
                frames = mavlink_frames(read_all(mav, 3.0))
                ids = [m for m, _ in frames]
                check("MAVLink sends heartbeats", ids.count(0) >= 2, repr(ids[:40]))
                check("MAVLink sends attitude messages", ids.count(30) >= 4, repr(ids[:40]))
                mav.sendall(mavlink_command_long(512, 148.0))
                replies = mavlink_frames(read_all(mav, 1.5))
                ids = [m for m, _ in replies]
                check("MAVLink answers an autopilot version request", 148 in ids and 77 in ids, repr(ids[:40]))
                if mission:
                    mavlink_mission_upload(mav)
                    mav.close()
                    stop(proc)
                    sock.close()
                    proc, sock = start(image, store)
                    time.sleep(2.5)
                    mav = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
                    mav.settimeout(0.3)
                    mavlink_mission_readback(mav)
                else:
                    print("SKIP the MAVLink mission checks: the build leaves the flight plan out")
                mav.close()
                ack = msp(sock, 68, bytes([1]))
                check("MSP reboot into the bootloader accepted", ack == bytes([1]), repr(ack))
                try:
                    code = proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    code = None
                check("MSP reboot restarts into the bootloader", code == 2, repr(code))
            finally:
                stop(proc)
                sock.close()
        if built("MAVLink_Receiver"):
            store = os.path.join(work, "mavlinkrx.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "feature TELEMETRY")
                check("telemetry feature on for the MAVLink receiver", "Enabled" in text, text[-120:])
                text = cli(sock, "set serialrx_provider = MAVLINK")
                check("receiver protocol set to MAVLINK", "serialrx_provider set to MAVLINK" in text, text[-120:])
                text = cli(sock, "set rx_uart = UART3")
                check("MAVLINK port assigned", "rx_uart set to UART3" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            sender = SerialReceiver(mavlink_override([1500, 1599, 988, 1500] + [1500] * 10))
            sender.start()
            try:
                time.sleep(2.5)
                passed, values = until(lambda: rc_values(sock),
                                       lambda v: len(v) == 4 and abs(v[0] - 1500) <= 2 and abs(v[1] - 1599) <= 2
                                       and abs(v[2] - 1500) <= 2 and v[3] <= 1000)
                check("MAVLINK channels reach the MSP RC reply", passed, repr(values))
                time.sleep(1.0)
                ids = [m for m, _ in mavlink_frames(sender.received)]
                check("MAVLink telemetry heartbeats ride on the receiver's port", ids.count(0) >= 2, repr(ids[:40]))
            finally:
                sender.stop.set()
                stop(proc)
                sock.close()
        us = [1500, 1599, 988, 1500] + [1500] * 10
        for name, frame, expected in (("CRSF", crsf_frame([992, 1150, 172, 992] + [992] * 12),
                                       bytes.fromhex("c80732ecc810019ee8")),
                                      ("SRXL2", srxl2_frame(us), b"\xa6\x41")):
            bind_store = os.path.join(work, name.lower() + "bind.bin")
            proc, sock = start(image, bind_store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, f"set serialrx_provider = {name}")
                check(f"{name} receiver set for binding", f"serialrx_provider set to {name}" in text, text[-120:])
                text = cli(sock, "set rx_uart = UART3")
                check(f"{name} bind port assigned", "rx_uart set to UART3" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, bind_store)
            sender = SerialReceiver(frame)
            sender.start()
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "bind_rx")
                check(f"bind_rx starts a {name} bind", "Binding..." in text, text[-120:])
                time.sleep(1.0)
                check(f"{name} receiver gets its bind frame", expected in sender.received, repr(sender.received[:48]))
            finally:
                sender.stop.set()
                stop(proc)
                sock.close()
        store = os.path.join(work, "srxl2tlm.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "feature TELEMETRY")
            check("telemetry feature on for SRXL2", "Enabled" in text, text[-120:])
            text = cli(sock, "set serialrx_provider = SRXL2")
            check("receiver protocol set to SRXL2 for telemetry", "serialrx_provider set to SRXL2" in text, text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("SRXL2 telemetry port assigned", "rx_uart set to UART3" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        us = [1500, 1599, 988, 1500] + [1500] * 10
        sender = SerialReceiver([srxl2_frame(us), srxl2_frame(us, reply=0x31)])
        sender.start()
        try:
            time.sleep(2.5)
            passed, values = until(lambda: rc_values(sock),
                                   lambda v: len(v) == 4 and abs(v[0] - 1500) <= 2 and abs(v[1] - 1599) <= 2
                                   and abs(v[2] - 1500) <= 2 and v[3] <= 1000)
            check("SRXL2 channels reach the MSP RC reply with telemetry on", passed, repr(values))
            time.sleep(1.0)
            replies = sender.received.count(b"\xa6\x80\x16")
            check("SRXL2 receiver gets telemetry packets when it asks", replies >= 2, repr(sender.received[:48]))
        finally:
            sender.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "frskyhub.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "feature TELEMETRY")
            check("telemetry feature on for the FrSky hub", "Enabled" in text, text[-120:])
            text = cli(sock, "set telemetry_1_protocol = FRSKY_HUB")
            check("telemetry provider set to the FrSky hub", "telemetry_1_protocol set to FRSKY_HUB" in text,
                  text[-120:])
            text = cli(sock, "set telemetry_1_uart = UART3")
            check("FrSky hub port assigned", "telemetry_1_uart set to UART3" in text, text[-120:])
            for line in ("rangefinder_hardware = TFMINI", "rangefinder_uart = UART4"):
                text = cli(sock, "set " + line)
                check(f"FrSky hub rangefinder {line}", line.replace(" = ", " set to ") in text, text[-120:])
            text = cli(sock, "feature RANGEFINDER")
            check("rangefinder feature on for the FrSky hub", "Enabled" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        lidar = Lidar()
        lidar.start()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            hub = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
            hub.settimeout(0.3)
            frames = hub_frames(read_all(hub, 1.3))
            hub.close()
            ids = [i for i, _ in frames]
            check("FrSky hub sends the acceleration frames every 125 ms", 6 <= ids.count(0x24) <= 14, repr(ids[:40]))
            if built("Rangefinder"):
                check("FrSky hub sends the vario and altitude frames with a rangefinder",
                      0x30 in ids and 0x10 in ids and 0x21 in ids, repr(sorted(set(ids))))
        finally:
            lidar.stop.set()
            stop(proc)
            sock.close()
        if built("IBus_Telemetry"):
            store = os.path.join(work, "ibustlm.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "feature TELEMETRY")
                check("telemetry feature on for iBus", "Enabled" in text, text[-120:])
                text = cli(sock, "set telemetry_1_protocol = IBUS")
                check("telemetry provider set to iBus", "telemetry_1_protocol set to IBUS" in text, text[-120:])
                text = cli(sock, "set telemetry_1_uart = UART3")
                check("iBus telemetry port assigned", "telemetry_1_uart set to UART3" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                line = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
                line.settimeout(0.3)
                replies = []
                for command in (0x80, 0x90, 0xA0):
                    line.sendall(ibus_request(command, 1))
                    replies.append(read_all(line, 0.3))
                    line.sendall(replies[-1])
                    time.sleep(0.05)
                line.close()
                check("iBus telemetry answers the discovery", replies[0] == ibus_request(0x80, 1), repr(replies[0]))
                check("iBus telemetry gives the sensor type and value",
                      len(replies[1]) == 6 and replies[1][:2] == bytes([0x06, 0x91])
                      and len(replies[2]) == 6 and replies[2][:2] == bytes([0x06, 0xA1]), repr(replies[1:]))
            finally:
                stop(proc)
                sock.close()
        store = os.path.join(work, "smartport.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "feature TELEMETRY")
            check("telemetry feature on for SmartPort", "Enabled" in text, text[-120:])
            text = cli(sock, "set telemetry_1_protocol = SMARTPORT")
            check("telemetry provider set to SmartPort", "telemetry_1_protocol set to SMARTPORT" in text, text[-120:])
            text = cli(sock, "set telemetry_1_uart = UART3")
            check("SmartPort port assigned", "telemetry_1_uart set to UART3" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            line = socket.create_connection(("127.0.0.1", RX_PORT), timeout=1)
            line.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            line.settimeout(0.01)
            data = b""
            for _ in range(80):
                line.sendall(bytes([0x7E, 0x1B]))
                time.sleep(0.012)
                try:
                    data += line.recv(4096)
                except socket.timeout:
                    pass
            line.sendall(sport_request(bytes([0x30, 0x00, 0x01, 0x00, 0x00, 0x00])))
            msp_bytes = b""
            for _ in range(12):
                time.sleep(0.012)
                line.sendall(bytes([0x7E, 0x1B]))
                time.sleep(0.012)
                try:
                    msp_bytes += line.recv(4096)
                except socket.timeout:
                    pass
            line.close()
            frames = sport_frames(data)
            ids = sorted({i for i, _ in frames})
            check("SmartPort answers the polls with checked data frames", len(frames) >= 20, repr(ids))
            check("SmartPort sends the battery voltage", 0x0210 in ids, repr(ids))
            chunks = sport_msp_frames(msp_bytes)
            check("SmartPort answers an MSP request with server frames", len(chunks) >= 2, repr(chunks[:3]))
            check("SmartPort MSP reply opens with its status, size, command and the API version",
                  chunks[:1] == [bytes([0x30, 3, 1, 0, 1, 49])], repr(chunks[:1]))
            check("SmartPort MSP reply pads its last chunk with zeros", chunks[1:2] == [bytes([0x21, 0, 0, 0, 0, 0])],
                  repr(chunks[1:2]))
        finally:
            stop(proc)
            sock.close()
        us = [1500, 1599, 988, 1500] + [1500] * 10
        receiver_features = {"SUMD": "SUMD", "SUMH": "SUMH", "JETIEXBUS": "Jeti_EX_Bus"}
        for name, frame, extra in (("SBUS", sbus_frame([992, 1150, 172, 992] + [992] * 12), []),
                                   ("IBUS", ibus_frame(us), ["serialrx_halfduplex = ON"]),
                                   ("SUMD", sumd_frame(us), []), ("SUMH", sumh_frame(us), []),
                                   ("SPEK2048", spektrum_frame(us), []),
                                   ("XB-B", xbus_frame(us), []),
                                   ("FPORT", fport_frame([992, 1150, 172, 992] + [992] * 12), []),
                                   ("GHST", ghst_frames(us), []), ("JETIEXBUS", jeti_frame(us), []),
                                   ("SRXL2", srxl2_frame(us), [])):
            if name in receiver_features and not built(receiver_features[name]):
                continue
            store = os.path.join(work, name.lower() + ".bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, f"set serialrx_provider = {name}")
                check(f"receiver protocol set to {name}", f"serialrx_provider set to {name}" in text, text[-120:])
                text = cli(sock, "set rx_uart = UART3")
                check(f"{name} port assigned", "rx_uart set to UART3" in text, text[-120:])
                for line in extra:
                    text = cli(sock, f"set {line}")
                    check(f"{name} receiver {line}", line.replace(" = ", " set to ") in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            sender = SerialReceiver(frame)
            sender.start()
            try:
                time.sleep(2.5)
                passed, values = until(lambda: rc_values(sock),
                                       lambda v: len(v) == 4 and abs(v[0] - 1500) <= 2 and abs(v[1] - 1599) <= 2
                                       and abs(v[2] - 1500) <= 2 and v[3] <= 1000)
                check(f"{name} channels reach the MSP RC reply", passed, repr(values))
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "status")
                flags = text.split("Arming disable flags:")[-1]
                check(f"{name} link clears the signal loss",
                      "Arming disable flags:" in text and "RXLOSS" not in flags, flags.strip()[:80])
            finally:
                sender.stop.set()
                stop(proc)
                sock.close()
        store = os.path.join(work, "crsfmsp.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set rx_uart = UART3")
            check("CRSF receiver port assigned for MSP", "rx_uart set to UART3" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        receiver = Receiver()
        receiver.start()
        try:
            time.sleep(3.0)
            until(lambda: len(receiver.frames), lambda n: n > 0)
            receiver.outbox.append(crsf_msp_request(bytes([0x30, 0, 1])))
            until(lambda: len(receiver.msp_replies), lambda n: n >= 1, wait=5.0)
            time.sleep(0.5)
            replies = list(receiver.msp_replies)
            reply = msp_tunnel_reply([f[5:-1] for f in replies])
            check("MSP over CRSF answers the API version to the request's origin",
                  len(replies) == 1 and replies[0][3:5] == bytes([0xEA, 0xC8]) and reply is not None
                  and reply[0] == 1 and reply[1] == 3 and reply[2][:2] == bytes([0, 1]) and reply[3], repr(replies))
            receiver.msp_replies.clear()
            receiver.outbox.append(crsf_msp_request(bytes([0x31, 0, 52])))
            until(lambda: len(receiver.msp_replies), lambda n: n >= 6, wait=5.0)
            time.sleep(0.5)
            replies = list(receiver.msp_replies)
            reply = msp_tunnel_reply([f[5:-1] for f in replies])
            serial = msp(sock, 52)
            check("MSP over CRSF sends the 300-byte adjustment ranges in six numbered chunks as serial MSP does",
                  len(replies) == 6 and reply is not None and reply[0] == 52 and reply[1] == 300
                  and reply[2] == serial and reply[3], repr(replies[:2]))
            receiver.msp_replies.clear()
            receiver.outbox.append(crsf_msp_request(bytes([0x32, 0, 245])))
            until(lambda: len(receiver.msp_replies), lambda n: n >= 1, wait=5.0)
            time.sleep(0.5)
            replies = list(receiver.msp_replies)
            reply = msp_tunnel_reply([f[5:-1] for f in replies])
            motors = msp(sock, 104)
            check("passthrough request over CRSF is refused and MSP goes on",
                  len(replies) == 1 and reply is not None and reply[0] == 245 and reply[1] == 1
                  and reply[2] == b"\x00" and motors is not None and len(motors) == 16, repr((replies, motors)))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "tasks", wait=1.5)
            rate = re.search(r"TELEMETRY\)\s+(\d+)", text)
            check("telemetry task runs at 500 Hz with a CRSF receiver",
                  rate is not None and rate.group(1) == "500", repr(rate and rate.group(0)))
        finally:
            receiver.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "runcam.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set rcdevice_uart = UART4")
            check("RunCam port assigned", "rcdevice_uart set to UART4" in text, text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("receiver port assigned for the camera switch", "rx_uart set to UART3" in text, text[-120:])
            cli(sock, "aux 0 32 0 1700 2100 0 0")
            text = cli(sock, "aux")
            check("camera control 1 on AUX1", "aux 0 32 0 1700 2100 0 0" in text, text[-200:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        camera = Camera()
        camera.start()
        proc, sock = start(image, store)
        receiver = Receiver()
        receiver.start()
        try:
            time.sleep(3.0)
            info = bytes([0xCC, 0x00, crc8_dvb_s2(bytes([0xCC, 0x00]))])
            check("RunCam device asks the camera for its device information", camera.received.startswith(info),
                  repr(camera.received[:20]))
            receiver.channels[4] = 1811
            time.sleep(0.6)
            press = bytes([0xCC, 0x01, 0x00])
            check("camera control 1 presses the camera's WiFi button once",
                  camera.received.count(press + bytes([crc8_dvb_s2(press)])) == 1, repr(camera.received[:40]))
        finally:
            receiver.stop.set()
            camera.stop.set()
            stop(proc)
            sock.close()
        if built("Jeti_EX_Bus"):
            store = os.path.join(work, "jetitlm.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set serialrx_provider = JETIEXBUS")
                check("receiver protocol set to EX Bus for its telemetry", "serialrx_provider set to JETIEXBUS" in text,
                      text[-120:])
                text = cli(sock, "set rx_uart = UART3")
                check("EX Bus telemetry port assigned", "rx_uart set to UART3" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            sender = SerialReceiver([jeti_frame(us), jeti_request(7)])
            sender.start()
            try:
                time.sleep(4.0)
                passed, answers = until(lambda: jeti_answers(sender.received), lambda a: len(a) >= 10)
                check("EX Bus telemetry answers the receiver's requests with checked frames", passed,
                      repr(sender.received[:40]))
                check("EX Bus telemetry answers echo the packet id and carry the EX telemetry header",
                      bool(answers) and all(a[3] == 7 and a[4] == 0x3A and a[6] == 0x9F
                                            and a[8:10] == bytes([0x1E, 0xA4]) for a in answers), repr(answers[:2]))
            finally:
                sender.stop.set()
                stop(proc)
                sock.close()
        store = os.path.join(work, "mspdp.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            plain_version = msp(sock, 3)
            plain_osd = msp(sock, 84)
            check("version reply has its text and the OSD reply every item on a port without the display",
                  plain_version is not None and len(plain_version) > 3 and plain_osd is not None
                  and len(plain_osd) > 8 and plain_osd[7] > 80, repr((plain_version, plain_osd and plain_osd[:8])))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set osd_displayport_device = MSP")
            check("OSD display device set to MSP", "osd_displayport_device set to MSP" in text, text[-120:])
            text = cli(sock, "set osd_uart = UART1")
            check("OSD display port on UART1", "osd_uart set to UART1" in text, text[-120:])
            cli(sock, "set craft_name = ADAHOST")
            text = cli(sock, "set osd_craft_name_pos = 2122")
            check("craft name element placed for the MSP display", "osd_craft_name_pos set to 2122" in text,
                  text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            data = read_all(sock, 7.0)
            pushes = msp_pushes(data, 182)
            subs = sorted({p[0] for p in pushes if p})
            check("MSP display port pushes the heartbeat, clear, string and draw subcommands on UART1",
                  {0, 2, 3, 4} <= set(subs), repr(subs))
            check("MSP display port writes the craft name",
                  any(p[0] == 3 and b"ADAHOST" in p[4:] for p in pushes), repr(pushes[-6:]))
            sock.sendall(b"$M<" + bytes([0, 1, 1]))
            api = msp_pushes(read_all(sock, 0.5), 1)
            check("UART1 still answers MSP beside the display port", len(api) == 1 and len(api[0]) == 3,
                  repr(api))
            sock.sendall(b"$M<" + bytes([0, 3, 3]))
            version = msp_pushes(read_all(sock, 0.5), 3)
            check("version reply on the display's port is its three bytes",
                  len(version) == 1 and plain_version is not None and version[0] == plain_version[:3],
                  repr((version, plain_version)))
            sock.sendall(b"$M<" + bytes([0, 84, 84]))
            osd = msp_pushes(read_all(sock, 0.5), 84)
            check("OSD reply on the display's port has eighty items and no RSSI dBm alarm",
                  len(osd) == 1 and plain_osd is not None and osd[0][7] == 80
                  and len(osd[0]) == len(plain_osd) - 2 * (plain_osd[7] - 80) - 2,
                  repr((len(osd), osd and osd[0][:10], plain_osd and len(plain_osd))))
        finally:
            stop(proc)
            sock.close()
        store = os.path.join(work, "mspdp4.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("osd_displayport_device = MSP", "osd_uart = UART4", "osd_craft_name_pos = 2122"):
                text = cli(sock, "set " + line)
                check(f"display port on UART4 {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "set craft_name = ADAHOST")
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        uart4 = None
        try:
            uart4 = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
            uart4.settimeout(0.3)
            data = read_all(uart4, 7.0)
            pushes = msp_pushes(data, 182)
            subs = sorted({p[0] for p in pushes if p})
            check("MSP display port on UART4 pushes the heartbeat, clear, string and draw subcommands",
                  {0, 2, 3, 4} <= set(subs), repr(subs))
            check("MSP display port on UART4 writes the craft name",
                  any(p[0] == 3 and b"ADAHOST" in p[4:] for p in pushes), repr(pushes[-6:]))
            uart4.sendall(b"$M<" + bytes([0, 1, 1]))
            api = msp_pushes(read_all(uart4, 0.5), 1)
            check("UART4 answers MSP on the port the display port implies", len(api) == 1 and len(api[0]) == 3,
                  repr(api))
        finally:
            stop(proc)
            sock.close()
            if uart4 is not None:
                uart4.close()
        store = os.path.join(work, "uart1rx.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set msp_2_uart = NONE")
            check("MSP slot taken off UART1 for the receiver", "msp_2_uart set to NONE" in text, text[-120:])
            text = cli(sock, "set rx_uart = UART1")
            check("CRSF receiver on UART1", "rx_uart set to UART1" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        stop_feed = threading.Event()

        def feed_uart1():
            while not stop_feed.is_set():
                try:
                    sock.sendall(crsf_frame([992, 1150, 172, 992] + [992] * 12))
                except OSError:
                    break
                time.sleep(0.02)
        feeder = threading.Thread(target=feed_uart1, daemon=True)
        feeder.start()
        vcp = None
        try:
            time.sleep(3.0)
            vcp = socket.create_connection(("127.0.0.1", VCP_PORT), timeout=1)
            vcp.settimeout(0.3)
            time.sleep(0.5)
            passed, values = until(lambda: rc_values(vcp),
                                   lambda v: len(v) == 4 and abs(v[0] - 1500) <= 2 and abs(v[1] - 1599) <= 2)
            check("receiver on UART1 keeps its bytes from the MSP framing", passed, repr(values))
        finally:
            stop_feed.set()
            stop(proc)
            sock.close()
            if vcp is not None:
                vcp.close()
        if built("Rangefinder"):
            store = os.path.join(work, "lidar.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set rangefinder_hardware = TFMINI")
                check("rangefinder set to a TFmini", "rangefinder_hardware set to TFMINI" in text, text[-120:])
                text = cli(sock, "set rangefinder_uart = UART4")
                check("rangefinder port assigned", "rangefinder_uart set to UART4" in text, text[-120:])
                text = cli(sock, "feature RANGEFINDER")
                check("rangefinder feature on", "Enabled" in text, text[-120:])
                for line in ("blackbox_device = SERIAL", "blackbox_uart = UART6", "blackbox_mode = ALWAYS"):
                    text = cli(sock, "set " + line)
                    check(f"rangefinder flight log {line}", line.replace(" = ", " set to ") in text, text[-120:])
                for line in ("osd_displayport_device = MAX7456", "vcd_video_system = PAL", "osd_lidar_dist_pos = 2177"):
                    text = cli(sock, "set " + line)
                    check(f"rangefinder OSD {line}", line.replace(" = ", " set to ") in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            lidar = Lidar()
            lidar.start()
            proc, sock = start(image, store)
            log = None
            deadline = time.time() + 5
            while log is None and time.time() < deadline:
                try:
                    log = socket.create_connection(("127.0.0.1", LOG_PORT), timeout=1)
                    log.settimeout(0.3)
                except OSError:
                    time.sleep(0.01)
            try:
                data = read_all(log, 3.0) if log is not None else b""
                fields = next((line for line in data.split(b"\n") if line.startswith(b"H Field I name:")), b"")
                check("flight log lists the rangefinder's surfaceRaw field", b",surfaceRaw," in fields + b",",
                      repr(fields[-80:]))
                status = msp(sock, 101)
                check("MSP status names the rangefinder", status is not None and len(status) > 5
                      and (status[4] | status[5] << 8) & 0x10 != 0, repr(status))
                sonar = msp(sock, 58)
                altitude = int.from_bytes(sonar[:4], "little", signed=True) if sonar and len(sonar) >= 4 else None
                check("MSP sonar altitude reads the lidar's 150 cm", altitude is not None and abs(altitude - 150) <= 2,
                      repr(altitude))
                time.sleep(4.5)
                try:
                    with open(store + ".osd.txt") as f:
                        rows = f.read().splitlines()
                except OSError:
                    rows = []
                check("OSD lidar element draws the 150 cm", len(rows) > 4 and "RF:150" in rows[4],
                      repr(rows[4] if len(rows) > 4 else rows))
            finally:
                lidar.stop.set()
                stop(proc)
                sock.close()
                if log is not None:
                    log.close()
            store = os.path.join(work, "tofsense.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set rangefinder_hardware = NOOPLOOP_F2")
                check("rangefinder set to a TOFSense F2", "rangefinder_hardware set to NOOPLOOP_F2" in text,
                      text[-120:])
                text = cli(sock, "set rangefinder_uart = UART4")
                check("TOFSense port assigned", "rangefinder_uart set to UART4" in text, text[-120:])
                text = cli(sock, "feature RANGEFINDER")
                check("rangefinder feature on for the TOFSense", "Enabled" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            tof = Lidar(tofsense_frame(1234))
            tof.start()
            proc, sock = start(image, store)
            try:
                time.sleep(3.0)
                sonar = msp(sock, 58)
                altitude = int.from_bytes(sonar[:4], "little", signed=True) if sonar and len(sonar) >= 4 else None
                check("MSP sonar altitude reads the TOFSense's 123 cm",
                      altitude is not None and abs(altitude - 123) <= 1, repr(altitude))
            finally:
                tof.stop.set()
                stop(proc)
                sock.close()
            # A UP-T1 module on UART4 for both readings: its startup text, then frames at 150 cm with flow integrals,
            # so both sensor flags show and the sonar altitude follows the laser distance.
            store = os.path.join(work, "upt1.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("set rangefinder_hardware = UPT1", "set rangefinder_uart = UART4",
                             "set opticalflow_hardware = UPT1", "set opticalflow_uart = UART4"):
                    text = cli(sock, line)
                    check(f"UP-T1 {line[4:]}", line[4:].replace(" = ", " set to ") in text, text[-120:])
                text = cli(sock, "feature RANGEFINDER")
                check("rangefinder feature on for the UP-T1", "Enabled" in text, text[-120:])
                text = cli(sock, "feature OPTICALFLOW")
                check("optical flow feature on for the UP-T1", "Enabled" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            module = Lidar(upt1_frame(1500), prefix=b"UPIXELS UP-T1 READY.\r\n")
            module.start()
            proc, sock = start(image, store)
            try:
                time.sleep(3.0)
                status = msp(sock, 101)
                check("MSP status shows the UP-T1 rangefinder and optical flow", status is not None and len(status) > 5
                      and (status[4] | status[5] << 8) & 0x50 == 0x50, repr(status))
                sonar = msp(sock, 58)
                altitude = int.from_bytes(sonar[:4], "little", signed=True) if sonar and len(sonar) >= 4 else None
                check("MSP sonar altitude reads the UP-T1's 150 cm", altitude is not None and abs(altitude - 150) <= 1,
                      repr(altitude))
            finally:
                module.stop.set()
                stop(proc)
                sock.close()
        store = os.path.join(work, "fporttlm.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set serialrx_provider = FPORT")
            check("receiver protocol set to FPORT for its telemetry", "serialrx_provider set to FPORT" in text,
                  text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("FPORT telemetry port assigned", "rx_uart set to UART3" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        sender = SerialReceiver([fport_frame([992, 1150, 172, 992] + [992] * 12), fport_telemetry_request()])
        sender.start()
        try:
            time.sleep(2.0)
            sender.outbox.append(fport_telemetry_request(0x30, bytes([0x30, 0x00, 0x01, 0x00, 0x00, 0x00])))
            time.sleep(2.0)
            replies = fport_replies(sender.received)
            data = [r for r in replies if r[0] == 0x10]
            check("FPORT telemetry answers the requests with checked SmartPort replies", len(data) >= 10,
                  repr(sender.received[:40]))
            check("FPORT telemetry replies carry the battery voltage among their values",
                  any(r[1] == 0x0210 for r in data), repr(sorted({r[1] for r in data})))
            chunks = [r[1].to_bytes(2, "little") + r[2].to_bytes(4, "little") for r in replies if r[0] == 0x32]
            check("FPORT answers an MSP request with server frames", len(chunks) >= 2, repr(chunks[:3]))
            check("FPORT MSP reply opens with its status, size, command and the API version",
                  chunks[:1] == [bytes([0x30, 3, 1, 0, 1, 49])], repr(chunks[:1]))
            check("FPORT MSP reply pads its last chunk with zeros", chunks[1:2] == [bytes([0x21, 0, 0, 0, 0, 0])],
                  repr(chunks[1:2]))
        finally:
            sender.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "srxltlm.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "feature TELEMETRY")
            check("telemetry feature on for SRXL", "Enabled" in text, text[-120:])
            text = cli(sock, "set serialrx_provider = SRXL")
            check("receiver protocol set to SRXL", "serialrx_provider set to SRXL" in text, text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("SRXL receiver port assigned", "rx_uart set to UART3" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        sender = SerialReceiver(spektrum_frame(us))
        sender.start()
        try:
            time.sleep(4.0)
            frames = srxl_frames(sender.received)
            kinds = sorted({f[0] for f in frames})
            check("SRXL telemetry answers the receiver's frames with checked frames", len(frames) >= 10,
                  repr(sender.received[:40]))
            check("SRXL telemetry sends the link quality and the RPM frames", 0x7F in kinds and 0x7E in kinds,
                  repr(kinds))
            if built("Menus"):
                gesture = spektrum_frame([1500, 1950, 1500, 1000] + [1500] * 10)
                for frame in (gesture, spektrum_frame(us), gesture, spektrum_frame(us)):
                    sender.frames = [frame]
                    time.sleep(0.4)
                mark = len(sender.received)
                time.sleep(2.0)
                lines = [f[3:16].decode("ascii", "replace") for f in srxl_frames(sender.received[mark:])
                         if f[0] == 0x0C]
                check("stick gesture opens the menu on the SRXL display, whose text frames carry the title",
                      any("MAIN" in line or "QUICK" in line for line in lines), repr(lines[:9]))
        finally:
            sender.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "ghsttlm.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "feature TELEMETRY")
            check("telemetry feature on for Ghost", "Enabled" in text, text[-120:])
            text = cli(sock, "set serialrx_provider = GHST")
            check("receiver protocol set to GHST for its telemetry", "serialrx_provider set to GHST" in text,
                  text[-120:])
            text = cli(sock, "set rx_uart = UART3")
            check("Ghost telemetry port assigned", "rx_uart set to UART3" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        sender = SerialReceiver(ghst_frames(us))
        sender.start()
        try:
            time.sleep(4.0)
            frames = ghst_replies(sender.received)
            kinds = sorted({k for k, _ in frames})
            check("Ghost telemetry answers in the receiver's quiet window with checked frames", len(frames) >= 10,
                  repr(sender.received[:60]))
            check("Ghost telemetry sends the battery pack and the barometer frames",
                  kinds == ([0x23, 0x27] if contains("Barometer") else [0x23]), repr(kinds))
            chunks = ghst_msp_exchange(sender, bytes([0x30, 0, 1]), 2, 5.0)
            reply = msp_tunnel_reply(chunks)
            check("MSP over Ghost answers the API version in a full chunk and an empty last one",
                  len(chunks) == 2 and chunks[1][1:] == bytes(5) and reply is not None and reply[0] == 1
                  and reply[1] == 3 and reply[2][:2] == bytes([0, 1]) and reply[3], repr(chunks))
            chunks = ghst_msp_exchange(sender, bytes([0x31, 0, 52]), 61, 8.0)
            reply = msp_tunnel_reply(chunks)
            serial = msp(sock, 52)
            check("MSP over Ghost sends the 300-byte adjustment ranges in six-byte chunks as serial MSP does",
                  len(chunks) == 61 and reply is not None and reply[0] == 52 and reply[1] == 300
                  and reply[2] == serial and reply[3], repr((len(chunks), chunks[:3])))
        finally:
            sender.stop.set()
            stop(proc)
            sock.close()

        def screen_row(store, row):
            try:
                with open(store + ".osd.txt") as f:
                    rows = f.read().splitlines()
            except OSError:
                rows = []
            return rows[row] if len(rows) > row else repr(rows)

        def screen_wait(store, text):
            deadline = time.time() + 15
            while time.time() < deadline:
                if screen_row(store, 4)[1:1 + len(text)] == text:
                    return True
                time.sleep(0.1)
            return False

        for name, port in (("customtext.bin", "UART4"), ("customtext1.bin", "UART1")):
            store = os.path.join(work, name)
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in (("msp_2_uart = NONE",) if port == "UART1" else ()) + (
                        "osd_custom_text_uart = " + port, "osd_displayport_device = MAX7456",
                        "vcd_video_system = PAL", "osd_custom_serial_text_pos = 2177"):
                    text = cli(sock, "set " + line)
                    check(f"custom text {line}", line.replace(" = ", " set to ") in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            line = sock
            vcp = None
            try:
                if port == "UART4":
                    deadline = time.time() + 5
                    while line is sock and time.time() < deadline:
                        try:
                            line = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
                        except OSError:
                            time.sleep(0.05)
                check("custom text element shows dashes before a message", screen_wait(store, "---"),
                      repr(screen_row(store, 4)))
                if port == "UART4":
                    line.sendall(b"HELLO ADA\r\n")
                    check("custom text element shows the message without its carriage return",
                          screen_wait(store, "HELLO ADA   "), repr(screen_row(store, 4)))
                    line.sendall(b"SPLIT ")
                    time.sleep(0.3)
                    line.sendall(b"MESSAGE\n")
                    check("custom text element joins a message sent in two parts",
                          screen_wait(store, "SPLIT MESSAGE   "), repr(screen_row(store, 4)))
                    line.sendall(b"\n")
                    check("an empty custom text message clears the text", screen_wait(store, "---       "),
                          repr(screen_row(store, 4)))
                else:
                    line.sendall(b"ON UART1\n")
                    check("custom text on UART1 reaches the OSD", screen_wait(store, "ON UART1   "),
                          repr(screen_row(store, 4)))
                    check("custom text on UART1 keeps MSP off UART1", msp(sock, 1) is None)
                    vcp = socket.create_connection(("127.0.0.1", VCP_PORT), timeout=1)
                    vcp.settimeout(0.3)
                    time.sleep(0.5)
                    api = msp(vcp, 1)
                    check("MSP answers on the USB port beside the custom text", api is not None and len(api) == 3,
                          repr(api))
            finally:
                stop(proc)
                sock.close()
                if line is not sock:
                    line.close()
                if vcp is not None:
                    vcp.close()
        if built("Gimbal"):
            store = os.path.join(work, "gimbal.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set gimbal_uart = UART4")
                check("gimbal port assigned", "gimbal_uart set to UART4" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            line = None
            try:
                deadline = time.time() + 5
                while line is None and time.time() < deadline:
                    try:
                        line = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
                        line.settimeout(0.02)
                    except OSError:
                        time.sleep(0.05)
                time.sleep(3.0)
                read_all(line, 0.2)
                frames = gimbal_frames(read_all(line, 1.0))
                check("gimbal gets a checked command frame about every 10 ms without a head tracker",
                      80 <= len(frames) <= 120, repr(len(frames)))
                check("gimbal frames without a head tracker hold no roll or yaw, mode 0 and sensitivity 15",
                      len(frames) > 0 and all(f[0] == 0 and f[1] == 15 and f[2] == 0 and f[4] == 0 for f in frames),
                      repr(frames[:2]))
                line.sendall(gimbal_frame(900, 0, 0))
                reply = gimbal_frames(read_all(line, 0.1))
                check("a head tracker frame goes on to the gimbal at once with its roll of 900 scaled to 500",
                      len(reply) == 1 and reply[0][2] == 500 and reply[0][4] == 0, repr(reply))
                line.sendall(b"AB" + bytes([0xA5, 0x41]))
                echo = read_all(line, 0.1)
                check("bytes outside a frame pass through to the gimbal, a lone opcode byte as itself",
                      echo == b"AB" + bytes([0xA5, 0x41]), repr(echo[:12]))
            finally:
                stop(proc)
                sock.close()
                if line is not None:
                    line.close()
        if built("Menus"):
            store = os.path.join(work, "crsfmenu.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set rx_uart = UART3")
                check("CRSF receiver port assigned for the menu", "rx_uart set to UART3" in text, text[-120:])
                text = cli(sock, "feature TELEMETRY")
                check("telemetry feature on for the CRSF menu", "Enabled" in text, text[-120:])
                for line in ("osd_displayport_device = MAX7456", "vcd_video_system = PAL"):
                    text = cli(sock, "set " + line)
                    check(f"CRSF menu beside the OSD {line}", line.replace(" = ", " set to ") in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            receiver = Receiver()
            receiver.start()
            try:
                time.sleep(3.0)
                receiver.outbox.append(crsf_display_command(3, rows=9, cols=32))
                time.sleep(2.0)
                screens = crsf_display_screens(list(receiver.display_frames))
                rows = [screens[-1][r:r + 32] for r in range(0, len(screens[-1]), 32)] if screens else []
                check("a CRSF display open draws the start menu, the quick menu, on the transmitter's screen",
                      any("-- QUICK --" in r for r in rows) and any("VTX" in r for r in rows), repr(rows[:4]))
                mark = len(receiver.display_frames)
                receiver.outbox.append(crsf_display_command(4))
                time.sleep(1.0)
                kinds = [f[5] for f in receiver.display_frames[mark:]]
                check("a CRSF display close leaves the menu and clears the transmitter's screen", 0x02 in kinds,
                      repr(kinds[:10]))
                receiver.outbox.append(crsf_display_command(3, rows=9, cols=32))
                time.sleep(1.0)
                receiver.set(992, 1811, 992, 172)
                time.sleep(0.3)
                receiver.set(992, 992, 172, 992)
                time.sleep(1.5)
                screen = "".join(screen_row(store, r) for r in range(16))
                check("the stick gesture moves the open menu from the transmitter to the OSD", "-- QUICK --" in screen,
                      repr(screen[:120]))
                receiver.outbox.append(crsf_display_command(4))
                time.sleep(1.5)
                screen = "".join(screen_row(store, r) for r in range(16))
                check("a CRSF display close after the menu moved to the OSD frees the OSD", "-- QUICK --" not in screen,
                      repr(screen_row(store, 1)))
            finally:
                receiver.stop.set()
                stop(proc)
                sock.close()
        store = os.path.join(work, "tuning.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("p_roll = 47", "i_roll = 83", "d_roll = 31", "d_max_roll = 42", "f_roll = 125",
                         "profile_name = SNAPPY", "rateprofile_name = FREESTYL", "osd_displayport_device = MAX7456",
                         "vcd_video_system = PAL", "osd_pid_roll_pos = 2177", "osd_pid_profile_name_pos = 2209",
                         "osd_rate_profile_name_pos = 2241"):
                text = cli(sock, "set " + line)
                check(f"tuning elements {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            check("OSD roll PID element shows the profile's gains", screen_wait(store, "ROL  47  83  31  42 125"),
                  repr(screen_row(store, 4)))
            check("OSD profile name elements show the PID and rate profile names",
                  screen_row(store, 5)[1:7] == "SNAPPY" and screen_row(store, 6)[1:9] == "FREESTYL",
                  repr((screen_row(store, 5), screen_row(store, 6))))
        finally:
            stop(proc)
            sock.close()
        store = os.path.join(work, "watthours.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "feature ESC_SENSOR")
            check("watt hours from the ESC sensor feature", "Enabled" in text, text[-120:])
            for line in ("esc_sensor_uart = UART6", "battery_meter = ESC", "current_meter = ESC",
                         "osd_displayport_device = MAX7456", "vcd_video_system = PAL", "osd_wh_drawn_pos = 2177"):
                text = cli(sock, "set " + line)
                check(f"watt hours {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        esc = ESC(growing=True)
        proc, sock = start(image, store)
        esc.start()
        try:
            def milliwatt_hours():
                row = screen_row(store, 4)
                whole = re.search(r"(\d+)\.(\d\d)WH", row)
                milli = re.search(r"(\d+)MWH", row)
                return (int(whole.group(1)) * 1000 + int(whole.group(2)) * 10 if whole
                        else int(milli.group(1)) if milli else 0)
            deadline = time.time() + 20
            first = 0
            while first == 0 and time.time() < deadline:
                time.sleep(0.5)
                first = milliwatt_hours()
            grew, second = until(milliwatt_hours, lambda w: w > first, wait=10.0)
            check("OSD watt hours element counts the energy of the charge the ESCs report", 0 < first and grew,
                  repr((first, second, screen_row(store, 4))))
        finally:
            esc.stop.set()
            stop(proc)
            sock.close()
        if built("SD_Card"):
            card = os.path.join(work, "logstatus.img")
            fat16_image(card, 40960)
            store = os.path.join(work, "logstatus.bin")
            proc, sock = start(image, store, {"ADAFLIGHT_SD_IMAGE": card})
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("blackbox_device = SDCARD", "blackbox_mode = ALWAYS", "osd_displayport_device = MAX7456",
                             "vcd_video_system = PAL", "osd_log_status_pos = 2177"):
                    text = cli(sock, "set " + line)
                    check(f"log status {line}", line.replace(" = ", " set to ") in text, text[-120:])
                text = cli(sock, "aux 0 26 0 900 2100 0 0")
                check("flight log box on AUX1", "aux 0 26 0 900 2100 0 0" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, {"ADAFLIGHT_SD_IMAGE": card})
            try:
                passed, row = until(lambda: screen_row(store, 4), lambda r: r[2:4] == "1 ", wait=30.0)
                check("OSD log status element shows the SD card's log number", passed, repr(row))
            finally:
                stop(proc)
                sock.close()
        store = os.path.join(work, "auxvalue.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("rx_uart = UART3", "osd_displayport_device = MAX7456", "vcd_video_system = PAL",
                         "osd_aux_pos = 2177"):
                text = cli(sock, "set " + line)
                check(f"aux value {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        receiver = Receiver()
        receiver.channels[4] = 1811
        receiver.start()
        try:
            check("OSD aux value element shows AUX1 at full deflection scaled to 200", screen_wait(store, "A200 "),
                  repr(screen_row(store, 4)))
        finally:
            receiver.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "flightstate.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("stats_total_flights = 7", "osd_displayport_device = MAX7456", "vcd_video_system = PAL",
                         "osd_ready_mode_pos = 2177", "osd_total_flights_pos = 2209", "osd_flymode_pos = 2241"):
                text = cli(sock, "set " + line)
                check(f"flight state elements {line}", line.replace(" = ", " set to ") in text, text[-120:])
            for line in ("aux 0 47 0 900 2100 0 0", "aux 1 53 0 900 2100 0 0"):
                text = cli(sock, line)
                check(f"flight state box range {line}", line in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            check("OSD ready mode element shows READY with its box active and the craft disarmed",
                  screen_wait(store, "READY "), repr(screen_row(store, 4)))
            check("OSD total flights element shows the stored count", screen_row(store, 5)[1:4] == "#7 ",
                  repr(screen_row(store, 5)))
            check("OSD flight mode element shows ATRN with the acro trainer box active",
                  screen_row(store, 6)[1:6] == "ATRN ", repr(screen_row(store, 6)))
        finally:
            stop(proc)
            sock.close()
        store = os.path.join(work, "vtxelement.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("vtx_uart = UART6", "vtx_type = SMARTAUDIO", "vtx_band = 1", "vtx_channel = 1", "vtx_power = 1",
                         "osd_displayport_device = MAX7456", "vcd_video_system = PAL", "osd_vtx_channel_pos = 2177"):
                text = cli(sock, "set " + line)
                check(f"transmitter element {line}", line.replace(" = ", " set to ") in text, text[-120:])
            for line in ("vtxtable bands 1", "vtxtable channels 8",
                         "vtxtable band 1 BOSCAM_A A FACTORY 5865 5845 5825 5805 5785 5765 5745 5725",
                         "vtxtable powerlevels 2", "vtxtable powervalues 0 1", "vtxtable powerlabels 25 200"):
                cli(sock, line)
            text = cli(sock, "vtxtable")
            check("transmitter element's table stored", "vtxtable band 1 BOSCAM_A A FACTORY 5865" in text, text[-200:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        vtx = SmartAudio()
        proc, sock = start(image, store)
        vtx.start()
        try:
            check("OSD transmitter element shows the SmartAudio device's band, channel and power label",
                  screen_wait(store, "A:1:25 "), repr(screen_row(store, 4)))
        finally:
            vtx.stop.set()
            stop(proc)
            sock.close()
        def row_wait(store, row, text, wait=10):
            deadline = time.time() + wait
            while time.time() < deadline:
                if screen_row(store, row)[1:1 + len(text)] == text:
                    return True
                time.sleep(0.1)
            return False

        store = os.path.join(work, "names.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("osd_displayport_device = MAX7456", "vcd_video_system = PAL"):
                text = cli(sock, "set " + line)
                check(f"names and messages {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            for item, pos in ((81, 2177), (8, 2209), (50, 2241)):
                check(f"OSD element {item} placed over MSP", msp(sock, 85, bytes([item]) + pos.to_bytes(2, "little")) == b"")
            check("OSD custom message element shows its placeholder while the message is empty",
                  row_wait(store, 4, "CUSTOM_MSG1 "), repr(screen_row(store, 4)))
            check("OSD craft name element shows its placeholder while the name is empty",
                  row_wait(store, 5, "CRAFT_NAME "), repr(screen_row(store, 5)))
            for kind, text in ((7, b"Hello pilot"), (2, b"quad one"), (1, b"jb")):
                check(f"text {kind} written over MSP", msp2(sock, 0x3007, bytes([kind, len(text)]) + text) == b"")
            check("OSD custom message element shows a message written while running",
                  row_wait(store, 4, "Hello pilot "), repr(screen_row(store, 4)))
            check("OSD craft name element shows a name written while running, in capitals",
                  row_wait(store, 5, "QUAD ONE "), repr(screen_row(store, 5)))
            check("OSD pilot name element shows a name written while running, in capitals",
                  row_wait(store, 6, "JB "), repr(screen_row(store, 6)))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set osd_craftname_msgs = ON")
            check("craft name messages on", "osd_craftname_msgs set to ON" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            names = set()
            deadline = time.time() + 10
            while time.time() < deadline and not any(n.startswith("LQ ") for n in names):
                reply = msp(sock, 10)
                if reply is not None:
                    names.add(reply.decode(errors="replace"))
                time.sleep(0.1)
            check("MSP name reply contains the warnings element's link quality with the craft name messages on",
                  any(n.startswith("LQ ") for n in names), repr(sorted(names)[:6]))
            check("OSD craft name element shows the warnings element's text with the craft name messages on",
                  row_wait(store, 5, "LQ "), repr(screen_row(store, 5)))
        finally:
            stop(proc)
            sock.close()
        store = os.path.join(work, "coretemp.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            status = msp(sock, 101)
            check("MSP status reply contains the core temperature",
                  status is not None and len(status) >= 5 and int.from_bytes(status[-5:-3], "little", signed=True) == 40,
                  repr(status))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "status")
            check("status line shows the measured supply and the core temperature",
                  "Vref=3.30V, Core temp=40degC" in text, text[-240:])
            for line in ("osd_displayport_device = MAX7456", "vcd_video_system = PAL", "osd_core_temp_pos = 2177"):
                text = cli(sock, "set " + line)
                check(f"core temperature element {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            check("OSD core temperature element shows the internal sensor's 40 degrees", screen_wait(store, "Cz 40."),
                  repr(screen_row(store, 4)))
        finally:
            stop(proc)
            sock.close()
        store = os.path.join(work, "resources.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "resource MOTOR 1")
            check("resource names the board's first motor pin", "# resource MOTOR 1 B00" in text, text[-120:])
            text = cli(sock, "resource SERVO 1 B00")
            check("resource notes a pin another owner holds",
                  "NOTE: B00 already assigned to MOTOR 1." in text and "Resource is set to B00" in text, text[-160:])
            text = cli(sock, "dma show")
            check("dma show lists the streams", "Currently active DMA:" in text and "DMA2 Stream 7: FREE" in text, text[-160:])
            text = cli(sock, "dma")
            check("dma lists the options set", "dma pin A02 0" in text and "# pin A02: DMA1 Stream 1 Channel 3" in text,
                  text[-160:])
            text = cli(sock, "timer")
            check("timer lists the board's map", "timer A02 AF1" in text and "# pin A02: TIM2 CH3 (AF1)" in text, text[-160:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "resource SERVO 1")
            check("resource keeps a stored servo pin across a restart", "# resource SERVO 1 B00" in text, text[-120:])
            text = cli(sock, "diff")
            check("diff lists the changed resource", "resource SERVO 1 B00" in text, text[-200:])
        finally:
            stop(proc)
            sock.close()
        store = os.path.join(work, "servos.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "mixer FLYING_WING")
            check("flying wing mixer set", "Mixer: FLYING_WING" in text, text[-120:])
            # The camera control holds the board's B09 at every start, before the servos take their pins.
            text = cli(sock, "resource CAMERA_CONTROL NONE")
            check("camera control pin freed for the wing's second servo", "Resource is freed" in text, text[-120:])
            for line in ("resource SERVO 1 B08", "resource SERVO 2 B09"):
                text = cli(sock, line)
                check(f"wing {line}", "Resource is set to " + line[-3:] in text, text[-160:])
            text = cli(sock, "set rx_uart = UART3")
            check("receiver port assigned for the wing", "rx_uart set to UART3" in text, text[-120:])
            text = cli(sock, "aux 0 12 0 1700 2100 0 0")
            check("passthrough mode on AUX1", "aux 0 12 0 1700 2100 0 0" in cli(sock, "aux"), text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        receiver = Receiver()
        receiver.start()
        try:
            time.sleep(3.0)
            setups = [line for line in servo_lines(store) if line[0] == "setup"]
            check("the wing's two servo outputs start at 50 Hz with a 1500 us center",
                  setups == [["setup", "0", "20000", "1500"], ["setup", "1", "20000", "1500"]], repr(setups))
            ok, values = until(lambda: servo_values(sock), lambda v: len(v) == 8 and v[3] == 1500 and v[4] == 1500)
            check("the wing's flaperons rest at their middle", ok and values[7] == 1000, repr(values))
            receiver.channels[4] = 1811
            receiver.channels[0] = 1811
            ok, values = until(lambda: servo_values(sock), lambda v: len(v) == 8 and v[3] == 2000 and v[4] == 1000)
            check("passthrough roll moves the flaperons apart", ok, repr(values))
            ok, pulses = until(lambda: [line for line in servo_lines(store) if line[0] == "pulse"],
                               lambda p: ["pulse", "0", "2000"] in p and ["pulse", "1", "1000"] in p, wait=5.0)
            check("the servo outputs take the flaperons' pulses in output order", ok, repr(pulses[-6:]))
            msp(sock, 212, bytes([3]) + struct.pack("<HHHBBI", 1000, 1900, 1500, 100, 255, 0))
            ok, values = until(lambda: servo_values(sock), lambda v: len(v) == 8 and v[3] == 1900)
            check("a servo's new limit from the configurator holds it at once", ok, repr(values))
        finally:
            receiver.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "servomotor.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            cli(sock, "mixer FLYING_WING")
            cli(sock, "resource SERVO 1 B00")
            cli(sock, "resource SERVO 2 B09")
            text = cli(sock, "resource SERVO 1")
            check("a servo on the wing's motor pin is stored", "# resource SERVO 1 B00" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(3.0)
            check("a servo on the motor's pin is refused and ends the servo setup", servo_lines(store) == [],
                  repr(servo_lines(store)))
        finally:
            stop(proc)
            sock.close()
        # The OSD's warning line over MSP: none with the default warnings and no arm switch, and the link quality
        # warning, blinking and critical, once it alone is on and no link reports a quality.
        store = os.path.join(work, "warnings.bin")
        proc, sock = start(image, store)
        try:
            # A beep at start-up leaves the visual beeper's mark for one rendering, which the first request takes.
            time.sleep(5.0)
            msp2(sock, 0x3005)
            quiet = msp2(sock, 0x3005)
            check("MSP OSD warnings reply is empty while no warning shows", quiet == bytes(2), repr(quiet))
            receiver_config = bytearray(msp(sock, 44) or bytes(39))
            receiver_config[25] = (receiver_config[25] + 5) % 200
            changed = msp(sock, 45, bytes(receiver_config))

            def restart_asked():
                status = msp(sock, 150)
                if status is None or len(status) < 22 + status[15]:
                    return None
                return status[21 + status[15]]
            passed, flag = until(restart_asked, lambda f: f == 1, wait=3.0)
            check("extended status reply says a restart is needed after that change", passed, repr(flag))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "status")
            check("an RC smoothing cutoff changed over MSP holds arming until a restart",
                  changed == b"" and "REBOOT_REQD" in text.split("Arming disable flags:")[-1], text[-160:])
            text = cli(sock, "set osd_warn_bitmask = 8192")
            check("link quality warning alone turned on", "osd_warn_bitmask set to 8192" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(3.0)
            ok, shown = until(lambda: msp2(sock, 0x3005), lambda r: r == b"\x83\x0cLINK QUALITY", wait=5.0)
            check("MSP OSD warnings reply gives the warning line with its blink and severity", ok, repr(shown))
        finally:
            stop(proc)
            sock.close()
        # The MSP receiver: with its feature on, the channels of MSP raw RC frames are the receiver's, the sticks
        # through the channel map. Then the MSP override over a CRSF receiver: with roll set for it, the roll of
        # fresh MSP frames replaces the receiver's while the override's box is on.
        store = os.path.join(work, "msprx.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "feature RX_MSP")
            check("MSP receiver feature on", "Enabled RX_MSP" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            seen = rc_stream(sock, [1600, 1400, 1300, 1700, 1100, 1200, 1800, 1900], 60)
            check("MSP raw RC frames are the MSP receiver's channels",
                  len(seen) >= 3 and seen[-1] == [1600, 1400, 1700, 1300, 1100, 1200, 1800, 1900], repr(seen[-2:]))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("feature -RX_MSP", "feature RX_SERIAL", "set rx_uart = UART3",
                         "set msp_override_channels_mask = 1", "aux 0 50 0 1700 2100 0 0",
                         "aux 1 27 1 1700 2100 0 0"):
                cli(sock, line)
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        receiver = Receiver()
        receiver.start()
        try:
            time.sleep(3.0)
            overriding = [1700, 1400, 1300, 1700, 1100, 1200, 1800, 1900]
            off = rc_stream(sock, overriding, 30)
            receiver.channels[4] = 1811
            time.sleep(0.6)
            on = rc_stream(sock, overriding, 30)
            check("MSP override leaves the receiver's roll while its box is off",
                  len(off) >= 2 and abs(off[-1][0] - 1500) <= 2, repr(off[-2:]))
            check("MSP override takes the roll of fresh MSP frames while its box is on, and no other stick",
                  len(on) >= 2 and on[-1][0] == 1700 and abs(on[-1][1] - 1500) <= 2 and abs(on[-1][2] - 1500) <= 2,
                  repr(on[-2:]))
            ok, values = until(lambda: rc_values(sock), lambda v: len(v) == 4 and abs(v[0] - 1500) <= 2, wait=5.0)
            check("MSP override gives the roll back once its frames stop", ok, repr(values))
            receiver.channels[4] = 992
            receiver.channels[0] = 1811
            moved, values = until(lambda: rc_values(sock), lambda v: len(v) == 4 and v[0] >= 2000, wait=5.0)
            receiver.channels[5] = 1811
            switched, held = until(lambda: rc_values(sock), lambda v: len(v) == 4 and abs(v[0] - 1500) <= 2, wait=5.0)
            check("failsafe switch puts the roll at its failsafe value while the receiver still sends",
                  moved and switched, f"{values} {held}")
            receiver.channels[5] = 992
            back, values = until(lambda: rc_values(sock), lambda v: len(v) == 4 and v[0] >= 2000, wait=5.0)
            check("failsafe switch off gives the roll back", back, repr(values))
        finally:
            receiver.stop.set()
            stop(proc)
            sock.close()
        if built("Pitot"):
            # The pitot: the host's I2C bus answers an MS4525 frame at 0x28, so naming the sensor finds it at the next
            # start, its first sample sets the sensor flag, and twenty samples at rest zero it.
            store = os.path.join(work, "pitot.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set pitot_hardware = MS4525")
                check("pitot hardware set to MS4525", "pitot_hardware set to MS4525" in text, text[-120:])
                # Boards without a default I2C device store bus zero, so the pilot names the bus as upstream needs.
                text = cli(sock, "set pitot_i2c_device = 1")
                check("pitot bus set to I2C1", "pitot_i2c_device set to 1" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store, extra={"ADAFLIGHT_PITOT_STEP": "40"})
            try:
                time.sleep(3.0)
                status = msp(sock, 101)
                check("MSP status shows the pitot after its first sample", status is not None and len(status) > 5
                      and (status[4] | status[5] << 8) & 0x80 != 0, repr(status))
                air = msp(sock, 170)
                speed, pressure = struct.unpack("<ii", air) if air is not None and len(air) == 8 else (0, 0)
                check("MSP pitot reply gives the airspeed and pressure of a step after the zeroing",
                      speed > 500 and pressure > 100, repr(air))
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "status")
                check("status lists the pitot as detected", "PITOT" in text.upper() or "MS4525" in text.upper(),
                      text[-300:])
            finally:
                stop(proc)
                sock.close()
        if built("Optical_Flow"):
            # An MT rangefinder and optical flow module over MSP: named by both hardware settings with both features on,
            # its range and flow frames arrive as MSP2 sensor messages, so both sensor flags show and the rangefinder
            # altitude follows the distance.
            store = os.path.join(work, "mtflow.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set rangefinder_hardware = MTF01")
                check("rangefinder hardware set to MTF01", "rangefinder_hardware set to MTF01" in text, text[-120:])
                text = cli(sock, "set opticalflow_hardware = MT")
                check("optical flow hardware set to MT", "opticalflow_hardware set to MT" in text, text[-120:])
                text = cli(sock, "feature RANGEFINDER")
                check("rangefinder feature on", "Enabled RANGEFINDER" in text, text[-120:])
                text = cli(sock, "feature OPTICALFLOW")
                check("optical flow feature on", "Enabled OPTICALFLOW" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            try:
                time.sleep(3.0)
                for _ in range(4):
                    msp2(sock, 0x1F01, struct.pack("<Bi", 100, 1500))
                    msp2(sock, 0x1F02, struct.pack("<Bii", 200, 10, -5))
                status = msp(sock, 101)
                check("MSP status shows the MT rangefinder and optical flow", status is not None and len(status) > 5
                      and (status[4] | status[5] << 8) & 0x50 == 0x50, repr(status))
                altitude = msp(sock, 58)
                check("MT distance frames set the rangefinder altitude", altitude is not None and len(altitude) >= 4
                      and abs(struct.unpack_from("<i", altitude, 0)[0] - 150) <= 2, repr(altitude))
            finally:
                stop(proc)
                sock.close()
        store = os.path.join(work, "oneshot.bin")
        for protocol in ("ONESHOT125", "PWM"):
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "set motor_pwm_protocol = " + protocol)
                check(f"{protocol} motor protocol set", "motor_pwm_protocol set to " + protocol in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            try:
                time.sleep(3.0)
                setups = [line for line in pwm_lines(store) if line[0] == "setup"]
                if protocol == "ONESHOT125":
                    check("OneShot125 motors start at their timers' rates with the minimum command",
                          setups == [["setup", "0", "56000000", "65535", "1000"],
                                     ["setup", "1", "56000000", "65535", "1000"],
                                     ["setup", "2", "42000000", "65535", "1000"],
                                     ["setup", "3", "42000000", "65535", "1000"]], repr(setups))
                    ok, pulses = until(lambda: pwm_lines(store),
                                       lambda p: ["pulse", "0", "7000"] in p and ["pulse", "2", "5250"] in p, wait=5.0)
                    check("OneShot125 motors idle at the minimum command's pulse", ok, repr(pulses[-6:]))
                    motors = msp(sock, 104)
                    check("the MSP motor reply gives OneShot125 values in microseconds",
                          motors is not None and motors[:8] == struct.pack("<4H", 1000, 1000, 1000, 1000), repr(motors))
                    msp(sock, 214, struct.pack("<8H", 1100, 1000, 1000, 1000, 1000, 1000, 1000, 1000))
                    ok, pulses = until(lambda: pwm_lines(store), lambda p: ["pulse", "0", "7700"] in p, wait=5.0)
                    check("a motor test value sets the OneShot125 pulse", ok, repr(pulses[-6:]))
                else:
                    check("PWM motors start at 480 Hz without an idle pulse",
                          setups[-4:] == [["setup", str(m), "28000000", "58333", "0"] for m in range(4)], repr(setups))
            finally:
                stop(proc)
                sock.close()
        store = os.path.join(work, "bidir.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "dshot_telemetry_info")
            check("dshot_telemetry_info reports DShot telemetry off", "Dshot telemetry not enabled" in text, text[-120:])
            text = cli(sock, "set dshot_bidir = ON")
            check("bidirectional DShot set", "dshot_bidir set to ON" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(3.0)
            msp(sock, 214, struct.pack("<8H", 1500, 1000, 1000, 1000, 1000, 1000, 1000, 1000))
            time.sleep(1.0)
            motors = msp(sock, 131)
            check("MSP motor configuration shows DShot telemetry in use", motors is not None and len(motors) >= 9
                  and motors[8] == 1, repr(motors))
            telemetry = msp(sock, 139)
            rpms = [struct.unpack_from("<IH", telemetry, 1 + 13 * m) for m in range(4)] \
                if telemetry is not None and len(telemetry) == 1 + 13 * 4 else []
            check("the MSP motor telemetry gives the spinning motor's RPM with no invalid replies",
                  len(rpms) == 4 and 4100 <= rpms[0][0] <= 4500 and rpms[0][1] == 0
                  and all(r == (0, 0) for r in rpms[1:]), repr(telemetry))
            sensor = msp(sock, 134)
            check("the MSP ESC sensor data reply takes the DShot RPM",
                  sensor is not None and len(sensor) == 1 + 3 * 4 and sensor[0] == 4
                  and 4100 <= struct.unpack_from("<H", sensor, 2)[0] <= 4500, repr(sensor))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "dshot_telemetry_info")
            reads = re.search(r"Dshot reads: (\d+)", text)
            check("the motors' replies are read", reads is not None and int(reads.group(1)) > 100, text[:200])
            check("no reply is invalid", "Dshot invalid pkts: 0\r\n" in text, text[:200])
            first = re.search(r"^ +1 +R---- +(\d+) +(\d+) +(\d+) +0\.00%", text, re.M)
            check("the spinning motor reports its eRPM and RPM",
                  first is not None and 29000 <= int(first.group(1)) <= 31000 and 4100 <= int(first.group(2)) <= 4500,
                  text[-700:])
            stopped = re.findall(r"^ +[234] +R---- +0 +0 +0 +0\.00%", text, re.M)
            check("the stopped motors report zero eRPM", len(stopped) == 3, text[-700:])
            text = cli(sock, "status")
            flags = re.search(r"Arming disable flags:([^\r\n]*)", text)
            check("arming does not wait for DShot telemetry every motor reports",
                  flags is not None and "DSHOT_TELEM" not in flags.group(1), text[-160:])
        finally:
            stop(proc)
            sock.close()
        store = os.path.join(work, "reorder.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "set motor_output_reordering = 1,0,2,3,4,5,6,7")
            check("the first two motors' outputs swapped", "motor_output_reordering set to 1,0,2,3" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(3.0)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "timer show")
            check("a timer owner takes the number of the motor pin it drives, whatever the output order",
                  re.search(r"TIM1:\r\n +CH2N: MOTOR 1\r\n", text) is not None
                  and re.search(r"TIM8:\r\n +CH3N: MOTOR 2\r\n", text) is not None, text[:400])
        finally:
            stop(proc)
            sock.close()
        if built("LED_Strip"):
            store = os.path.join(work, "ledstrip.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                text = cli(sock, "resource LED_STRIP 1")
                check("resource names the board's LED strip pin", "# resource LED_STRIP 1 B08" in text, text[-120:])
                text = cli(sock, "feature LED_STRIP")
                check("LED strip feature on", "Enabled LED_STRIP" in text, text[-120:])
                for line in ("led 0 0,0::C:2", "led 1 1,0::C:1"):
                    cli(sock, line)
                text = cli(sock, "led")
                check("two LEDs take their colors", "led 0 0,0::C:2" in text and "led 1 1,0::C:1" in text, text[-200:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            try:
                ok, lines = until(lambda: led_lines(store), lambda l: ["led", "0", "FF0000"] in l and ["led", "1", "FFFFFF"] in l,
                                  wait=8.0)
                check("the LED strip shows the red and white LEDs", ok, repr(lines[-6:]))
            finally:
                stop(proc)
                sock.close()
        store = os.path.join(work, "laps.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("gps_provider = NMEA", "gps_uart = UART4", "gps_lap_timer_gate_lat = 481173000",
                         "gps_lap_timer_gate_lon = 115166667", "gps_lap_timer_min_lap_time_s = 1",
                         "osd_displayport_device = MAX7456", "vcd_video_system = PAL", "osd_gps_lap_prev_pos = 2177"):
                text = cli(sock, "set " + line)
                check(f"lap timer {line}", line.replace(" = ", " set to ") in text, text[-120:])
            text = cli(sock, "feature GPS")
            check("lap timer GPS feature on", "Enabled GPS" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        gps = LapGPS()
        gps.start()
        try:
            time.sleep(9.0)
            row = screen_row(store, 4)
            lap = re.search(r"(\d+)\.(\d\d)", row)
            seconds = int(lap.group(1)) + int(lap.group(2)) / 100 if lap else None
            check("previous lap element shows the two-second lap through the gate",
                  seconds is not None and 1.8 <= seconds <= 2.2, repr(row))
        finally:
            gps.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "mspslots.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "get msp_")
            check("fresh configuration names the USB port and the host's MSP UART in the MSP slots",
                  "msp_1_uart = VCP" in text and "msp_2_uart = UART1" in text and "msp_3_uart = NONE" in text,
                  text[-240:])
            for line in ("msp_2_uart = NONE", "msp_3_uart = UART4"):
                text = cli(sock, "set " + line)
                check(f"MSP slot {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, vcp = start(image, store, port=VCP_PORT)
        uart4 = sock = None
        try:
            time.sleep(2.5)
            try:
                sock = socket.create_connection(("127.0.0.1", PORT), timeout=1)
                sock.settimeout(0.3)
                api = msp(sock, 1)
            except OSError:
                api = None
            check("UART1 serves no MSP with no slot naming it", api is None, repr(api))
            uart4 = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
            uart4.settimeout(0.3)
            api = msp(uart4, 1)
            check("UART4 answers MSP from the third slot", api is not None and len(api) == 3 and api[1] == 1, repr(api))
            api = msp(vcp, 1)
            check("USB port answers MSP from the first slot", api is not None and len(api) == 3, repr(api))
        finally:
            stop(proc)
            vcp.close()
            for extra in (uart4, sock):
                if extra is not None:
                    extra.close()
        store = os.path.join(work, "altasl.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("gps_provider = NMEA", "gps_uart = UART4", "osd_displayport_device = MAX7456",
                         "vcd_video_system = PAL", "osd_altitude_pos = 34945"):
                text = cli(sock, "set " + line)
                check(f"sea level altitude {line}", line.replace(" = ", " set to ") in text, text[-120:])
            text = cli(sock, "feature GPS")
            check("sea level altitude GPS feature on", "Enabled GPS" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        gps = GPS()
        gps.start()
        try:
            deadline = time.time() + 15
            while time.time() < deadline and "545.4" not in screen_row(store, 4):
                time.sleep(0.2)
            check("OSD altitude element's sea level variant shows the GPS altitude", "545.4" in screen_row(store, 4),
                  repr(screen_row(store, 4)))
        finally:
            gps.stop.set()
            stop(proc)
            sock.close()
        store = os.path.join(work, "serpass.bin")
        proc, sock = start(image, store)
        vcp = None
        line = None
        try:
            time.sleep(2.5)
            vcp = socket.create_connection(("127.0.0.1", VCP_PORT), timeout=1)
            vcp.settimeout(0.3)
            time.sleep(0.2)
            vcp.sendall(b"#")
            read_all(vcp, 0.8)
            text = cli(vcp, "serialpassthrough uart4 9600")
            check("serialpassthrough opens UART4 for the USB port",
                  "Port1: UART4" in text and "Port2: VCP" in text and "Port1 opened, baud = 9600." in text
                  and "Forwarding, power cycle to exit." in text, text[-240:])
            deadline = time.time() + 5
            while line is None and time.time() < deadline:
                try:
                    line = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
                except OSError:
                    time.sleep(0.1)
            check("the passthrough's UART4 port opens", line is not None)
            if line is not None:
                line.settimeout(0.3)
                time.sleep(0.2)
                line.sendall(b"from-the-device")
                got = collect(vcp, b"from-the-device", 3.0)
                check("serialpassthrough forwards UART4's bytes to the USB port", b"from-the-device" in got,
                      repr(got[-60:]))
                vcp.sendall(b"from-the-host")
                got = collect(line, b"from-the-host", 3.0)
                check("serialpassthrough forwards the USB port's bytes to UART4", b"from-the-host" in got,
                      repr(got[-60:]))
        finally:
            for s in (vcp, line):
                if s is not None:
                    s.close()
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        vcp = None
        try:
            time.sleep(2.5)
            vcp = socket.create_connection(("127.0.0.1", VCP_PORT), timeout=1)
            vcp.settimeout(0.3)
            time.sleep(0.2)
            vcp.sendall(b"#")
            read_all(vcp, 0.8)
            text = cli(vcp, "serialpassthrough uart4 9600 rx reset")
            check("serialpassthrough with a reset on DTR names the DTR drop",
                  "Forwarding, power cycle or drop DTR to exit." in text, text[-160:])
            vcp.close()
            vcp = None
            deadline = time.time() + 5
            while proc.poll() is None and time.time() < deadline:
                time.sleep(0.1)
            check("dropping the USB port's DTR ends the passthrough with a reset", proc.poll() == 0, repr(proc.poll()))
        finally:
            if vcp is not None:
                vcp.close()
            stop(proc)
            sock.close()
        store = os.path.join(work, "spekbind.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("serialrx_provider = SPEK2048", "rx_uart = UART3", "spektrum_sat_bind = 3",
                         "spektrum_sat_bind_autoreset = ON"):
                text = cli(sock, f"set {line}")
                check(f"bind setting {line}", line.replace(" = ", " set to ") in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        with open(store, "rb") as f:
            stored_before_bind = f.read()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "get spektrum_sat_bind")
            check("the power-up bind returns its count to zero", "spektrum_sat_bind = 0" in text, text[-120:])
        finally:
            stop(proc)
            sock.close()
        with open(store, "rb") as f:
            check("the power-up bind writes the configuration", f.read() != stored_before_bind)
        proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        try:
            time.sleep(2.5)
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sim.bind(("127.0.0.1", 9002))
            sim.settimeout(0.5)
            # A level craft at rest rolled ten degrees, in the Gazebo bridge's frames: no rates, gravity's
            # reaction along the body's up axis, and the attitude quaternion as the plugin sends it.
            half = math.radians(5.0)
            def fdm(t):
                return struct.pack("<18d", t, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, math.cos(half), math.sin(half),
                                   0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            motor_packet = None
            for i in range(80):
                sim.sendto(fdm(i * 0.01), ("127.0.0.1", 9003))
                if motor_packet is None:
                    try:
                        motor_packet = sim.recv(256)
                    except socket.timeout:
                        pass
                time.sleep(0.01)
            check("simulator link answers the first flight dynamics packet with a motor packet",
                  motor_packet is not None and len(motor_packet) == 16, repr(motor_packet))
            attitude = msp(sock, 108)
            angles = [int.from_bytes(attitude[i:i + 2], "little", signed=True) for i in range(0, 6, 2)] if attitude else []
            check("simulator attitude gives ten degrees of roll", len(angles) == 3 and abs(angles[0] - 100) <= 5
                  and abs(angles[1]) <= 5 and 0 <= angles[2] < 360, repr(angles))
            imu = msp(sock, 102)
            raw = [int.from_bytes(imu[i:i + 2], "little", signed=True) for i in range(0, 12, 2)] if imu else []
            check("simulator feeds the virtual accelerometer one g up and a still gyro",
                  len(raw) == 6 and abs(raw[2] - 512) <= 8 and abs(raw[0]) <= 8 and abs(raw[1]) <= 8
                  and raw[3:6] == [0, 0, 0], repr(raw))
            status = msp(sock, 101)
            if contains("Barometer"):
                check("simulator status shows the virtual barometer", status is not None and len(status) > 5
                      and (status[4] | status[5] << 8) & 0x02 != 0, repr(status))
            if contains("Compass"):
                check("simulator status shows the virtual compass", status is not None and len(status) > 5
                      and (status[4] | status[5] << 8) & 0x04 != 0, repr(status))
            imu = msp(sock, 102)
            mag = list(struct.unpack_from("<3h", imu, 12)) if imu and len(imu) >= 18 else None
            # The synthetic field (4096 counts, 60 degrees of inclination, 2 degrees of east declination) in the
            # body frame of the rolled craft, after the bridge's quarter turn of yaw between the simulator frame
            # and the flight frame.
            if contains("Compass"):
                check("virtual compass reads the fed field in the body frame",
                      mag is not None and abs(mag[0] - (-72)) <= 2 and abs(mag[1] - (-2632)) <= 2
                      and abs(mag[2] - (-3138)) <= 2, repr(mag))
            # A position in the Gazebo bridge's order (longitude, latitude, altitude); the virtual barometer takes
            # its pressure from the altitude and the virtual GPS its solution from all three.
            def fdm_at(t, lon, lat, alt):
                return struct.pack("<18d", t, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                   lon, lat, alt, 0.0)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            cli(sock, "feature GPS")
            cli(sock, "set altitude_source = BARO_ONLY")
            text = cli(sock, "set gps_provider = VIRTUAL")
            check("virtual GPS provider set", "gps_provider set to VIRTUAL" in text, text[-120:])
            text = cli(sock, "set debug_mode = GYRO_FILTERED")
            check("debug mode set to the filtered gyro", "debug_mode set to GYRO_FILTERED" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
            sim.close()
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        try:
            time.sleep(2.5)
            sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sim.bind(("127.0.0.1", 9002))
            sim.settimeout(0.5)
            for i in range(0, 600):
                sim.sendto(fdm_at(i * 0.01, -105.25, 40.0, 1600.0), ("127.0.0.1", 9003))
                time.sleep(0.01)
            gps = msp(sock, 106)
            fix = gps[0] if gps else None
            sats = gps[1] if gps and len(gps) > 1 else None
            lat = int.from_bytes(gps[2:6], "little", signed=True) if gps and len(gps) >= 10 else None
            lon = int.from_bytes(gps[6:10], "little", signed=True) if gps and len(gps) >= 10 else None
            check("virtual GPS gives a fix with twelve satellites at the fed position",
                  fix not in (None, 0) and sats == 12 and lat is not None and abs(lat - 400000000) <= 2000
                  and abs(lon + 1052500000) <= 2000, repr((fix, sats, lat, lon)))
            altitude = msp(sock, 109)
            alt_cm = int.from_bytes(altitude[0:4], "little", signed=True) if altitude and len(altitude) >= 4 else None
            if contains("Barometer"):
                check("virtual barometer altitude settles at a fed 1600 m",
                      alt_cm is not None and abs(alt_cm - 160000) <= 500, repr(alt_cm))
            for i in range(600, 950):
                sim.sendto(fdm_at(i * 0.01, -105.25, 40.0, 1620.0), ("127.0.0.1", 9003))
                time.sleep(0.01)
            altitude = msp(sock, 109)
            alt_cm = int.from_bytes(altitude[0:4], "little", signed=True) if altitude and len(altitude) >= 4 else None
            if contains("Barometer"):
                check("virtual barometer altitude follows a fed twenty metre climb",
                      alt_cm is not None and abs(alt_cm - 162000) <= 500, repr(alt_cm))
            # A roll rate of one radian per second: the filtered gyro's debug values show it on roll alone.
            def fdm_rolling(t):
                return struct.pack("<18d", t, 1.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                   -105.25, 40.0, 1620.0, 0.0)
            for i in range(950, 1030):
                sim.sendto(fdm_rolling(i * 0.01), ("127.0.0.1", 9003))
                time.sleep(0.01)
            reply = msp(sock, 254)
            debug = list(struct.unpack("<8h", reply[:16])) if reply and len(reply) >= 16 else None
            check("filtered gyro debug values show the fed roll rate on roll alone",
                  debug is not None and 45 <= abs(debug[0]) <= 70 and abs(debug[1]) <= 5 and abs(debug[2]) <= 5
                  and debug[3:] == [0, 0, 0, 0, 0], repr(debug))
            # A filter write from the configurator sets the gyro's filters up again at once: with both lowpass
            # stages at 1 Hz and the dynamic lowpass off, a reversed roll rate takes most of a second to show.
            filters = msp(sock, 92)
            slow = bytearray(filters or bytes(56))
            slow[0] = 1
            slow[20:22] = (1).to_bytes(2, "little")
            slow[22:24] = (1).to_bytes(2, "little")
            slow[24] = 0
            slow[25] = 0
            slow[29:31] = bytes(2)
            written = msp(sock, 93, bytes(slow))
            for i in range(1030, 1180):
                sim.sendto(fdm_rolling(i * 0.01), ("127.0.0.1", 9003))
                time.sleep(0.01)
            settled = debug_values(sock)
            for i in range(1180, 1190):
                sim.sendto(struct.pack("<18d", i * 0.01, -1.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0,
                                       0.0, 0.0, -105.25, 40.0, 1620.0, 0.0), ("127.0.0.1", 9003))
                time.sleep(0.01)
            turned = debug_values(sock)
            way = 1 if settled and settled[0] > 0 else -1
            check("a gyro filter write from the configurator slows the running filters without a restart",
                  written == b"" and len(settled) == 8 and abs(settled[0]) >= 45 and len(turned) == 8
                  and turned[0] * way > -30, f"{settled[:1]} {turned[:1]}")
            sim.close()
        finally:
            stop(proc)
            sock.close()
        # Simulator sticks and motor packets: the UDP receiver feature with the analog motor protocol the reference's
        # simulator build has. Packets of sixteen pulses arrive on port 9004, and a motor set over MSP returns as the
        # speed and raw motor packets, one pair per flight dynamics packet, while a feeder keeps both packet kinds flowing.
        store = os.path.join(work, "simrc.bin")
        proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            cli(sock, "feature -RX_SERIAL")
            text = cli(sock, "feature RX_UDP")
            check("UDP receiver feature set", "Enabled RX_UDP" in text, text[-120:])
            text = cli(sock, "set motor_pwm_protocol = PWM")
            check("analog motor protocol set for the simulator", "motor_pwm_protocol set to PWM" in text, text[-120:])
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        stop_feed = threading.Event()
        def feed_simulator():
            out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sticks = [1500, 1600, 1000, 1700] + [1000] * 12
            i = 0
            while not stop_feed.is_set():
                out.sendto(struct.pack("<18d", i * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                       0.0, -105.25, 40.0, 1600.0, 0.0), ("127.0.0.1", 9003))
                if i % 2 == 0:
                    out.sendto(struct.pack("<d16H", i * 0.01, *sticks), ("127.0.0.1", 9004))
                i += 1
                time.sleep(0.01)
            out.close()
        sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sim.bind(("127.0.0.1", 9002))
        sim.settimeout(0.05)
        raw_sim = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        raw_sim.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        raw_sim.bind(("127.0.0.1", 9001))
        raw_sim.settimeout(0.05)
        feeder = threading.Thread(target=feed_simulator, daemon=True)
        try:
            time.sleep(2.5)
            feeder.start()
            passed, values = until(lambda: rc_values(sock), lambda v: v == [1500, 1600, 1700, 1000], wait=5.0)
            check("UDP receiver pulses reach MSP RC", passed, repr(values))
            msp(sock, 214, struct.pack("<8H", 1500, 1000, 1000, 1000, 1000, 1000, 1000, 1000))
            speeds = None
            raw = None
            deadline = time.time() + 3.0
            while time.time() < deadline:
                try:
                    data = sim.recv(64)
                    if len(data) == 16:
                        speeds = struct.unpack("<4f", data)
                except socket.timeout:
                    pass
                try:
                    data = raw_sim.recv(128)
                    if len(data) == 66:
                        raw = struct.unpack("<H16f", data)
                except socket.timeout:
                    pass
                if speeds is not None and raw is not None and speeds[0] > 0.4:
                    break
            check("speed packet carries motor one at half throttle",
                  speeds is not None and abs(speeds[0] - 0.5) <= 0.01 and all(abs(v) <= 0.01 for v in speeds[1:]),
                  repr(speeds))
            check("raw packet carries four motors with motor one at 1500",
                  raw is not None and raw[0] == 4 and abs(raw[1] - 1500.0) <= 1.0
                  and all(abs(v - 1000.0) <= 1.0 for v in raw[2:5]), repr(raw))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "status")
            flags = text.split("Arming disable flags:")[-1]
            check("UDP frames clear RXLOSS", "Arming disable flags:" in text and "RXLOSS" not in flags,
                  flags.strip()[:80])
        finally:
            stop_feed.set()
            stop(proc)
            sock.close()
            sim.close()
            raw_sim.close()
        # An armed craft under the simulator link: the arm switch on AUX1 arms with the sticks fed over UDP, a
        # passthrough request while armed is refused and MSP goes on, the switch disarms, and the flight count
        # is saved half a second after the disarm.
        store = os.path.join(work, "simarm.bin")
        proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            for line in ("feature -RX_SERIAL", "feature RX_UDP", "set motor_pwm_protocol = PWM",
                         "aux 0 0 0 1700 2100 0 0", "set stats_min_armed_time_s = 0"):
                cli(sock, line)
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            stop(proc)
            sock.close()
        proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        stop_feed = threading.Event()
        arm_sticks = [1500, 1500, 1000, 1500] + [1000] * 12

        def feed_armed():
            out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            i = 0
            while not stop_feed.is_set():
                out.sendto(struct.pack("<18d", i * 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                       0.0, -105.25, 40.0, 1600.0, 0.0), ("127.0.0.1", 9003))
                if i % 2 == 0:
                    out.sendto(struct.pack("<d16H", i * 0.01, *arm_sticks), ("127.0.0.1", 9004))
                i += 1
                time.sleep(0.01)
            out.close()

        def armed():
            status = msp(sock, 150)
            return None if status is None or len(status) < 7 else bool(status[6] & 1)
        feeder = threading.Thread(target=feed_armed, daemon=True)
        try:
            time.sleep(2.5)
            feeder.start()
            time.sleep(6.0)
            check("craft stays disarmed with the arm switch off", armed() is False, repr(armed()))
            arm_sticks[4] = 1800
            passed, value = until(armed, lambda a: a is True, wait=8.0)
            check("arm switch arms the craft under the simulator link", passed, repr(value))
            if passed:
                four_way_count = msp(sock, 245)
                serial_port = msp(sock, 245, bytes([0xFD, 51]))
                api = msp(sock, 1)
                check("passthrough requests while armed are refused and MSP goes on",
                      four_way_count == b"\x00" and serial_port == b"\x00" and api is not None and len(api) == 3,
                      repr((four_way_count, serial_port, api)))
            time.sleep(1.0)
            arm_sticks[4] = 1000
            passed, value = until(armed, lambda a: a is False, wait=8.0)
            check("arm switch disarms the craft", passed, repr(value))
            time.sleep(2.0)
        finally:
            stop_feed.set()
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            sock.sendall(b"#")
            read_all(sock, 0.8)
            text = cli(sock, "get stats_total_flights")
            check("flight count is saved after the disarm", "stats_total_flights = 1" in text, text[-120:])
        finally:
            stop(proc)
            sock.close()
        # Simulator time scaling: flight dynamics packets whose timestamps advance 15 ms per 10 ms of real time set
        # the image's clock to one and a half times real time, read from System Uptime over a real interval.
        store = os.path.join(work, "simrate.bin")
        proc, sock = start(image, store, extra={"ADAFLIGHT_SIMULATOR": "gazebo,127.0.0.1"})
        stop_feed = threading.Event()
        def feed_fast():
            out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            i = 0
            while not stop_feed.is_set():
                out.sendto(struct.pack("<18d", i * 0.015, 0.0, 0.0, 0.0, 0.0, 0.0, -9.80665, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                       0.0, -105.25, 40.0, 1600.0, 0.0), ("127.0.0.1", 9003))
                i += 1
                time.sleep(0.01)
            out.close()
        feeder = threading.Thread(target=feed_fast, daemon=True)
        try:
            time.sleep(2.5)
            feeder.start()
            time.sleep(2.0)
            def uptime():
                text = cli(sock, "status", wait=1.0)
                found = re.search(r"System Uptime: (\d+)", text)
                return int(found.group(1)) if found else None, time.time()
            sock.sendall(b"#")
            read_all(sock, 0.8)
            first, t_first = uptime()
            time.sleep(6.0)
            second, t_second = uptime()
            ratio = (second - first) / (t_second - t_first) if first is not None and second is not None else None
            check("simulator timestamps at one and a half times real time scale the uptime",
                  ratio is not None and 1.3 <= ratio <= 1.7, repr((first, second, round(t_second - t_first, 2), ratio)))
        finally:
            stop_feed.set()
            stop(proc)
            sock.close()
        # The status replies name the PID profile, the rate profile and the battery profile in use.
        store = os.path.join(work, "profiles.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)

            def profiles():
                status, extended = msp(sock, 101), msp(sock, 150)
                if status is None or extended is None or len(status) < 11 or len(extended) < 16:
                    return None
                return status[10], extended[10], extended[14], extended[-1]
            first = profiles()
            acks = [msp(sock, 210, bytes([choice])) for choice in (1, 0x80 | 2, 0x40 | 1)]
            passed, now = until(profiles, lambda p: p == (1, 1, 2, 1), wait=3.0)
            check("status replies name the selected PID, rate and battery profiles",
                  first == (0, 0, 0, 0) and acks == [b""] * 3 and passed, repr((first, acks, now)))
        finally:
            stop(proc)
            sock.close()
        # What a board reports for a request: its link, so an MSP arming disable from one link outlasts another
        # link's enable, and the 3D feature, so a motor write with it on reads back as written.
        store = os.path.join(work, "links.bin")
        proc, sock = start(image, store)
        vcp = socket.create_connection(("127.0.0.1", VCP_PORT), timeout=1)
        vcp.settimeout(0.3)
        try:
            time.sleep(2.5)

            def arming_flags():
                status = msp(sock, 150)
                if status is None or len(status) < 16 or len(status) < 21 + status[15]:
                    return None
                at = 16 + status[15]
                return int.from_bytes(status[at + 1:at + 5], "little")
            before = arming_flags()
            msp(sock, 99, bytes([1, 0]))
            held = arming_flags()
            msp(vcp, 99, bytes([0, 0]))
            other = arming_flags()
            msp(sock, 99, bytes([0, 0]))
            own = arming_flags()
            bit = held & ~before if None not in (before, held) else 0
            check("MSP arming disable from one link outlasts another link's enable",
                  None not in (other, own) and bit != 0 and other & bit != 0 and own & bit == 0,
                  repr((before, held, other, own)))
            sock.sendall(b"#")
            read_all(sock, 0.8)
            cli(sock, "feature 3D")
            cli(sock, "save", wait=2.0)
            proc.wait(timeout=10)
        finally:
            vcp.close()
            stop(proc)
            sock.close()
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)
            read_back = []
            for value in (1500, 1300):
                msp(sock, 214, value.to_bytes(2, "little") * 4 + (1500).to_bytes(2, "little") * 4)
                time.sleep(0.3)
                outputs = msp(sock, 104)
                read_back.append([int.from_bytes(outputs[i:i + 2], "little") for i in range(0, 8, 2)]
                                 if outputs else None)
            check("motor writes with the 3D feature on read back as written",
                  read_back == [[1500] * 4, [1300] * 4], repr(read_back))
            msp(sock, 214, (1500).to_bytes(2, "little") * 8)
        finally:
            stop(proc)
            sock.close()
        # A serial passthrough request over MSP: a port the board lacks is refused, and an open port's bytes are
        # forwarded both ways with the request's port until a restart.
        if contains("GPS"):
            store = os.path.join(work, "msppass.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                for line in ("gps_provider = NMEA", "gps_uart = UART4"):
                    cli(sock, "set " + line)
                cli(sock, "feature GPS")
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            uart4 = None
            try:
                time.sleep(2.5)
                uart4 = socket.create_connection(("127.0.0.1", GPS_PORT), timeout=1)
                uart4.settimeout(0.3)
                refused = msp(sock, 245, bytes([0xFD, 57]))
                api = msp(sock, 1)
                check("serial passthrough to a port the board lacks is refused and MSP goes on",
                      refused == b"\x00" and api is not None and len(api) == 3, repr((refused, api)))
                started = msp(sock, 245, bytes([0xFD, 54]))
                check("serial passthrough to the open GPS port is taken", started == b"\x01", repr(started))
                read_all(uart4, 0.5)
                sock.sendall(b"to the module 123\r\n")
                heard = collect(uart4, b"123\r\n", 3.0)
                check("bytes from the request's port reach the named port", b"to the module 123\r\n" in heard,
                      repr(heard[-40:]))
                uart4.sendall(b"$GPTXT,from the module*00\r\n")
                heard = collect(sock, b"*00\r\n", 3.0)
                check("bytes from the named port reach the request's port",
                      b"$GPTXT,from the module*00\r\n" in heard, repr(heard[-40:]))
                sock.sendall(b"$M<" + bytes([0, 1, 1]))
                heard = collect(uart4, b"$M<", 3.0)
                answered = msp_pushes(read_all(sock, 0.5), 1)
                check("MSP request after the passthrough's start is forwarded and not answered",
                      b"$M<\x00\x01\x01" in heard and not answered, repr((heard[-12:], answered)))
            finally:
                if uart4 is not None:
                    uart4.close()
                stop(proc)
                sock.close()
        # The 4-way interface after its passthrough request, without an ESC on the motor pins: the interface's own
        # frames are answered, a flash init finds no bootloader, a frame with a bad check is refused, MSP stays
        # silent until the exit command, and the motors run again after it.
        store = os.path.join(work, "fourway.bin")
        proc, sock = start(image, store)
        try:
            time.sleep(2.5)

            def four_way(command, params=b"\x00"):
                body = bytes([0x2F, command, 0, 0, len(params) & 0xFF]) + params
                return body + crc16_xmodem(body).to_bytes(2, "big")

            def four_way_reply(command, wait=5.0, data=b""):
                """A 4-way reply's output parameters and acknowledgement, or None with the bytes read."""
                deadline = time.time() + wait
                while time.time() < deadline:
                    data += read_all(sock, 0.1)
                    at = data.find(bytes([0x2E, command]))
                    if at >= 0 and len(data) >= at + 5:
                        count = data[at + 4] or 256
                        whole = data[at:at + count + 8]
                        if len(whole) == count + 8 and crc16_xmodem(whole[:-2]).to_bytes(2, "big") == whole[-2:]:
                            return whole[5:5 + count], whole[5 + count]
                return None, data
            count = msp(sock, 245)
            check("4-way passthrough request answers the count of motor outputs", count == b"\x04", repr(count))
            sock.sendall(four_way(0x32))
            name = four_way_reply(0x32)
            check("4-way interface answers its name", name == (b"m4wFCIntf", 0), repr(name))
            # Three connect attempts each send a 21-byte boot message at 52 microseconds a bit, so a reply
            # sooner than 30 ms means the pins saw no bootloader traffic.
            sock.settimeout(8.0)
            began = time.time()
            sock.sendall(four_way(0x37))
            try:
                first = sock.recv(1)
            except OSError:
                first = b""
            waited = time.time() - began
            sock.settimeout(0.3)
            started = four_way_reply(0x37, wait=8.0, data=first)
            check("4-way flash init without an ESC ends in the general error after its connect attempts",
                  started == (bytes(4), 0x0F) and waited >= 0.03, repr((started, round(waited, 4))))
            sock.sendall(four_way(0x37, b"\x07"))
            channel = four_way_reply(0x37)
            check("4-way flash init for an ESC past the count is an invalid channel", channel == (b"\x00", 0x08),
                  repr(channel))
            sock.sendall(four_way(0x32)[:-1] + b"\x00")
            broken = four_way_reply(0x32)
            check("4-way frame with a bad check is refused", broken == (b"\x00", 0x03), repr(broken))
            sock.sendall(b"$M<" + bytes([0, 1, 1]))
            inside = read_all(sock, 0.5)
            check("MSP request inside the 4-way interface gets no answer", inside == b"", repr(inside))
            sock.sendall(four_way(0x34))
            left = four_way_reply(0x34)
            api = msp(sock, 1)
            check("4-way exit command is acknowledged and MSP answers again",
                  left == (b"\x00", 0) and api is not None and len(api) == 3, repr((left, api)))
            ack = msp(sock, 214, b"".join(v.to_bytes(2, "little") for v in [1100, 1200, 1300, 1400] + [1000] * 4))
            time.sleep(0.3)
            outputs = msp(sock, 104)
            values = [int.from_bytes(outputs[i:i + 2], "little") for i in range(0, 8, 2)] if outputs else []
            check("motors run again after the 4-way exit", ack == b"" and values == [1100, 1200, 1300, 1400],
                  repr((ack, values)))
            msp(sock, 214, (1000).to_bytes(2, "little") * 8)
        finally:
            stop(proc)
            sock.close()
        # A GPS solution over MSP with the MSP provider: the raw form and an MSP GPS sensor's form each show in
        # the GPS reply, and the status reports a GPS from the first one until solutions stop.
        if contains("GPS"):
            store = os.path.join(work, "mspgps.bin")
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)
                sock.sendall(b"#")
                read_all(sock, 0.8)
                cli(sock, "feature GPS")
                text = cli(sock, "set gps_provider = MSP")
                check("MSP GPS provider set", "gps_provider set to MSP" in text, text[-120:])
                cli(sock, "save", wait=2.0)
                proc.wait(timeout=10)
            finally:
                stop(proc)
                sock.close()
            proc, sock = start(image, store)
            try:
                time.sleep(2.5)

                def gps_sensor_reported():
                    status = msp(sock, 101)
                    return None if status is None or len(status) < 6 else bool(status[4] & 0x08)

                def gps_solution():
                    raw = msp(sock, 106)
                    return None if raw is None or len(raw) < 18 else struct.unpack("<BBiiHHHH", raw[:18])
                check("no GPS reported before a solution arrives over MSP", gps_sensor_reported() is False,
                      repr(gps_sensor_reported()))
                ack = msp(sock, 201, struct.pack("<BBiiHH", 1, 9, 401234567, -1052345678, 1650, 345))
                found, solution = until(gps_solution, lambda s: s is not None and s[1] == 9)
                check("raw GPS solution over MSP shows in the GPS reply",
                      ack == b"" and found and solution[:6] == (2, 9, 401234567, -1052345678, 1650, 345),
                      repr((ack, solution)))
                found, reported = until(gps_sensor_reported, lambda r: r is True)
                check("GPS link takes the solution and reports a GPS", found, repr(reported))
                sensor = struct.pack("<BHIBBHHHHiiiiiiHHHBBBBB", 0, 2300, 123456789, 3, 14, 120, 180, 25, 135, -1052000000,
                                     400500000, 170050, 300, 400, -10, 12345, 0, 2026, 11, 10, 9, 0, 0)
                ack = msp2(sock, 0x1F03, sensor)
                found, solution = until(gps_solution, lambda s: s is not None and s[1] == 14)
                check("MSP GPS sensor's solution shows in the GPS reply with its speed, course and dilution",
                      ack == b"" and found and solution == (2, 14, 400500000, -1052000000, 1700, 500, 1234, 135),
                      repr((ack, solution)))
                found, reported = until(gps_sensor_reported, lambda r: r is False, wait=8.0)
                check("status stops reporting a GPS once solutions stop", found, repr(reported))
                ack = msp(sock, 201, struct.pack("<BBiiHH", 1, 7, 401234000, -1052345000, 1600, 100))
                found, reported = until(gps_sensor_reported, lambda r: r is True)
                check("solution after a loss is taken again", ack == b"" and found, repr((ack, reported)))
            finally:
                stop(proc)
                sock.close()
        # The command-line MSP client against the image's port: one request, a refused one, the dump of
        # every read command, and a port that does not answer.
        client = os.path.join(os.path.dirname(os.path.abspath(__file__)), "msp", "bin", "adaflight_msp")
        if os.path.exists(client):
            port = f"tcp:127.0.0.1:{PORT}"
            store = os.path.join(work, "client.bin")
            proc, sock = start(image, store)
            sock.close()
            try:
                time.sleep(2.5)

                def run(*words):
                    done = subprocess.run([client, *words], capture_output=True, text=True, timeout=120)
                    return done.returncode, done.stdout.strip()
                status, variant = run("request", port, "2")
                check("MSP client reads the firmware variant", status == 0 and variant == "4144464c", variant)
                status, unknown = run("request", port, "9")
                check("MSP client reports a refused request", status == 0 and unknown == "refused", unknown)
                status, dump = run("dump", port)
                lines = dump.splitlines()
                check("MSP client's dump gets a reply or a refusal for every read command",
                      status == 0 and len(lines) > 50 and "MSP_API_VERSION 1 000131" in lines
                      and not any(line.endswith("no reply") for line in lines), repr(lines[:3]))
                status, nothing = run("request", "tcp:127.0.0.1:1", "1")
                check("MSP client fails on a port it cannot open", status == 1 and nothing == "", nothing)
            finally:
                stop(proc)
            # The client's backup, restore and comparison through the image's command line. A backup and a
            # restore each end the image, as an exit and a save do, so each runs against a fresh start.
            store = os.path.join(work, "backup.bin")

            def tool(*words):
                proc, sock = start(image, store)
                sock.close()
                try:
                    time.sleep(2.5)
                    done = subprocess.run([client, *words], capture_output=True, text=True, timeout=180)
                    return done.returncode, done.stdout, done.stderr
                finally:
                    stop(proc)

            def kept(name, text):
                full = os.path.join(work, name)
                with open(full, "w") as out:
                    out.write(text)
                return full

            def compared(one, other):
                done = subprocess.run([client, "diff", one, other], capture_output=True, text=True, timeout=60)
                return done.returncode, done.stdout.splitlines()
            status, first, errors = tool("backup", port)
            lines = first.splitlines()
            check("MSP client's backup is the command line's list of changed settings",
                  status == 0 and "defaults nosave" in lines and lines[-1:] == ["save"] and "###" not in first
                  and not any(line.startswith("diff all") for line in lines), repr((status, lines[:3], errors)))
            changes = ("# a change\nset craft_name = TOOLTEST\n\naux 0 0 0 1700 2100 0 0\n"
                       "profile 1\nset p_roll = 51\n")
            status, said, errors = tool("restore", port, kept("changes.txt", changes))
            check("MSP client's restore sends a file's lines and saves",
                  status == 0 and said == "restored 4 lines and saved\n", repr((status, said, errors)))
            status, second, errors = tool("backup", port)
            differs, found = compared(kept("first.txt", first), kept("second.txt", second))
            check("MSP client's comparison lists the restored changes",
                  status == 0 and differs == 1
                  and found == ["+ aux 0 0 0 1700 2100 0 0", "~ profile: 0 -> 1", "+ profile 1: set p_roll = 51",
                                "+ set craft_name = TOOLTEST"], repr((status, differs, found)))
            status, said, errors = tool("restore", port, kept("first.txt", first))
            again, third, _ = tool("backup", port)
            differs, found = compared(kept("first.txt", first), kept("third.txt", third))
            check("MSP client's restore of a backup brings its configuration back",
                  status == 0 and again == 0 and differs == 0 and found == [] and third == first,
                  repr((status, said, errors, differs, found)))
            status, said, errors = tool("restore", port, kept("bad.txt", "set craft_name = OTHER\nset no_such = 1\n"))
            check("MSP client's restore reports a refused line and saves nothing",
                  status == 1 and said == "" and "set no_such = 1" in errors
                  and "1 of 2 lines failed; nothing saved" in errors, repr((status, said, errors)))
            status, fourth, errors = tool("backup", port)
            check("refused restore leaves the configuration as it was", status == 0 and fourth == first, errors)
            status, whole, errors = tool("backup", port, "all")
            lines = whole.splitlines()
            check("MSP client's whole backup lists settings at their defaults",
                  status == 0 and len(lines) > 500 and "set craft_name = -" in lines
                  and "set craft_name = -" not in first.splitlines(), repr((status, len(lines), errors)))
        else:
            print("SKIP the checks of the MSP client: tools/msp is not built")
    print(f"host smoke: {'all checks passed' if not failures else str(len(failures)) + ' failed'}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
