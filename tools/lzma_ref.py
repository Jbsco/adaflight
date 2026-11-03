#!/usr/bin/env python3
"""LZMA streams as Adaflight.LZMA decodes them, and a second decoder with its statuses.
usage: lzma_ref.py compress <in> <out>
       lzma_ref.py vectors <out.csv>
A stream is a 32-bit big-endian length, then raw LZMA1 data with no literal context bits, no literal position bits
and no position bits, which Python's lzma module writes. The decoder here follows Adaflight.LZMA step for step and
names its statuses the same way; the vectors mode writes the Ada decoder's test cases: drawn data with their
streams, and malformed streams with the status and output this decoder gives, each hex string as a chunk count and
its chunks.
"""
import lzma
import random
import sys

FILTERS = [{"id": lzma.FILTER_LZMA1, "preset": 9 | lzma.PRESET_EXTREME, "lc": 0, "lp": 0, "pb": 0,
            "dict_size": 1 << 20}]
SPECIAL_DISTANCE = {4: 4, 5: 6, 6: 8, 7: 12, 8: 16, 9: 24, 10: 32, 11: 48, 12: 64, 13: 96}
SPECIAL_BITS = {4: 1, 5: 1, 6: 2, 7: 2, 8: 3, 9: 3, 10: 4, 11: 4, 12: 5, 13: 5}
MASK = 0xFFFFFFFF


def compress(data: bytes) -> bytes:
    return len(data).to_bytes(4, "big") + lzma.compress(data, format=lzma.FORMAT_RAW, filters=FILTERS)


class Decoder:
    def __init__(self, stream: bytes):
        self.stream, self.read = stream, 4
        self.range, self.code = MASK, 0
        self.exhausted, self.corrupt = False, False

    def next_byte(self):
        if self.read < len(self.stream):
            b = self.stream[self.read]
            self.read += 1
            return b
        self.exhausted = True
        return 0

    def normalize(self):
        if self.range < 1 << 24:
            b = self.next_byte()
            self.range = (self.range << 8) & MASK
            self.code = ((self.code << 8) | b) & MASK

    def bit(self, probs, i):
        p = probs[i]
        bound = (self.range >> 11) * p
        if self.code < bound:
            self.range = bound
            probs[i] = p + (2048 - p) // 32
            b = 0
        else:
            self.range = (self.range - bound) & MASK
            self.code = (self.code - bound) & MASK
            probs[i] = p - p // 32
            b = 1
        self.normalize()
        return b

    def tree(self, probs, base, bits):
        index = 1
        for _ in range(bits):
            index = index * 2 + self.bit(probs, base + index)
        return index - (1 << bits)

    def reverse_tree(self, probs, base, bits):
        index, value = 1, 0
        for i in range(bits):
            b = self.bit(probs, base + index)
            index = index * 2 + b
            value += b << i
        return value

    def direct_bits(self, count):
        value = 0
        for _ in range(count):
            self.range >>= 1
            self.code = (self.code - self.range) & MASK
            t = (0 - (self.code >> 31)) & MASK
            self.code = (self.code + (self.range & t)) & MASK
            if self.code == self.range:
                self.corrupt = True
            self.normalize()
            value = ((value << 1) + ((t + 1) & MASK)) & MASK
        return value


