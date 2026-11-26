#!/usr/bin/env python3
"""Generate the Ada package of the features one build contains.

usage: featuregen.py <configs dir> <board name> <output .ads> [features]
       featuregen.py --feature <name> <configs dir> <board name> [features]
       featuregen.py --json <configs dir> <board name> [features]

The board's MCU, from its config.h in the board configuration repository, sets the flash size, and
FLASH_KB in the environment sets it instead. Each feature is on when the flash is at least the size
its entry names or when the board's configuration names its define (the compass and the barometer), and a
feature with no size is off unless named. The features argument then adds or
removes features by name, case ignored, each
name with + or - in front (+ when there is none), separated by spaces or commas. Beside the package
goes adaflight-checks.adc, the configuration pragmas of the board crate, which turn its run-time
checks off when Board_Checks is off, itcm_load.ld, which names where an STM32F7 image loads its ITCM code from,
and the linker scripts' RAM sections, where an STM32F4 build packs its
initialized data and elaboration code only and keeps its tables in flash. A feature
with a negative size is on below that size instead. Debug values are off in a build of 512 KB or less, for the
room its drivers take. An STM32F411 or STM32F446 build leaves the servos, the GPS and the flight log out. A
board whose default receiver is a FlySky one builds the FlySky receivers in place of the CC2500 families where flash is
short. A 512 KB board whose configuration names a compass, a barometer and a flash chip leaves the GPS out, since
a board's own hardware comes before a peripheral its owner may not have. The output is deterministic for the same inputs, so a build regenerates it without a diff. The --feature
form prints on or off for one feature, which a build passes to the core project.
The --json form prints the board's MCU, flash size and crate, and each feature with its description, its default
and its state after the changes, for a configurator's feature selection.
"""
import json
import os
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from boardgen import find_config  # noqa: E402

FLASH_KB = {"STM32F405": 1024, "STM32F411": 512, "STM32F446": 512, "STM32F722": 512, "STM32F745": 1024,
            "STM32F746": 1024, "STM32F765": 2048, "STM32G474": 512, "STM32H725": 1024, "STM32H743": 2048,
            "STM32H753": 2048, "STM32H563": 2048, "AT32F435G": 1024, "AT32F435M": 4096, "APM32F405": 1024}

