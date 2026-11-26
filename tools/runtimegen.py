#!/usr/bin/env python3
"""Generate a board's run-time library from a toolchain runtime.

usage: runtimegen.py <configs dir> <board name> <output dir>

An STM32F4 board's runtime is the toolchain's light-tasking-stm32f4 and an STM32F7 board's its
light-tasking-stm32f746disco, copied to the output directory with the board parameters set to the board's crystal
(SYSTEM_HSE_MHZ in its config.h, 8 when unset), the MCU's system clock, the flash latency that speed needs and the
PLL divisors that give the USB its 48 MHz, then built with the runtime's own build script. An STM32H743 board's
runtime starts from the same F7 copy. targets/stm32h7/runtime-src replaces its clock setup and MCU parameters, the
H743's interrupt names and vector table are written from INTERRUPTS_H743, and the start-up leaves the caches to
the image, since the F7 copy finds the MCU by a register the H7 has elsewhere. A copy whose stamp names the same
source, parameters and replacements is kept, so a build regenerates nothing. The toolchain is found through
arm-eabi-gcc on the path.
"""
import hashlib
import re
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from boardgen import find_config  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
H7_SOURCES = ROOT / "targets" / "stm32h7" / "runtime-src"

# By MCU: the toolchain runtime, the system clock, the flash latency, and the PLL's P and Q divisors.
PARAMETERS = {"STM32F405": ("light-tasking-stm32f4", 168_000_000, 5, 2, 7),
              "STM32F411": ("light-tasking-stm32f4", 96_000_000, 3, 4, 8),
              "STM32F446": ("light-tasking-stm32f4", 168_000_000, 5, 2, 7),
              "STM32F722": ("light-tasking-stm32f746disco", 216_000_000, 7, 2, 9),
              "STM32F745": ("light-tasking-stm32f746disco", 216_000_000, 7, 2, 9),
              "STM32F746": ("light-tasking-stm32f746disco", 216_000_000, 7, 2, 9),
              "STM32H743": ("light-tasking-stm32f746disco", 400_000_000, 2, 2, 8)}

# The STM32H743's interrupts, number and name, as RM0433 numbers them; numbers not listed are reserved.
INTERRUPTS_H743 = """
    0 WWDG 1 PVD_AVD 2 TAMP_STAMP 3 RTC_WKUP 4 FLASH 5 RCC 6 EXTI0 7 EXTI1 8 EXTI2 9 EXTI3 10 EXTI4 11
    DMA1_Stream0 12 DMA1_Stream1 13 DMA1_Stream2 14 DMA1_Stream3 15 DMA1_Stream4 16 DMA1_Stream5 17
    DMA1_Stream6 18 ADC 19 FDCAN1_IT0 20 FDCAN2_IT0 21 FDCAN1_IT1 22 FDCAN2_IT1 23 EXTI9_5 24 TIM1_BRK 25
    TIM1_UP 26 TIM1_TRG_COM 27 TIM1_CC 28 TIM2 29 TIM3 30 TIM4 31 I2C1_EV 32 I2C1_ER 33 I2C2_EV 34 I2C2_ER 35
    SPI1 36 SPI2 37 USART1 38 USART2 39 USART3 40 EXTI15_10 41 RTC_Alarm 43 TIM8_BRK_TIM12 44 TIM8_UP_TIM13 45
    TIM8_TRG_COM_TIM14 46 TIM8_CC 47 DMA1_Stream7 48 FMC 49 SDMMC1 50 TIM5 51 SPI3 52 UART4 53 UART5 54
    TIM6_DAC 55 TIM7 56 DMA2_Stream0 57 DMA2_Stream1 58 DMA2_Stream2 59 DMA2_Stream3 60 DMA2_Stream4 61 ETH 62
    ETH_WKUP 63 FDCAN_CAL 68 DMA2_Stream5 69 DMA2_Stream6 70 DMA2_Stream7 71 USART6 72 I2C3_EV 73 I2C3_ER 74
    OTG_HS_EP1_OUT 75 OTG_HS_EP1_IN 76 OTG_HS_WKUP 77 OTG_HS 78 DCMI 80 RNG 81 FPU 82 UART7 83 UART8 84 SPI4 85
    SPI5 86 SPI6 87 SAI1 88 LTDC 89 LTDC_ER 90 DMA2D 91 SAI2 92 QUADSPI 93 LPTIM1 94 CEC 95 I2C4_EV 96 I2C4_ER
    97 SPDIF_RX 98 OTG_FS_EP1_OUT 99 OTG_FS_EP1_IN 100 OTG_FS_WKUP 101 OTG_FS 102 DMAMUX1_OVR 103 HRTIM1_Master
    104 HRTIM1_TIMA 105 HRTIM1_TIMB 106 HRTIM1_TIMC 107 HRTIM1_TIMD 108 HRTIM1_TIME 109 HRTIM1_FLT 110
    DFSDM1_FLT0 111 DFSDM1_FLT1 112 DFSDM1_FLT2 113 DFSDM1_FLT3 114 SAI3 115 SWPMI1 116 TIM15 117 TIM16 118
    TIM17 119 MDIOS_WKUP 120 MDIOS 121 JPEG 122 MDMA 124 SDMMC2 125 HSEM1 127 ADC3 128 DMAMUX2_OVR 129
    BDMA_Channel0 130 BDMA_Channel1 131 BDMA_Channel2 132 BDMA_Channel3 133 BDMA_Channel4 134 BDMA_Channel5 135
    BDMA_Channel6 136 BDMA_Channel7 137 COMP 138 LPTIM2 139 LPTIM3 140 LPTIM4 141 LPTIM5 142 LPUART1 144 CRS
    145 ECC 146 SAI4 149 WAKEUP_PIN
"""
H7_INTERRUPT_COUNT = 150


