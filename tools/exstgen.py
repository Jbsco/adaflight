#!/usr/bin/env python3
"""Writes the image of a board whose boot loader runs it from external flash and checks its hash.

usage: exstgen.py <image.bin> <base address> <length in KB> <file>@<address> ...

Each file goes at its address less the base, the rest of the image is zeros, and the last 16 bytes take the MD5
hash of the whole image with those bytes zero. Every file must end before those 16 bytes."""
import hashlib
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) < 5:
        raise SystemExit(__doc__)
    output, base, length = Path(sys.argv[1]), int(sys.argv[2], 0), int(sys.argv[3]) * 1024
    image = bytearray(length)
    for arg in sys.argv[4:]:
        name, _, address = arg.rpartition("@")
        data = Path(name).read_bytes()
        offset = int(address, 0) - base
        if offset < 0 or offset + len(data) > length - 16:
            raise SystemExit(f"exstgen: {name} at {address} does not fit the image before its hash")
        image[offset:offset + len(data)] = data
    image[length - 16:] = hashlib.md5(image).digest()
    output.write_bytes(image)
    print(f"exstgen: {output} {length} bytes, MD5 {image[length - 16:].hex()}")


if __name__ == "__main__":
    main()