# Each feature with the smallest flash size, in KB, that contains it by default.
FEATURES = [
    ("Menus", 1024, "The menu system on the OSD, the display port and the CRSF transmitter's screen."),
    ("Gimbal", 1024, "The gimbal control on a UART."),
    ("LED_Strip", 1024, "The LED strip on a timer."),
    ("Transponder", 1024, "The race transponder on a timer."),
    ("Soft_Serial", 1024, "The two software serial ports on timers."),
    ("SD_Card", 1024, "The SD card as a flight log device."),
    ("Flash_Chip", None, "The flash chip as a flight log device, when the board's configuration names one."),
    ("Blackbox", 1024, "The flight log, or below that size when the board's configuration names a flash chip. An "
                       "STM32F411 or STM32F446 build leaves it out."),
    ("Mass_Storage", None, "The USB mass storage mode, which shows the flash chip's flight logs as a disk."),
    ("Servos", 0, "The servo outputs and the servo mixer, which an STM32F411 or STM32F446 build leaves out."),
    ("GPS", 0, "The GPS with its rescue, its holds and the position estimate, which an STM32F411 or STM32F446 build "
               "and a 512 KB board with a compass, a barometer and a flash chip of its own leave "
               "out."),
    ("Rangefinder", 1024, "The TF lidar and TOFSense rangefinders."),
    ("IBus_Telemetry", 1024, "The iBus telemetry."),
    ("LTM_Telemetry", 1024, "The LTM telemetry."),
    ("HoTT_Telemetry", 1024, "The HoTT telemetry."),
    ("MAVLink_Telemetry", 1024, "The MAVLink telemetry."),
    ("Jeti_EX_Bus", 1024, "The Jeti EX Bus receiver and its telemetry."),
    ("SUMD", 1024, "The SUMD receiver."),
    ("SUMH", 1024, "The SUMH receiver."),
    ("MAVLink_Receiver", 1024, "The MAVLink receiver."),
    ("Compass", 1024, "The compass, or below that size when the board's configuration names one."),
    ("Barometer", 1024, "The barometer, or below that size when the board's configuration names one."),
    ("Pitot", 1024, "The pitot airspeed sensor."),
    ("Dashboard", 1024, "The OLED dashboard on an I2C bus."),
    ("Optical_Flow", 1024, "The optical flow sensors."),
    ("SPI_Receiver", None, "The SPI receiver, when the board's configuration names its radio chip."),
    ("CC2500_Receiver", None, "The CC2500 SPI receiver families, when the board's configuration names the chip."),
    ("FlySky_Receiver", None, "The FlySky SPI receivers on an A7105, in a CC2500 build of 1024 KB or more, or in "
                              "place of the CC2500 families on a board whose default receiver is a FlySky one."),
    ("SX1280_Receiver", None, "The ExpressLRS SPI receiver, when the board's configuration names the SX1280."),
    ("Debug_Values", 0, "The debug values the debug mode selects."),
    ("Stack_Check", None, "The main stack's use measured from a pattern filled at start, shown in status."),
    ("Wing", None, "The wing build: fixed-wing flight in place of the multirotor-only features."),
    ("Flight_Plan", None, "The flight plan: its waypoint command and its map on the OSD."),
    ("Board_Checks", 1024, "The run-time checks of the board crate."),
    ("Packed_Data", -1024, "Named tables, strings and initialized data kept compressed in flash, unpacked at start "
                           "(STM32F7)."),
]

# The cold tables a packed build moves to RAM by their input sections: read by the command line, MSP, a
# configuration reset or a log start, never by the flight loop, and compressing below 80 percent.


# Features a board's configuration turns on at any flash size by naming one of the defines.
BOARD_DEFINES = {"Compass": ("USE_MAG",), "Barometer": ("USE_BARO",), "Flash_Chip": ("USE_FLASH",),
                 "Blackbox": ("USE_FLASH",),
                 "SPI_Receiver": ("USE_RX_SPI", "USE_RX_CC2500", "USE_RX_SX1280", "USE_RX_SX127X"),
                 "CC2500_Receiver": ("USE_RX_CC2500",), "SX1280_Receiver": ("USE_RX_SX1280",)}


def selection(flash_kb: int, changes: str, defines: frozenset = frozenset(), mcu: str = "",
              flysky_default: bool = False) -> dict:
    chosen = {name: (False if size is None else flash_kb >= size if size >= 0 else flash_kb < -size)
              or any(define in defines for define in BOARD_DEFINES.get(name, ()))
              for name, size, _ in FEATURES}
    if flash_kb <= 512:
        chosen["Debug_Values"] = False
    # No STM32F411 image fits its flash with the flight log, whose flash chip code goes with it below. The
    # STM32F446 has the same flash and main RAM, and the same cuts.
    if mcu in SMALL_F4:
        chosen["Servos"] = False
        chosen["GPS"] = False
        chosen["Blackbox"] = False
    # A board's own hardware comes before an external peripheral: 512 KB have no room for the GPS beside a
    # compass, a barometer and a flash chip with its flight log.
    if flash_kb <= 512 and all(chosen[name] for name in ("Compass", "Barometer", "Flash_Chip")):
        chosen["GPS"] = False
    # The FlySky receivers come with a CC2500 build where flash allows: beside the CC2500 families they take about
    # 4.5 KB, which no 512 KB board with those families has.
    chosen["FlySky_Receiver"] = chosen["CC2500_Receiver"] and flash_kb >= 1024
    # A board whose default receiver is a FlySky one has an A7105, so where flash is short it builds those
    # receivers and leaves the CC2500 families out.
    if flysky_default and flash_kb < 1024:
        chosen["FlySky_Receiver"] = True
        chosen["CC2500_Receiver"] = False
    by_key = {name.lower(): name for name, _, _ in FEATURES}
    for token in re.split(r"[\s,]+", changes.strip()):
        if not token:
            continue
        on = not token.startswith("-")
        key = token.lstrip("+-").lower()
        if key not in by_key:
            raise SystemExit(f"featuregen: unknown feature {token}; the features are "
                             + ", ".join(name for name, _, _ in FEATURES))
        chosen[by_key[key]] = on
    # The software serial ports run on the F4 and F7 timer table, which an STM32H7 does not have.
    if mcu.startswith("STM32H7"):
        chosen["Soft_Serial"] = False
    # A build without the flight log has no log storage and no mass storage mode over it.
    if not chosen["Blackbox"]:
        for name in ("SD_Card", "Flash_Chip", "Mass_Storage"):
            chosen[name] = False
    # Each optical flow sensor brings a rangefinder, so a build without rangefinders has no optical flow.
    if not chosen["Rangefinder"]:
        chosen["Optical_Flow"] = False
    # The MAVLink receiver answers over the MAVLink telemetry, so a build without that telemetry has no such receiver.
    if not chosen["MAVLink_Telemetry"]:
        chosen["MAVLink_Receiver"] = False
    return chosen