def toolchain_runtime(source_runtime: str) -> Path:
    gcc = shutil.which("arm-eabi-gcc")
    if not gcc:
        raise SystemExit("runtimegen: arm-eabi-gcc is not on the path; run under alr")
    root = Path(gcc).resolve().parent.parent
    runtime = root / "arm-eabi" / "lib" / "gnat" / source_runtime
    if not (runtime / "gnat" / "s-bbbopa.ads").exists():
        raise SystemExit(f"runtimegen: no {source_runtime} runtime under {root}")
    return runtime


def h7_pll(hse_hz: int, clock_hz: int, pllp: int) -> tuple:
    """PLL1's input divider, multiplier and input range for a VCO of clock_hz times pllp from the crystal."""
    vco = clock_hz * pllp
    for divm in range(63, 0, -1):
        ref = hse_hz / divm
        if hse_hz % divm == 0 and ref >= 2_000_000 and vco % (hse_hz // divm) == 0:
            return divm, vco // (hse_hz // divm), 1 if ref < 4_000_000 else 2 if ref < 8_000_000 else 3
    raise SystemExit(f"runtimegen: no PLL1 divider gives {vco} Hz from a {hse_hz} Hz crystal")


def h7_vectors(f7_handler: str) -> str:
    """The F7 copy's vector table with the H743's interrupts in place of the F7's."""
    names = dict(zip(map(int, INTERRUPTS_H743.split()[0::2]), INTERRUPTS_H743.split()[1::2]))
    lines = f7_handler.splitlines()
    start = lines.index("\t/* Cortex-M core interrupts */")
    last = max(i for i, line in enumerate(lines) if "__gnat_irq_trap" in line and "/*" in line)
    table = [f"\t.word __gnat_irq_trap        /* {16 + n} {names.get(n, 'reserved')} */"
             for n in range(H7_INTERRUPT_COUNT)]
    head = ["/* The STM32H743's vector table, generated by tools/runtimegen.py. */", "", "\t.syntax unified",
            "\t.cpu cortex-m4", "\t.thumb", "", "\t.text", "\t.globl __vectors", "\t.p2align 10", "__vectors:"]
    return "\n".join(head + lines[start:start + 17] + ["\t/* MCU interrupts */"] + table + [""]
                     + lines[lines.index("\t.text", last):]) + "\n"


def h7_names() -> str:
    """Ada.Interrupts.Names for the H743."""
    pairs = list(zip(map(int, INTERRUPTS_H743.split()[0::2]), INTERRUPTS_H743.split()[1::2]))
    width = max(len(name) for _, name in pairs) + len("_Interrupt")
    body = [f"   {(name + '_Interrupt').ljust(width)} : constant Interrupt_ID := {n};" for n, name in pairs]
    return "\n".join(["--  The STM32H743's interrupts by name, generated by tools/runtimegen.py.", "",
                      "package Ada.Interrupts.Names is", "", "   pragma Implementation_Defined;", "",
                      f"   {'Sys_Tick_Interrupt'.ljust(width)} : constant Interrupt_ID := -1;"] + body
                     + ["", "end Ada.Interrupts.Names;", ""])


def h7_runtime(out: Path, hse_hz: int, clock_hz: int, flash_latency: int, pllp: int, pllq: int) -> None:
    """Turns the F7 copy in out into the STM32H743's runtime."""
    divm, divn, pll_range = h7_pll(hse_hz, clock_hz, pllp)
    (out / "gnat" / "s-bbbopa.ads").write_text(f"""--  The STM32H743 board parameters, generated by tools/runtimegen.py.

package System.BB.Board_Parameters is
   pragma No_Elaboration_Code_All;
   pragma Pure;

   Main_Clock_Frequency : constant := {clock_hz:_};
   HSE_Clock_Frequency  : constant := {hse_hz:_};
   FLASH_Latency        : constant := {flash_latency};
   Flash_Write_Delay    : constant := 2;
   PLLP_Value           : constant := {pllp};
   PLLQ_Value           : constant := {pllq};
   PLL1_M               : constant := {divm};
   PLL1_N               : constant := {divn};
   PLL1_R               : constant := 5;
   PLL1_Range           : constant := {pll_range};

end System.BB.Board_Parameters;
""")
    for source in sorted(H7_SOURCES.rglob("*.ad?")):
        shutil.copyfile(source, out / source.relative_to(H7_SOURCES))
    (out / "gnat" / "s-bbmcpa.adb").unlink()
    handler = out / "gnarl" / "handler.S"
    handler.write_text(h7_vectors(handler.read_text()))
    (out / "gnarl" / "a-intnam.ads").write_text(h7_names())
    stm32 = out / "gnat" / "s-stm32.ads"
    text = stm32.read_text()
    sysclk = "subtype SYSCLK_Range is Integer range           1 .. 216_000_000;"
    if text.count(sysclk) != 1:
        raise SystemExit(f"runtimegen: the system clock range not found once in {stm32}")
    stm32.write_text(text.replace(sysclk, sysclk.replace("216_000_000", "480_000_000")))
    start = out / "gnat" / "start-common.S"
    text = start.read_text()
    check = "        ldr     r0, =MCU_ID_REG\n"
    if text.count(check) != 1:
        raise SystemExit(f"runtimegen: the MCU check not found once in {start}")
    start.write_text(text.replace(check, "        b       end\n" + check))


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
    wanted = f"{source}\n{mcu}\n{hse_mhz}\n{clock_hz}\n{flash_latency}\n{pllp}\n{pllq}\n"
    if mcu.startswith("STM32H7"):
        digest = hashlib.sha256(Path(__file__).read_bytes())
        for source_file in sorted(H7_SOURCES.rglob("*.ad?")):
            digest.update(source_file.read_bytes())
        wanted += digest.hexdigest() + "\n"
    if stamp.exists() and stamp.read_text() == wanted and (out / "adalib" / "libgnat.a").exists():
        return
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(source, out, symlinks=True)
    for sub in ("obj", "adalib"):
        shutil.rmtree(out / sub, ignore_errors=True)
    if mcu.startswith("STM32H7"):
        h7_runtime(out, hse_mhz * 1_000_000, clock_hz, flash_latency, pllp, pllq)
    else:
        params = out / "gnat" / "s-bbbopa.ads"
        p = params.read_text()
        for name, value in (("Main_Clock_Frequency", f"{clock_hz:_}"),
                            ("HSE_Clock_Frequency", f"{hse_mhz * 1_000_000:_}"), ("FLASH_Latency", str(flash_latency)),
                            ("PLLP_Value", str(pllp)), ("PLLQ_Value", str(pllq))):
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
