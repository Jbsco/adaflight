#!/usr/bin/env python3
"""Pack a packed STM32F7 image's tables and initialized data after the link.

usage: datapack.py <elf>

Runs in the crate directory with the ARM toolchain on the path. The linker placed the packed tables and the
initialized data in RAM with load addresses in the staging region; this reads their bytes, compresses the range
from __packed_start to __packed_end with tools/lzss.py, checks the stream decodes back, checks that it fits between
__rom_end and the end of the flash region, and writes the flash files beside the image: sector0.bin with the vector
table and the code of sector 0, and code.bin with the code from sector 2 followed by the stream at __rom_end.
"""
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import lzss  # noqa: E402


def run(*args) -> str:
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def sections(elf: Path) -> dict:
    out = {}
    for line in run("arm-eabi-objdump", "-h", str(elf)).splitlines():
        p = line.split()
        if len(p) >= 6 and p[0].isdigit():
            out[p[1]] = (int(p[2], 16), int(p[3], 16), int(p[4], 16))
    return out


def symbols(elf: Path) -> dict:
    out = {}
    for line in run("arm-eabi-nm", str(elf)).splitlines():
        p = line.split()
        if len(p) == 3:
            out[p[2]] = int(p[0], 16)
    return out


def section_bytes(elf: Path, name: str, scratch: Path) -> bytes:
    run("arm-eabi-objcopy", "-O", "binary", f"--only-section={name}", str(elf), str(scratch))
    return scratch.read_bytes()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    elf = Path(sys.argv[1])
    secs, syms = sections(elf), symbols(elf)
    if ".packed_tables" not in secs:
        raise SystemExit("datapack: the image has no packed tables section; it is a plain build")
    if secs.get(".ccmdata", (0, 0, 0))[0]:
        raise SystemExit("datapack: a packed image cannot hold .ccmdata, which the run-time library copies")
    start, end = syms["__packed_start"], syms["__packed_end"]
    raw = bytearray(end - start)
    scratch = elf.parent / "datapack.tmp"
    for name in (".packed_tables", ".data"):
        size, vma, _ = secs[name]
        raw[vma - start:vma - start + size] = section_bytes(elf, name, scratch)
    stream = lzss.compress(bytes(raw))
    back, status = lzss.decompress(stream, len(raw))
    if status != "done" or back != bytes(raw):
        raise SystemExit("datapack: the stream does not decode back to the packed range")
    rom_end, flash_end = syms["__rom_end"], syms["__flash_end"]
    room = flash_end - rom_end
    print(f"datapack: tables {secs['.packed_tables'][0]} and data {secs['.data'][0]} bytes, "
          f"range {len(raw)} -> stream {len(stream)} bytes; {room - len(stream)} bytes of flash left")
    if len(stream) > room:
        raise SystemExit(f"datapack: the stream overflows the flash region by {len(stream) - room} bytes")
    run("arm-eabi-objcopy", "-O", "binary", "--only-section=.vectors", "--only-section=.text0", str(elf),
        str(elf.parent / "sector0.bin"))
    remove = [f"--remove-section={n}" for n in (".vectors", ".text0", ".packed_tables", ".data", ".ccmdata")]
    run("arm-eabi-objcopy", "-O", "binary", *remove, str(elf), str(scratch))
    code = scratch.read_bytes()
    code_start = min(lma for name, (size, _, lma) in secs.items()
                     if size and name not in (".vectors", ".text0", ".packed_tables", ".data", ".ccmdata")
                     and 0x08000000 <= lma < 0x08200000)
    if code_start + len(code) != rom_end:
        raise SystemExit(f"datapack: the code ends at {code_start + len(code):#x}, not at __rom_end {rom_end:#x}")
    (elf.parent / "code.bin").write_bytes(code + stream)
    scratch.unlink()
    print(f"datapack: wrote sector0.bin and code.bin ({len(code) + len(stream)} bytes from {code_start:#010x})")


if __name__ == "__main__":
    main()
