#!/usr/bin/env python3
"""Generate the memory layout of a board's image from its MCU.

usage: memorygen.py <configs dir> <board name> <output .ld>

The layout keeps flash sector 0 as its own region for the vector table and the code beside it, sector 1 for the
configuration store, and the rest of the code from sector 2. That code region is declared longer than its flash
by a measuring allowance, so an image past its flash still links and its build names its size; __flash_size is
the flash the code has, and target.do checks an image against it. The main RAM and the core coupled memory follow the
MCU, and an STM32F7 or STM32H7 adds its instruction tightly coupled memory. An STM32H7 also adds its D2 RAM for
DMA buffers, since its DMA does not reach the data tightly coupled memory. The crate's linker script
includes the output, and the Ada package adaflight-stm32-memory.ads beside it gives the code the configuration
sector, the bootloader and the unique identifier's addresses.
"""
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from boardgen import find_config  # noqa: E402

# Sector 0 and 1 sizes, the code's start and size, the main RAM and the core coupled memory (none on an
# STM32F411 or STM32F446, whose sections alias the main RAM), then the system memory bootloader's, the unique
# identifier's and the ADC calibration words' addresses.
LAYOUTS = {
    "STM32F405": ("16K", "0x08004000", "16K", "0x08008000", "992K", "0x20000000", "128K", "0x10000000", "64K",
                  "16#1FFF_0000#", "16#1FFF_7A10#", "16#1FFF_7A2A#"),
    "STM32F411": ("16K", "0x08004000", "16K", "0x08008000", "480K", "0x20000000", "128K", "0x20000000", "0K",
                  "16#1FFF_0000#", "16#1FFF_7A10#", "16#1FFF_7A2A#"),
    "STM32F446": ("16K", "0x08004000", "16K", "0x08008000", "480K", "0x20000000", "128K", "0x20000000", "0K",
                  "16#1FFF_0000#", "16#1FFF_7A10#", "16#1FFF_7A2A#"),
    "STM32F722": ("16K", "0x08004000", "16K", "0x08008000", "480K", "0x20010000", "192K", "0x20000000", "64K",
                  "16#1FF0_0000#", "16#1FF0_7A10#", "16#1FF0_7A2A#"),
    "STM32F745": ("32K", "0x08008000", "32K", "0x08010000", "960K", "0x20010000", "256K", "0x20000000", "64K",
                  "16#1FF0_0000#", "16#1FF0_F420#", "16#1FF0_F44A#"),
    "STM32F746": ("32K", "0x08008000", "32K", "0x08010000", "960K", "0x20010000", "256K", "0x20000000", "64K",
                  "16#1FF0_0000#", "16#1FF0_F420#", "16#1FF0_F44A#"),
    "STM32H743": ("128K", "0x08020000", "128K", "0x08040000", "1792K", "0x24000000", "512K", "0x20000000", "128K",
                  "16#1FF0_9800#", "16#1FF1_E800#", "16#1FF1_E860#"),
}


# The core clock and the two peripheral bus clocks, as the run-time library sets them (tools/runtimegen.py).
CLOCKS = {"STM32F405": (168_000_000, 42_000_000, 84_000_000), "STM32F411": (96_000_000, 24_000_000, 48_000_000),
          "STM32F446": (168_000_000, 42_000_000, 84_000_000),
          "STM32F722": (216_000_000, 54_000_000, 108_000_000), "STM32F745": (216_000_000, 54_000_000, 108_000_000),
          "STM32F746": (216_000_000, 54_000_000, 108_000_000), "STM32H743": (400_000_000, 100_000_000, 100_000_000)}


# Peripheral addresses and clock enables that move between MCU families, for adaflight-stm32-memory.ads: the reset and
# clock control registers the drivers write (peripheral bus resets and enables, the GPIO ports' clock enables, and
# the registers and bits that enable the DMA controllers, the USB OTG FS core and SYSCFG), peripheral bases, then the
# EXTI registers' offsets. DMAMUX1_Base is 0 on families that select a stream's request in its control register.
MAP_F4_F7 = (("RCC_APB1_Reset", 0x4002_3820), ("RCC_APB2_Reset", 0x4002_3824), ("RCC_APB1_Enable", 0x4002_3840),
             ("RCC_APB2_Enable", 0x4002_3844), ("RCC_GPIO_Enable", 0x4002_3830), ("RCC_DMA_Enable", 0x4002_3830),
             ("DMA1_Enable_Bit", 21), ("RCC_USB_Enable", 0x4002_3834), ("USB_Enable_Bit", 7),
             ("RCC_SYSCFG_Enable", 0x4002_3844), ("SYSCFG_Enable_Bit", 14),
             ("GPIO_Base", 0x4002_0000), ("EXTI_Base", 0x4001_3C00), ("SYSCFG_Base", 0x4001_3800),
             ("DMA1_Base", 0x4002_6000), ("DMA2_Base", 0x4002_6400), ("DMAMUX1_Base", 0), ("OTG_FS_Base", 0x5000_0000),
             ("EXTI_IMR", 0x00), ("EXTI_EMR", 0x04), ("EXTI_RTSR", 0x08), ("EXTI_FTSR", 0x0C), ("EXTI_SWIER", 0x10),
             ("EXTI_PR", 0x14))