def generate(board: str, mcu: str, flash_kb: int, chosen: dict) -> str:
    column = max(len(name) for name, _, _ in FEATURES)
    out = ["--  The features this build contains, generated by tools/featuregen.py for",
           f"--  {board} ({mcu or 'no MCU named'}, {flash_kb} KB of flash). Do not edit.",
           "package Adaflight.Build_Features is",
           "   pragma Pure;",
           ""]
    for name, _, what in FEATURES:
        out.append(f"   --  {what}")
        out.append(f"   {name.ljust(column)} : constant Boolean := {chosen[name]};")
    out += ["", "   --  The flash size the features follow.", f"   Flash_KB : constant := {flash_kb};",
            "", "end Adaflight.Build_Features;", ""]
    return "\n".join(out)


def checks(chosen: dict) -> str:
    if chosen["Board_Checks"]:
        return "--  The board crate keeps its run-time checks. Generated by tools/featuregen.py.\n"
    return ("--  The board crate runs without its run-time checks. Generated by tools/featuregen.py.\n"
            "pragma Suppress (All_Checks);\n")


# The zeroed data: the core coupled memory's sections, then the main RAM's with the stacks and the heap, whose end the
# caller sets.
ZEROED = """
  /* Zeroed data placed in the core coupled memory by its section name: the
     menu's state and target, which the main RAM cannot hold. */
  .ccmbss (NOLOAD) : {
   . = ALIGN(0x8);
   __ccmbss_start = .;
   *(.bss.ccm .bss.ccm.*)
   . = ALIGN(0x8);
   __ccmbss_end = .;
  } > ccm

  .bss (NOLOAD): {
   . = ALIGN(0x8);
   __bss_start = .;

   *(.bss .bss.*)
   *(COMMON)

   . = ALIGN(0x8);    /* Align the stack to 64 bits */
   __bss_end = .;

   __interrupt_stack_start = .;
   *(.noinit.interrupt_stacks)
   . = ALIGN(0x8);
   __interrupt_stack_end = .;

{stack}   _end = .;
   __heap_start = .;
{heap_end}  } > sram_bs

  __bss_words = (__bss_end - __bss_start) >> 2;
"""

# The main stack in a plain build's zeroed data.
STACK = """   __stack_start = .;
   . += DEFINED (__stack_size) ? __stack_size : _DEFAULT_STACK_SIZE;
   . = ALIGN(0x8);
   __stack_end = .;

"""

# A packed build keeps this much heap below the unpacked data, for the allocations of elaboration.
HEAP_RESERVE = 4096

