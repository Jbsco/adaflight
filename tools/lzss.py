#!/usr/bin/env python3
"""LZSS with no entropy stage, as Adaflight.LZSS decodes it.

usage: lzss.py compress <in> <out>
       lzss.py vectors <out.csv>

A stream is a 32-bit big-endian length, then tokens written most significant bit first: a flag bit, then an 8-bit
literal (flag 0) or a 12-bit distance less one and a 4-bit count less three (flag 1). The encoder takes the longest
match among the last 64 positions with the same three bytes ahead, within 4096 bytes back. The vectors mode writes
the decoder's test cases: drawn data with their streams, and malformed streams with the status they give,
each hex string as a chunk count and its chunks.
"""
import random
import sys
from collections import deque

OFFSET_BITS = 12
COUNT_BITS = 4
MIN_MATCH = 3
WINDOW = 1 << OFFSET_BITS
MAX_MATCH = MIN_MATCH + (1 << COUNT_BITS) - 1
CHAIN = 64


class Bits:
    def __init__(self):
        self.out, self.acc, self.n = bytearray(), 0, 0

    def put(self, value, count):
        self.acc = (self.acc << count) | value
        self.n += count
        while self.n >= 8:
            self.n -= 8
            self.out.append((self.acc >> self.n) & 0xFF)
        self.acc &= (1 << self.n) - 1

    def done(self):
        if self.n:
            self.out.append((self.acc << (8 - self.n)) & 0xFF)
        return bytes(self.out)


def compress(data: bytes) -> bytes:
    bits = Bits()
    bits.put(len(data), 32)
    recent = {}
    i = 0
    while i < len(data):
        best_len, best_dist = 0, 0
        for j in reversed(recent.get(data[i:i + MIN_MATCH], ())):
            dist = i - j
            if dist > WINDOW:
                break
            length = 0
            while length < MAX_MATCH and i + length < len(data) and data[j + length] == data[i + length]:
                length += 1
            if length > best_len:
                best_len, best_dist = length, dist
                if length == MAX_MATCH:
                    break
        if best_len >= MIN_MATCH:
            bits.put(1, 1)
            bits.put(best_dist - 1, OFFSET_BITS)
            bits.put(best_len - MIN_MATCH, COUNT_BITS)
            step = best_len
        else:
            bits.put(0, 1)
            bits.put(data[i], 8)
            step = 1
        for k in range(i, min(i + step, len(data) - MIN_MATCH + 1)):
            recent.setdefault(data[k:k + MIN_MATCH], deque(maxlen=CHAIN)).append(k)
        i += step
    return bits.done()


def decompress(stream: bytes, size: int):
    """The decoded bytes and a status named as Adaflight.LZSS names it."""
    out = bytearray()
    if len(stream) < 4:
        return bytes(size), "truncated"
    if int.from_bytes(stream[:4], "big") != size:
        return bytes(size), "bad_length"
    total, bit = len(stream) * 8, 32

    def read(n):
        nonlocal bit
        v = 0
        for _ in range(n):
            v = v * 2 + ((stream[bit // 8] >> (7 - bit % 8)) & 1)
            bit += 1
        return v

    while len(out) < size:
        if bit >= total:
            return bytes(out) + bytes(size - len(out)), "truncated"
        if read(1) == 0:
            if bit > total - 8:
                return bytes(out) + bytes(size - len(out)), "truncated"
            out.append(read(8))
        else:
            if bit > total - (OFFSET_BITS + COUNT_BITS):
                return bytes(out) + bytes(size - len(out)), "truncated"
            dist, count = read(OFFSET_BITS) + 1, read(COUNT_BITS) + MIN_MATCH
            if dist > len(out):
                return bytes(out) + bytes(size - len(out)), "bad_distance"
            if count > size - len(out):
                return bytes(out) + bytes(size - len(out)), "overrun"
            for _ in range(count):
                out.append(out[-dist])
    return bytes(out), "done"


def draw(rng: random.Random, kind: int) -> bytes:
    n = rng.randint(0, 1500)
    if kind == 0:
        return bytes(rng.randrange(256) for _ in range(n))
    if kind == 1:
        words = [bytes(rng.randrange(97, 123) for _ in range(rng.randint(2, 9))) for _ in range(rng.randint(4, 40))]
        out = bytearray()
        while len(out) < n:
            out += rng.choice(words) + b" "
        return bytes(out[:n])
    if kind == 2:
        out = bytearray(n)
        for _ in range(n // 10):
            out[rng.randrange(n)] = rng.randrange(256) if n else 0
        return bytes(out)
    if kind == 3:
        record = bytes(rng.randrange(256) for _ in range(rng.randint(3, 40)))
        out = bytearray()
        while len(out) < n:
            r = bytearray(record)
            r[rng.randrange(len(r))] = rng.randrange(256)
            out += r
        return bytes(out[:n])
    if kind == 4:
        return bytes([rng.randrange(256)]) * n
    head = bytes(rng.randrange(256) for _ in range(rng.randint(3, 60)))
    filler = bytes(rng.randrange(256) for _ in range(WINDOW - len(head) + rng.randint(-2, 2)))
    return head + filler + head


def chunks(hexs: str) -> str:
    """A hex string as its chunk count and chunks of at most 4000 characters, fields the checker can hold."""
    parts = [hexs[k:k + 4000] for k in range(0, len(hexs), 4000)] or [""]
    return f"{len(parts)}," + ",".join(parts)


def vectors(path: str) -> None:
    rng = random.Random(20261031)
    lines = []
    for case in range(240):
        data = draw(rng, case % 6)
        stream = compress(data)
        back, status = decompress(stream, len(data))
        assert status == "done" and back == data
        lines.append(f"lzss,{case},done,{len(data)},{chunks(stream.hex())},{chunks(data.hex())}")
    case = 240
    for _ in range(60):
        data = draw(rng, rng.randrange(1, 4)) or b"abcabcabc"
        stream = compress(data)
        how = rng.randrange(4)
        size = len(data)
        if how == 0:
            stream = stream[:rng.randrange(0, len(stream))]
        elif how == 1:
            size = len(data) + rng.choice((-1, 1, 7)) if len(data) else 1
            size = max(0, size)
        elif how == 2:
            first = Bits()
            first.put(size, 32)
            first.put(1, 1)
            first.put(rng.randrange(0, WINDOW), OFFSET_BITS)
            first.put(rng.randrange(0, 16), COUNT_BITS)
            stream = first.done() + stream[4:]
        else:
            count = rng.randint(MIN_MATCH, MAX_MATCH)
            size = 1 + count - rng.randint(1, min(3, count))
            cut = Bits()
            cut.put(size, 32)
            cut.put(0, 1)
            cut.put(65, 8)
            cut.put(1, 1)
            cut.put(0, OFFSET_BITS)
            cut.put(count - MIN_MATCH, COUNT_BITS)
            stream = cut.done()
        back, status = decompress(stream, size)
        lines.append(f"lzss,{case},{status},{size},{chunks(stream.hex())},{chunks(back.hex())}")
        case += 1
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main() -> None:
    if len(sys.argv) == 4 and sys.argv[1] == "compress":
        data = open(sys.argv[2], "rb").read()
        stream = compress(data)
        assert decompress(stream, len(data)) == (data, "done")
        open(sys.argv[3], "wb").write(stream)
    elif len(sys.argv) == 3 and sys.argv[1] == "vectors":
        vectors(sys.argv[2])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
