#!/usr/bin/env python3
"""Generate the STM32F7 run-time library of a board from the toolchain's STM32F746 Discovery runtime.

usage: runtimegen.py <configs dir> <board name> <output dir>

The toolchain's light-tasking-stm32f746disco runtime is copied to the output directory with its board
parameters set to the board's crystal (SYSTEM_HSE_MHZ in its config.h, 8 when unset), a system clock of
216 MHz, the flash latency that speed needs and the PLL divisor that gives the USB its 48 MHz, then
built with the runtime's own build script. A copy whose stamp names the same source and parameters is
kept, so a build regenerates nothing. The toolchain is found through arm-eabi-gcc on the path.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from boardgen import find_config  # noqa: E402

# By MCU: the toolchain runtime, the system clock, the flash latency, and the PLL's P and Q divisors.
PARAMETERS = {"STM32F405": ("light-tasking-stm32f4", 168_000_000, 5, 2, 7),
              "STM32F411": ("light-tasking-stm32f4", 96_000_000, 3, 4, 8),
              "STM32F722": ("light-tasking-stm32f746disco", 216_000_000, 7, 2, 9),
              "STM32F745": ("light-tasking-stm32f746disco", 216_000_000, 7, 2, 9),
              "STM32F746": ("light-tasking-stm32f746disco", 216_000_000, 7, 2, 9)}


def toolchain_runtime(source_runtime: str) -> Path:
    gcc = shutil.which("arm-eabi-gcc")
    if not gcc:
        raise SystemExit("runtimegen: arm-eabi-gcc is not on the path; run under alr")
    root = Path(gcc).resolve().parent.parent
    runtime = root / "arm-eabi" / "lib" / "gnat" / source_runtime
    if not (runtime / "gnat" / "s-bbbopa.ads").exists():
        raise SystemExit(f"runtimegen: no {source_runtime} runtime under {root}")
    return runtime


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    configs, board, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    text = find_config(configs, board).read_text()
    m = re.search(r"^#define\s+SYSTEM_HSE_MHZ\s+(\d+)", text, re.M)
    hse_mhz = int(m.group(1)) if m else 8
    m = re.search(r"^#define\s+FC_TARGET_MCU\s+(\w+)", text, re.M)
    mcu = m.group(1) if m else ""
    if mcu not in PARAMETERS:
        raise SystemExit(f"runtimegen: no run-time parameters for the MCU {mcu or 'of ' + board}")
    source_runtime, clock_hz, flash_latency, pllp, pllq = PARAMETERS[mcu]
    source = toolchain_runtime(source_runtime)
    stamp = out / "adaflight-runtime.stamp"
    wanted = f"{source}\n{hse_mhz}\n{clock_hz}\n{flash_latency}\n{pllp}\n{pllq}\n"
    if stamp.exists() and stamp.read_text() == wanted and (out / "adalib" / "libgnat.a").exists():
        return
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(source, out, symlinks=True)
    for sub in ("obj", "adalib"):
        shutil.rmtree(out / sub, ignore_errors=True)
    params = out / "gnat" / "s-bbbopa.ads"
    p = params.read_text()
    for name, value in (("Main_Clock_Frequency", f"{clock_hz:_}"), ("HSE_Clock_Frequency", f"{hse_mhz * 1_000_000:_}"),
                        ("FLASH_Latency", str(flash_latency)), ("PLLP_Value", str(pllp)), ("PLLQ_Value", str(pllq))):
        p, n = re.subn(rf"^(\s*{name}\s*:\s*constant\s*:=\s*)[0-9_]+;", rf"\g<1>{value};", p, flags=re.M)
        if n != 1:
            raise SystemExit(f"runtimegen: {name} not found once in {params}")
    params.write_text(p)
    subprocess.run([sys.executable, "build.py"], cwd=out, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    if not (out / "adalib" / "libgnat.a").exists():
        raise SystemExit("runtimegen: the runtime build left no library")
    stamp.write_text(wanted)


if __name__ == "__main__":
    main()