# The main stack a packed build keeps above the elaboration's code for the elaboration itself, and above the
# unpacking's model for the unpacking's frames; less on an STM32F411 or STM32F446, whose main RAM is short, whose
# elaboration's deepest path is about 6 KB and whose unpacking's is under 1 KB.
BOOT_STACK = 16384
BOOT_STACK_F411 = 8192
# The STM32F4 parts with 512 KB of flash and 128 KB of main RAM, which take the STM32F411's cuts and reserves.
SMALL_F4 = ("STM32F411", "STM32F446")
UNPACK_FRAMES = 8192
UNPACK_FRAMES_F411 = 2048

# Zeroed objects a packed build moves from the main RAM to the core coupled memory, for the main RAM the packed
# data and code take. None of them is a DMA target.
CCM_OBJECTS = ["adaflight__stm32__usart__receivers", "adaflight__stm32__flight__config",
               "adaflight__stm32__flight__ctx", "adaflight__stm32__osd__context", "adaflight__stm32__flight__sched",
               "adaflight__stm32__flight__lines", "adaflight__stm32__flight__env", "adaflight__stm32__rx_spi_cc2500__ops",
               "adaflight__stm32__esc_serial_port__p", "adaflight__stm32__blackbox__in_flight",
               "adaflight__stm32__osd__chip_state", "adaflight__stm32__pilot__rc",
               "adaflight__stm32__osd__task_data", "adaflight__stm32__control__ctl", "adaflight__stm32__osd__trail",
               "adaflight__stm32__flight__adj_ranges", "adaflight__stm32__blackbox__l",
               "adaflight__stm32__smartport__tunnel", "adaflight__stm32__radio__msp_link",
               "adaflight__stm32__rx_spi_sx1280__pin_ops", "adaflight__stm32__rx_spi_sx1280__receiver",
               "adaflight__stm32__rx_spi_sx1280__tunnel"]


# The RAM the unpacking's model takes in the main stack, below the start-up's frames.
UNPACK_SCRATCH = 4096

# The flight loop's configuration and context in an STM32F4's core coupled memory, for the main RAM the stack takes.
F4_CCM_OBJECTS = ["adaflight__stm32__flight__config", "adaflight__stm32__flight__ctx"]

# Read-only data that stays in flash: the run-time libraries' and the unpacking's own, which the start-up reads
# before the unpacking; the unpacking's units build outside link time optimization to keep their file names.
RUNTIME_LIBRARIES = ("*libgnat.a:* *libgnarl.a:* *libgcc.a:* *libc.a:* *libm.a:* *:adaflight-lzma.o "
                     "*adaflight-stm32-data_pack*.o *adaflight-stm32-build_stamp.o")

# A packed STM32F7 build's command line printing code, unpacked into RAM and run there.
RAM_TEXT = """  .ram_text :
  {
    . = ALIGN(0x8);
    __ram_text_start = .;
    *(.text.adaflight__stm32__console__cli__put_*)
    . = ALIGN(0x8);
  } > sram_da AT > staging
"""

# A packed STM32F7 build's named tables and strings outside the run-time libraries, unpacked into RAM.
PACKED_TABLES = """  .packed_tables :
  {
    . = ALIGN(0x4);
    EXCLUDE_FILE (""" + RUNTIME_LIBRARIES + """) *(.rodata.adaflight__* .rodata.codes.* .rodata.adainit.*)
    EXCLUDE_FILE (""" + RUNTIME_LIBRARIES + """) *(.rodata.str* .rodata)
    . = ALIGN(0x4);
  } > sram_da AT > staging
"""


def ccm_objects(chosen: dict, mcu: str) -> list:
    """The zeroed objects a build places in the core coupled memory by name: on an STM32F4 the flight loop's
    configuration and context, on a packed STM32F7 the larger list that leaves its main RAM to the tables."""
    if mcu.startswith("STM32F4"):
        return F4_CCM_OBJECTS
    return CCM_OBJECTS if chosen["Packed_Data"] else []


