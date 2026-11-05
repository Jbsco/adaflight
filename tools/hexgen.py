#!/usr/bin/env python3
"""Writes an Intel HEX image of flash files at their addresses, then reads it back and compares.

usage: hexgen.py <image.hex> [--end=<address>] <file>@<address> ...

Each file becomes one run of 16-byte data records, with an extended linear address record wherever the upper
16 address bits change, so a flasher sees one block per file and leaves the flash between them as it is. With
--end, every file must end below that address."""
import sys


def record(address, kind, data):
    body = bytes([len(data), (address >> 8) & 0xFF, address & 0xFF, kind]) + data
    return ":" + (body + bytes([-sum(body) & 0xFF])).hex().upper()


def encode(blocks):
    lines, upper = [], None
    for start, data in blocks:
        offset = 0
        while offset < len(data):
            address = start + offset
            if address >> 16 != upper:
                upper = address >> 16
                lines.append(record(0, 4, upper.to_bytes(2, "big")))
            size = min(16, len(data) - offset, 0x10000 - (address & 0xFFFF))
            lines.append(record(address & 0xFFFF, 0, data[offset:offset + size]))
            offset += size
    lines.append(record(0, 1, b""))
    return "\n".join(lines) + "\n"


def decode(text):
    blocks, upper, done = [], 0, False
    for n, line in enumerate(text.splitlines(), 1):
        if done or not line.startswith(":"):
            raise SystemExit(f"hexgen: line {n} is not a record")
        raw = bytes.fromhex(line[1:])
        if len(raw) != raw[0] + 5 or sum(raw) & 0xFF:
            raise SystemExit(f"hexgen: line {n} has a bad length or checksum")
        kind, data = raw[3], raw[4:-1]
        if kind == 4:
            upper = int.from_bytes(data, "big")
        elif kind == 0:
            address = (upper << 16) | (raw[1] << 8) | raw[2]
            if blocks and blocks[-1][0] + len(blocks[-1][1]) == address:
                blocks[-1][1].extend(data)
            else:
                blocks.append((address, bytearray(data)))
        elif kind == 1:
            done = True
        else:
            raise SystemExit(f"hexgen: line {n} has record type {kind}")
    if not done:
        raise SystemExit("hexgen: no end of file record")
    return [(a, bytes(d)) for a, d in blocks]


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    blocks, end = [], None
    for arg in sys.argv[2:]:
        if arg.startswith("--end="):
            end = int(arg[6:], 0)
            continue
        name, _, where = arg.rpartition("@")
        data = open(name, "rb").read()
        if not data:
            raise SystemExit(f"hexgen: {name} is empty")
        blocks.append((int(where, 0), data))
    blocks.sort()
    for a, d in blocks:
        if end is not None and a + len(d) > end:
            raise SystemExit(f"hexgen: the file at {a:#010x} runs {a + len(d) - end} bytes past {end:#010x}")
    for (a, d), (b, _) in zip(blocks, blocks[1:]):
        if a + len(d) > b:
            raise SystemExit(f"hexgen: the file at {a:#010x} runs into the one at {b:#010x}")
    text = encode(blocks)
    merged = []
    for a, d in blocks:
        if merged and merged[-1][0] + len(merged[-1][1]) == a:
            merged[-1] = (merged[-1][0], merged[-1][1] + d)
        else:
            merged.append((a, d))
    if decode(text) != merged:
        raise SystemExit("hexgen: the image does not read back as its files")
    open(sys.argv[1], "w").write(text)
    print(f"hexgen: wrote {sys.argv[1]} with " + " and ".join(f"{len(d)} bytes at {a:#010x}" for a, d in blocks))


if __name__ == "__main__":
    main()