def decompress(stream: bytes, size: int):
    """The decoded bytes and a status named as Adaflight.LZMA names it."""
    out = bytearray(size)
    if len(stream) < 9:
        return bytes(out), "truncated"
    if int.from_bytes(stream[:4], "big") != size:
        return bytes(out), "bad_length"
    d = Decoder(stream)
    if d.next_byte() != 0:
        return bytes(out), "bad_data"
    for _ in range(4):
        d.code = ((d.code << 8) | d.next_byte()) & MASK
    if d.code == d.range:
        return bytes(out), "bad_data"
    m = {name: [1024] * n for name, n in (("is_match", 12), ("is_rep", 12), ("g0", 12), ("g1", 12), ("g2", 12),
                                          ("long", 12), ("slot", 256), ("special", 115), ("align", 16),
                                          ("len_choice", 2), ("len_low", 8), ("len_mid", 8), ("len_high", 256),
                                          ("rep_choice", 2), ("rep_low", 8), ("rep_mid", 8), ("rep_high", 256),
                                          ("literal", 0x300))}

    def length(prefix):
        if d.bit(m[prefix + "_choice"], 0) == 0:
            return d.tree(m[prefix + "_low"], 0, 3)
        if d.bit(m[prefix + "_choice"], 1) == 0:
            return 8 + d.tree(m[prefix + "_mid"], 0, 3)
        return 16 + d.tree(m[prefix + "_high"], 0, 8)

    def distance(n):
        slot = d.tree(m["slot"], min(n, 3) * 64, 6)
        if slot < 4:
            return slot
        if slot < 14:
            return SPECIAL_DISTANCE[slot] + d.reverse_tree(m["special"], SPECIAL_DISTANCE[slot] - slot,
                                                           SPECIAL_BITS[slot])
        direct = d.direct_bits(slot // 2 - 5)
        align = d.reverse_tree(m["align"], 0, 4)
        return (((2 + slot % 2) << (slot // 2 - 1)) + (direct << 4) + align) & MASK

    pos, state = 0, 0
    rep0 = rep1 = rep2 = rep3 = 0
    while pos < size:
        if d.bit(m["is_match"], state) == 0:
            symbol = 1
            if state >= 7:
                if rep0 >= pos:
                    return bytes(out), "bad_data"
                match_byte = out[pos - rep0 - 1]
                while True:
                    match_bit = match_byte >> 7
                    match_byte = (match_byte << 1) & 0xFF
                    b = d.bit(m["literal"], (1 + match_bit) * 256 + symbol)
                    symbol = symbol * 2 + b
                    if match_bit != b or symbol >= 256:
                        break
            while symbol < 256:
                symbol = symbol * 2 + d.bit(m["literal"], symbol)
            out[pos] = symbol - 256
            pos += 1
            state = 0 if state < 4 else state - 3 if state < 10 else state - 6
            continue
        if d.bit(m["is_rep"], state) == 1:
            if pos == 0:
                return bytes(out), "bad_data"
            if d.bit(m["g0"], state) == 0:
                if d.bit(m["long"], state) == 0:
                    if rep0 >= pos:
                        return bytes(out), "bad_data"
                    state = 9 if state < 7 else 11
                    out[pos] = out[pos - rep0 - 1]
                    pos += 1
                    continue
            else:
                if d.bit(m["g1"], state) == 0:
                    swap = rep1
                else:
                    if d.bit(m["g2"], state) == 0:
                        swap = rep2
                    else:
                        swap = rep3
                        rep3 = rep2
                    rep2 = rep1
                rep1 = rep0
                rep0 = swap
            n = length("rep") + 2
            state = 8 if state < 7 else 11
        else:
            rep3, rep2, rep1 = rep2, rep1, rep0
            n = length("len")
            rep0 = distance(n)
            n += 2
            state = 7 if state < 7 else 10
        if rep0 >= pos or n > size - pos:
            return bytes(out), "bad_data"
        for _ in range(n):
            out[pos] = out[pos - rep0 - 1]
            pos += 1
    return bytes(out), "truncated" if d.exhausted else "bad_data" if d.corrupt else "done"


def draw(rng: random.Random, kind: int) -> bytes:
    n = rng.randint(1, 3000)
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
            out[rng.randrange(n)] = rng.randrange(256)
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
    filler = bytes(rng.randrange(256) for _ in range(rng.randint(100, 2000)))
    return head + filler + head + filler[:rng.randint(0, 50)] + head


def chunks(hexs: str) -> str:
    """A hex string as its chunk count and chunks of at most 4000 characters, fields the checker can hold."""
    parts = [hexs[k:k + 4000] for k in range(0, len(hexs), 4000)] or [""]
    return f"{len(parts)}," + ",".join(parts)


def vectors(path: str) -> None:
    rng = random.Random(20261102)
    lines = []
    for case in range(180):
        data = draw(rng, case % 6)
        stream = compress(data)
        back, status = decompress(stream, len(data))
        assert status == "done" and back == data
        assert lzma.decompress(stream[4:], format=lzma.FORMAT_RAW, filters=FILTERS) == data
        lines.append(f"lzma,{case},done,{len(data)},{chunks(stream.hex())},{chunks(data.hex())}")
    case = 180
    for _ in range(120):
        data = draw(rng, rng.randrange(0, 6))
        stream = bytearray(compress(data))
        size = len(data)
        how = rng.randrange(5)
        if how == 0:
            stream = stream[:rng.randrange(0, len(stream))]
        elif how == 1:
            size = max(1, size + rng.choice((-1, 1, 7)))
        elif how == 2:
            stream[4] = rng.randrange(1, 256)
        elif how == 3:
            k = rng.randrange(5, len(stream))
            stream[k] ^= 1 << rng.randrange(8)
        else:
            for _ in range(rng.randint(1, 5)):
                stream[rng.randrange(5, len(stream))] = rng.randrange(256)
        back, status = decompress(bytes(stream), size)
        lines.append(f"lzma,{case},{status},{size},{chunks(bytes(stream).hex())},{chunks(back.hex())}")
        case += 1
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main() -> None:
    if len(sys.argv) == 4 and sys.argv[1] == "compress":
        with open(sys.argv[2], "rb") as f:
            data = f.read()
        with open(sys.argv[3], "wb") as f:
            f.write(compress(data))
    elif len(sys.argv) == 3 and sys.argv[1] == "vectors":
        vectors(sys.argv[2])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