# An STM32H7's DMA buffers by their section name, in its D2 RAM: its DMA does not reach the data tightly coupled
# memory, and its cache unit keeps the D2 RAM uncached.
DMA_ZEROED = """
  .dmabss (NOLOAD) : {
   . = ALIGN(32);
   __dmabss_start = .;
   *(.bss.dma .bss.dma.*)
   . = ALIGN(32);
   __dmabss_end = .;
  } > d2
"""


def zeroed(chosen: dict, mcu: str, heap_end: str, stack: str) -> str:
    text = ((DMA_ZEROED if mcu.startswith("STM32H7") else "")
            + ZEROED.replace("{heap_end}", heap_end).replace("{stack}", stack))
    return text.replace("   *(.bss.ccm .bss.ccm.*)\n",
                        "   *(.bss.ccm .bss.ccm.*)\n" + "".join(f"   *(.bss.{name})\n" for name in ccm_objects(chosen, mcu)))


def ram_early(chosen: dict, mcu: str = "") -> str:
    """The RAM sections placed before the code: in a packed build the zeroed data, the heap's reserve, the initialized
    data, on an STM32F7 the named tables and string literals outside the run-time libraries, those of the elaboration
    included, and the command line's printing code, then the elaboration's code and the main stack over it; nothing in
    a plain build."""
    if not chosen["Packed_Data"]:
        return "/* Plain build: the RAM sections follow the read-only data. Generated by tools/featuregen.py. */\n"
    tables = not mcu.startswith("STM32F4")
    return ("/* Packed build: zeroed data, the heap, then the initialized data, "
            + ("named tables, strings, printing code and\n   " if tables else "\n   ")
            + "elaboration code unpacked into the main RAM, and the main stack over the elaboration code.\n"
            "   Generated by tools/featuregen.py. */\n"
            + zeroed(chosen, mcu, f"   . += {HEAP_RESERVE};\n   __heap_end = .;\n", "") + """
  .data :
  {
    __packed_start = .;
    __data_start = .;
    *(.data .data.* .gnu.linkonce.d*)
    . = ALIGN(0x4);
    __data_end = .;
  } > sram_da AT > staging
  __data_load = LOADADDR (.data);
  __data_words = 0;

  .ccmdata :
  {
    __ccmdata_start = .;
    *(.ccmdata .ccmdata.*)
    . = ALIGN(0x4);
    __ccmdata_end = .;
  } > ccm_da AT > staging
  __ccmdata_load = LOADADDR (.ccmdata);
  __ccmdata_words = (__ccmdata_end - __ccmdata_start) >> 2;

""" + (PACKED_TABLES + RAM_TEXT if tables else "  __ram_text_start = .;\n") + """
  /* The elaboration's code, run once from the bottom of the main stack before the stack takes its RAM back. */
  .boot_code :
  {
    . = ALIGN(0x8);
    __boot_start = .;
    *(.text.*adainit* .text.*___elabb* .text.*___elabs*)
    . = ALIGN(0x8);
    __boot_end = .;
    __packed_end = .;
  } > sram_da AT > staging

  __stack_start = __boot_start;
  .main_stack (NOLOAD) :
  {
    . += MAX (DEFINED (__stack_size) ? __stack_size : _DEFAULT_STACK_SIZE,
              __boot_end - __boot_start + BOOT_STACK) - (__boot_end - __boot_start);
    . = ALIGN(0x8);
    __stack_end = .;
  } > sram_da

  /* The unpacking's model, in the main stack between the boot code and the start-up's frames. */
  __unpack_scratch = __stack_end - UNPACK_FRAMES - UNPACK_SCRATCH;
  ASSERT (__unpack_scratch >= __boot_end, "no room for the unpack model")
""".replace("UNPACK_SCRATCH", str(UNPACK_SCRATCH))
       .replace("BOOT_STACK", str(BOOT_STACK_F411 if mcu in SMALL_F4 else BOOT_STACK))
       .replace("UNPACK_FRAMES", str(UNPACK_FRAMES_F411 if mcu in SMALL_F4 else UNPACK_FRAMES)))