MAP_H7 = (("RCC_APB1_Reset", 0x5802_4490), ("RCC_APB2_Reset", 0x5802_4498), ("RCC_APB1_Enable", 0x5802_44E8),
          ("RCC_APB2_Enable", 0x5802_44F0), ("RCC_GPIO_Enable", 0x5802_44E0), ("RCC_DMA_Enable", 0x5802_44D8),
          ("DMA1_Enable_Bit", 0), ("RCC_USB_Enable", 0x5802_44D8), ("USB_Enable_Bit", 27),
          ("RCC_SYSCFG_Enable", 0x5802_44F4), ("SYSCFG_Enable_Bit", 1),
          ("GPIO_Base", 0x5802_0000), ("EXTI_Base", 0x5800_0000), ("SYSCFG_Base", 0x5800_0400),
          ("DMA1_Base", 0x4002_0000), ("DMA2_Base", 0x4002_0400), ("DMAMUX1_Base", 0x4002_0800),
          ("OTG_FS_Base", 0x4008_0000),
          ("EXTI_IMR", 0x80), ("EXTI_EMR", 0x84), ("EXTI_RTSR", 0x00), ("EXTI_FTSR", 0x04), ("EXTI_SWIER", 0x08),
          ("EXTI_PR", 0x88))


def ada_number(value: int) -> str:
    if value < 0x1_0000:
        return str(value)
    digits = f"{value:08X}"
    return f"16#{digits[:4]}_{digits[4:]}#"


# The length a code region is declared with past its flash, so an image past its flash links and is measured.
ALLOWANCE = "512K"


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    configs, board, output = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    text = find_config(configs, board).read_text()
    m = re.search(r"^#define\s+FC_TARGET_MCU\s+(\w+)", text, re.M)
    mcu = m.group(1) if m else ""
    if mcu not in LAYOUTS:
        raise SystemExit(f"memorygen: no memory layout for the MCU {mcu or 'of ' + board}")
    s0, cfg, s1, code, code_len, ram, ram_len, ccm, ccm_len, boot, uid, cal = LAYOUTS[mcu]
    itcm = ("  itcm   (rwx) : ORIGIN = 0x00000000, LENGTH = 16K\n" if mcu.startswith("STM32F7")
            else "  itcm   (rwx) : ORIGIN = 0x00000000, LENGTH = 64K\n"
            "  d2      (rw) : ORIGIN = 0x30000000, LENGTH = 256K\n" if mcu.startswith("STM32H7") else "")
    ccm_line = f"  ccm     (rw) : ORIGIN = {ccm}, LENGTH = {ccm_len}\n" if ccm_len != "0K" else ""
    aliases = ('REGION_ALIAS("ccm", sram12)\nREGION_ALIAS("ccm_da", sram12)\n' if ccm_len == "0K"
               else 'REGION_ALIAS("ccm_da", ccm)\n')
    stack = "32K" if mcu in ("STM32F411", "STM32F446") else "40K"
    core_hz, apb1_hz, apb2_hz = CLOCKS[mcu]
    out = f"""/* The memory layout of the {mcu}, generated by tools/memorygen.py for {board}. Do not edit. */
MEMORY
{{
  flash0  (rx) : ORIGIN = 0x08000000, LENGTH = {s0}
  config   (r) : ORIGIN = {cfg}, LENGTH = {s1}
  flash   (rx) : ORIGIN = {code}, LENGTH = {code_len} + {ALLOWANCE}
  staging  (r) : ORIGIN = 0xC0000000, LENGTH = 1M
  sram12 (rwx) : ORIGIN = {ram}, LENGTH = {ram_len}
{ccm_line}{itcm}}}
{aliases}__stack_size = {stack};
__flash_size = {code_len};
"""
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists() or output.read_text() != out:
        output.write_text(out)
    entries = MAP_H7 if mcu.startswith("STM32H7") else MAP_F4_F7
    width = max(len(name) for name, _ in entries)
    peripherals = "\n".join(f"   {name.ljust(width)} : constant := {ada_number(value)};" for name, value in entries)
    ada = output.parent / "adaflight-stm32-memory.ads"
    text_ada = f"""--  The {mcu}'s memory as the code reads it, generated by tools/memorygen.py for {board}.
--  Do not edit.
package Adaflight.STM32.Memory is
   --  The configuration store at the start of flash sector 1, which the
   --  image's layout keeps free.
   Config_Sector      : constant := 1;
   Config_Address     : constant := 16#{int(cfg, 16):08X}#;
   Config_Size        : constant := 8_192;
   --  The system memory bootloader's vector table and the unique identifier.
   Bootloader_Address : constant := {boot};
   UID_Address        : constant := {uid};
   --  The ADC's reference and temperature calibration words.
   Calibration_Address : constant := {cal};
   --  The identifier stored with the configuration.
   Board_Identifier    : constant String := "{mcu[5:]}";
   --  Peripheral addresses and clock enables that differ between MCU families.
{peripherals}
end Adaflight.STM32.Memory;
"""
    if not ada.exists() or ada.read_text() != text_ada:
        ada.write_text(text_ada)
    clocks = output.parent / "adaflight-stm32-clocks.ads"
    text_clocks = f"""--  The {mcu}'s clocks as the board crate's drivers read them, generated by tools/memorygen.py
--  for {board}. Do not edit.
package Adaflight.STM32.Clocks is
   Core_Hz : constant := {core_hz:_};
   APB1_Hz : constant := {apb1_hz:_};
   APB2_Hz : constant := {apb2_hz:_};
end Adaflight.STM32.Clocks;
"""
    if not clocks.exists() or clocks.read_text() != text_clocks:
        clocks.write_text(text_clocks)


if __name__ == "__main__":
    main()
