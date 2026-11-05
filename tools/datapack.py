#!/usr/bin/env python3
"""Pack a packed image's initialized data and elaboration code, with an STM32F7's tables, after the link.

usage: datapack.py <elf>

Runs in the crate directory with the ARM toolchain on the path. The linker placed the packed tables, which an
STM32F4 image keeps in flash, the initialized data and the elaboration's code in RAM with load addresses in the
staging region; this checks that
nothing but main's call of adainit reaches the elaboration's code, whose RAM the main stack takes back, reads
their bytes, compresses the range from __packed_start to __packed_end as an LZMA stream (tools/lzma_ref.py),
checks the stream decodes back,
checks that it fits between __rom_end and the end of the flash region, and writes the flash files beside the
image: sector0.bin with the vector table and the code of sector 0, and code.bin with the code from sector 2
followed by the stream at __rom_end.
"""
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import lzma_ref  # noqa: E402


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


# The code that runs before the packed range exists: the unpacking, its decoder and the cache start-up.
EARLY_CODE = ("adaflight_data_pack_unpack", "adaflight__lzma__", "adaflight__stm32__cache__")


def early_references(elf: Path, start: int, end: int, boot: int) -> list:
    """The addresses past start and before end that the code running before the unpacking loads, from its literal
    pools and its movw and movt pairs; start itself is the unpacking's target and boot the code it syncs."""
    found = []
    functions = sorted({p[2] for p in (line.split() for line in run("arm-eabi-nm", str(elf)).splitlines())
                        if len(p) == 3 and p[1] in "Tt" and p[2].startswith(EARLY_CODE)})
    for name in functions:
        low = {}
        for line in run("arm-eabi-objdump", "-d", f"--disassemble={name}", str(elf)).splitlines():
            m = re.search(r"\.word\s+0x([0-9a-f]{8})", line)
            if m and start < int(m.group(1), 16) < end and int(m.group(1), 16) != boot:
                found.append((name, int(m.group(1), 16)))
            m = re.search(r"\bmovw\s+(r\d+), #(\d+)", line)
            if m:
                low[m.group(1)] = int(m.group(2))
            m = re.search(r"\bmovt\s+(r\d+), #(\d+)", line)
            if m and m.group(1) in low:
                value = (int(m.group(2)) << 16) | low[m.group(1)]
                if start < value < end and value != boot:
                    found.append((name, value))
    return found


# The linker's long branch from main in flash to adainit in RAM.
BOOT_VENEER = "__adainit_veneer"

# The sections whose words may hold addresses of code.
POINTER_SECTIONS = (".rodata", ".rodata_unpack", ".init_array", ".preinit_array", ".fini_array", ".data",
                    ".packed_tables")


def boot_references(elf: Path, secs: dict, start: int, end: int, scratch: Path) -> list:
    """The places that take the address of a function from start to end, an odd address in the Thumb state, or
    branch into that range from outside it, other than the veneer of main's call: literal pools, movw and movt pairs
    and branches in the code, and words in the data."""
    def thumb(value: int) -> bool:
        return value & 1 == 1 and start <= value < end

    found = []
    name, low = "", {}
    for line in run("arm-eabi-objdump", "-d", str(elf)).splitlines():
        m = re.match(r"([0-9a-f]{8}) <(.+)>:$", line)
        if m:
            name, low = m.group(2), {}
            continue
        if name == BOOT_VENEER:
            continue
        m = re.search(r"\.word\s+0x([0-9a-f]{8})", line)
        if m and thumb(int(m.group(1), 16)):
            found.append((name, int(m.group(1), 16)))
        m = re.search(r"\bmovw\s+(r\d+), #(\d+)", line)
        if m:
            low[m.group(1)] = int(m.group(2))
        m = re.search(r"\bmovt\s+(r\d+), #(\d+)", line)
        if m and m.group(1) in low:
            value = (int(m.group(2)) << 16) | low[m.group(1)]
            if thumb(value):
                found.append((name, value))
        m = re.match(r"\s*([0-9a-f]+):.*\t(?:b[a-z.]*|cbn?z)\t(?:r\d+, )?([0-9a-f]+) <", line)
        if m and not start <= int(m.group(1), 16) < end and start <= int(m.group(2), 16) < end:
            found.append((name, int(m.group(2), 16)))
    for section in POINTER_SECTIONS:
        if secs.get(section, (0, 0, 0))[0]:
            data = section_bytes(elf, section, scratch)
            for k in range(0, len(data) - 3, 4):
                value = int.from_bytes(data[k:k + 4], "little")
                if thumb(value):
                    found.append((section, value))
    return found


def section_bytes(elf: Path, name: str, scratch: Path) -> bytes:
    run("arm-eabi-objcopy", "-O", "binary", f"--only-section={name}", str(elf), str(scratch))
    return scratch.read_bytes()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    elf = Path(sys.argv[1])
    secs, syms = sections(elf), symbols(elf)
    if ".boot_code" not in secs:
        raise SystemExit("datapack: the image has no boot code section; it is a plain build")
    secs.setdefault(".packed_tables", (0, syms["__packed_start"], 0))
    if secs.get(".ccmdata", (0, 0, 0))[0]:
        raise SystemExit("datapack: a packed image cannot hold .ccmdata, which the run-time library copies")
    start, end = syms["__packed_start"], syms["__packed_end"]
    early = early_references(elf, start, end, syms["__boot_start"])
    if early:
        raise SystemExit("datapack: code that runs before the unpacking reads packed data: "
                         + ", ".join(f"{name} {address:#010x}" for name, address in early))
    scratch = elf.parent / "datapack.tmp"
    boot = boot_references(elf, secs, syms["__boot_start"], syms["__boot_end"], scratch)
    if boot:
        raise SystemExit("datapack: the elaboration's code is reached from outside main's call of adainit: "
                         + ", ".join(f"{name} {address:#010x}" for name, address in boot))
    raw = bytearray(end - start)
    for name in (".packed_tables", ".data", ".boot_code"):
        size, vma, _ = secs[name]
        if size:
            raw[vma - start:vma - start + size] = section_bytes(elf, name, scratch)
    stream = lzma_ref.compress(bytes(raw))
    back, status = lzma_ref.decompress(stream, len(raw))
    if status != "done" or back != bytes(raw):
        raise SystemExit("datapack: the stream does not decode back to the packed range")
    rom_end, flash_end = syms["__rom_end"], syms["__flash_end"]
    room = flash_end - rom_end
    print(f"datapack: tables {secs['.packed_tables'][0]}, data {secs['.data'][0]} and boot code "
          f"{secs['.boot_code'][0]} bytes, "
          f"range {len(raw)} -> stream {len(stream)} bytes; {room - len(stream)} bytes of flash left")
    if len(stream) > room:
        raise SystemExit(f"datapack: the stream overflows the flash region by {len(stream) - room} bytes")
    run("arm-eabi-objcopy", "-O", "binary", "--only-section=.vectors", "--only-section=.text0", str(elf),
        str(elf.parent / "sector0.bin"))
    remove = [f"--remove-section={n}" for n in (".vectors", ".text0", ".packed_tables", ".data", ".ccmdata",
                                                 ".boot_code")]
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