def ram_late(chosen: dict, mcu: str = "") -> str:
    """The RAM sections placed after the flash's read-only data: in a plain build the initialized data, copied by the
    run-time library from flash, and the zeroed data; nothing in a packed build."""
    if chosen["Packed_Data"]:
        return "/* Packed build: the RAM sections precede the code. Generated by tools/featuregen.py. */\n"
    return ("/* Initialized data copied from flash, then zeroed data. Generated by tools/featuregen.py. */\n" + """
  __data_load = __rom_end;
  .data : AT (__data_load)
  {
    __data_start = .;
    *(.data .data.* .gnu.linkonce.d*)
    . = ALIGN(0x4);
    __data_end = .;
  } > sram_da
  __data_words = (__data_end - __data_start) >> 2;
  __packed_start = __data_start;
  __packed_end = __data_start;
  __boot_start = __data_start;
  __boot_end = __data_start;
  __ram_text_start = __data_start;
  __unpack_scratch = __data_start;

  __ccmdata_load = __rom_end + (__data_words << 2);
  .ccmdata : AT (__ccmdata_load)
  {
    __ccmdata_start = .;
    *(.ccmdata .ccmdata.*)
    . = ALIGN(0x4);
    __ccmdata_end = .;
  } > ccm_da
  __ccmdata_words = (__ccmdata_end - __ccmdata_start) >> 2;

""" + zeroed(chosen, mcu, "   __heap_end = ORIGIN(sram_bs) + LENGTH(sram_bs);\n", STACK))


def itcm_load(chosen: dict) -> str:
    """Where an STM32F7 image loads its ITCM code from: the staging region in a packed build, whose packer
    stores that code as a stream, and flash in a plain build, whose start copies it."""
    region = "staging" if chosen["Packed_Data"] else "flash"
    return f'/* Generated by tools/featuregen.py. */\nREGION_ALIAS("itcm_load", {region})\n'


# Board units a build replaces with stub bodies when it leaves their feature out: the feature, the unit and the
# source file stem; the stub body is the stem with "__off".
STUBS = [("Menus", "Adaflight.STM32.Menu", "adaflight-stm32-menu"),
         ("SD_Card", "Adaflight.STM32.SD", "adaflight-stm32-sd"),
         ("Flash_Chip", "Adaflight.STM32.Flash_Chip", "adaflight-stm32-flash_chip"),
         ("Blackbox", "Adaflight.STM32.Blackbox", "adaflight-stm32-blackbox"),
         ("Mass_Storage", "Adaflight.STM32.Mass_Storage_Mode", "adaflight-stm32-mass_storage_mode"),
         ("Servos", "Adaflight.STM32.Servos", "adaflight-stm32-servos"),
         ("GPS", "Adaflight.STM32.GPS", "adaflight-stm32-gps"),
         ("Compass", "Adaflight.STM32.Compass", "adaflight-stm32-compass"),
         ("Barometer", "Adaflight.STM32.Baro", "adaflight-stm32-baro"),
         ("Pitot", "Adaflight.STM32.Pitot", "adaflight-stm32-pitot"),
         ("Dashboard", "Adaflight.STM32.Dashboard", "adaflight-stm32-dashboard"),
         ("Soft_Serial", "Adaflight.STM32.Soft_Serial", "adaflight-stm32-soft_serial"),
         ("Optical_Flow", "Adaflight.STM32.Optical_Flow", "adaflight-stm32-optical_flow"),
         ("SPI_Receiver", "Adaflight.STM32.RX_SPI", "adaflight-stm32-rx_spi"),
         ("CC2500_Receiver", "Adaflight.STM32.RX_SPI_CC2500", "adaflight-stm32-rx_spi_cc2500"),
         ("FlySky_Receiver", "Adaflight.STM32.RX_SPI_A7105", "adaflight-stm32-rx_spi_a7105"),
         ("SX1280_Receiver", "Adaflight.STM32.RX_SPI_SX1280", "adaflight-stm32-rx_spi_sx1280")]


def feature_units(chosen: dict) -> str:
    """The project the board crates import for the bodies of the stubbed units and the sources they leave out."""
    lines = ["--  The bodies of the board units a build stubs for the features it leaves out, and the sources it",
             "--  leaves out. Generated by tools/featuregen.py.", "abstract project Adaflight_Feature_Units is"]
    excluded = []
    for feature, unit, stem in STUBS:
        on = chosen[feature]
        name = unit.rsplit(".", 1)[-1] + "_Body"
        lines.append(f'   {name} := "{stem}{"" if on else "__off"}.adb";')
        excluded.append(f'"{stem}{"__off" if on else ""}.adb"')
    lines.append("   Excluded := (" + ", ".join(excluded) + ");")
    lines.append("end Adaflight_Feature_Units;")
    return "\n".join(lines) + "\n"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


def board_selection(configs: Path, board: str, changes: str) -> tuple:
    """The board's MCU, its flash size and the features chosen for it."""
    text = find_config(configs, board).read_text()
    m = re.search(r"^#define\s+FC_TARGET_MCU\s+(\w+)", text, re.M)
    mcu = m.group(1) if m else ""
    if os.environ.get("FLASH_KB"):
        flash_kb = int(os.environ["FLASH_KB"])
    elif mcu in FLASH_KB:
        flash_kb = FLASH_KB[mcu]
    else:
        raise SystemExit(f"featuregen: no flash size for the MCU {mcu or 'of ' + board}; set FLASH_KB")
    defines = frozenset(re.findall(r"^#define\s+(\w+)", text, re.M))
    flysky_default = re.search(r"^#define\s+RX_SPI_DEFAULT_PROTOCOL\s+RX_SPI_A7105_FLYSKY", text, re.M) is not None
    return mcu, flash_kb, selection(flash_kb, changes, defines, mcu, flysky_default)


def describe(board: str, mcu: str, flash_kb: int, default: dict, chosen: dict) -> str:
    crate = "stm32f4" if mcu.startswith("STM32F4") else "stm32f7" if mcu.startswith("STM32F7") else None
    return json.dumps({"board": board, "mcu": mcu, "flash_kb": flash_kb, "crate": crate,
                       "features": [{"name": name, "description": what, "default": default[name], "on": chosen[name]}
                                    for name, _, what in FEATURES]}, indent=1) + "\n"


def main() -> None:
    if len(sys.argv) in (4, 5) and sys.argv[1] == "--json":
        configs, board = Path(sys.argv[2]), sys.argv[3]
        mcu, flash_kb, default = board_selection(configs, board, "")
        _, _, chosen = board_selection(configs, board, sys.argv[4] if len(sys.argv) == 5 else "")
        sys.stdout.write(describe(board, mcu, flash_kb, default, chosen))
        return
    if len(sys.argv) in (5, 6) and sys.argv[1] == "--feature":
        name = sys.argv[2]
        _, _, chosen = board_selection(Path(sys.argv[3]), sys.argv[4], sys.argv[5] if len(sys.argv) == 6 else "")
        if name not in chosen:
            raise SystemExit(f"featuregen: unknown feature {name}")
        print("on" if chosen[name] else "off")
        return
    if len(sys.argv) not in (4, 5):
        raise SystemExit(__doc__)
    configs, board, output = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    mcu, flash_kb, chosen = board_selection(configs, board, sys.argv[4] if len(sys.argv) == 5 else "")
    write(output, generate(board, mcu, flash_kb, chosen))
    write(output.parent / "adaflight-checks.adc", checks(chosen))
    write(output.parent / "ram_early.ld", ram_early(chosen, mcu))
    write(output.parent / "ram_late.ld", ram_late(chosen, mcu))
    write(output.parent / "itcm_load.ld", itcm_load(chosen))
    write(output.parent / "adaflight_feature_units.gpr", feature_units(chosen))


if __name__ == "__main__":
    main()
