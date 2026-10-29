#!/usr/bin/env python3
"""Generate the Ada board package for one board from its configuration file.

usage: boardgen.py <configs dir> <board name> <output .ads> [NAME=VALUE ...]

The configuration file is the board's config.h in the board configuration repository under
third_party/board-configs: #define lines that name pins (NAME_PIN Pxy), the inverter pins
(INVERTER_PIN_UARTn Pxy), the board, manufacturer and MCU names, the crystal frequency, the
beeper polarity and frequency, and the timer pin map. Everything else is left out for now.
The output is package Adaflight.Board over the types in Adaflight.Pins, deterministic for a
given file so a build regenerates it without a diff. A NAME=VALUE argument sets a define over the
file's, as a target without a board of its own sets its MSP UART.
"""
import re
import sys
from pathlib import Path

ACRONYMS = {"LED", "UART", "TX", "RX", "SPI", "SCK", "SDI", "SDO", "CS", "ADC", "VBAT", "RSSI", "CURR", "USB",
            "EXTI", "PINIO", "SDCARD", "OSD", "DMA", "PWM", "HZ", "MHZ", "I2C", "SCL", "SDA", "ESC", "TIM", "CH",
            "DSHOT", "HSE", "MCU", "ID", "CC", "FC", "SDIO", "CK", "CMD", "D0", "D1", "D2", "D3", "MOSI", "MISO",
            "NSS", "RF", "LRS", "GPS", "VTX", "BARO", "MAG", "IMU", "MAX7456"}


def ada_name(define: str) -> str:
    parts = []
    for seg in define.split("_"):
        base = seg.rstrip("0123456789")
        if seg in ACRONYMS or base in ACRONYMS:
            parts.append(seg)
        else:
            parts.append(base.capitalize() + seg[len(base):])
    return "_".join(parts)


def pin_literal(text: str) -> str:
    m = re.fullmatch(r"P([A-K])(\d{1,2})", text.strip())
    if not m:
        raise SystemExit(f"not a pin: {text}")
    return f"(Port_{m.group(1)}, {int(m.group(2))})"


BLACKBOX_DEVICES = {"BLACKBOX_DEVICE_NONE": 0, "BLACKBOX_DEVICE_FLASH": 1, "BLACKBOX_DEVICE_SDCARD": 2,
                    "BLACKBOX_DEVICE_SERIAL": 3}
VOLTAGE_SOURCES = {"VOLTAGE_METER_NONE": 0, "VOLTAGE_METER_ADC": 1, "VOLTAGE_METER_ESC": 2}
CURRENT_SOURCES = {"CURRENT_METER_NONE": 0, "CURRENT_METER_ADC": 1, "CURRENT_METER_VIRTUAL": 2,
                   "CURRENT_METER_ESC": 3, "CURRENT_METER_MSP": 4}


def pin_tag(text: str) -> int:
    """The pin's tag as the configuration stores it: the port from one in the high nibble and the
    pin number in the low one, zero for none."""
    m = re.fullmatch(r"P([A-K])(\d{1,2})", text)
    return ((ord(m.group(1)) - ord("A") + 1) << 4) | int(m.group(2)) if m else 0


def number(text, default: int) -> int:
    m = re.match(r"\s*(-?\d+)", text or "")
    return int(m.group(1)) if m else default


def pinio_config(text) -> int:
    """A PINIO output's configuration byte: a number, or the inverted flag and the push-pull mode by name,
    the push-pull mode when unset."""
    if not text:
        return 1
    if re.match(r"\s*\d", text):
        return number(text, 1)
    return (0x80 if "PINIO_CONFIG_OUT_INVERTED" in text else 0) | (1 if "PINIO_CONFIG_MODE_OUT_PP" in text else 0)


def i2c_device(text: str) -> int:
    """The I2C bus a configuration stores for an instance such as I2CDEV_1: its number, zero for none."""
    match = re.fullmatch(r"I2CDEV_([1-4])", text.strip())
    return int(match.group(1)) if match else 0


def spi_device(text: str) -> int:
    """The SPI bus a configuration stores for an instance such as SPI3: its number, zero for none."""
    match = re.fullmatch(r"SPI([1-6])", text.strip())
    return int(match.group(1)) if match else 0


def serial_port(text) -> int:
    """A serial port name's identifier as the reference numbers them, -1 for none."""
    text = re.sub(r"//.*|/\*.*?\*/", "", text or "").strip()
    if not text:
        return -1
    m = re.fullmatch(r"SERIAL_PORT_(USB_VCP|SOFTSERIAL(\d+)|LPUART(\d+)|UART0|US?ART(\d+)|NONE)", text)
    if not m:
        raise SystemExit(f"boardgen: unknown serial port {text}")
    if m.group(1) == "USB_VCP":
        return 20
    if m.group(2):
        return 29 + int(m.group(2))
    if m.group(3):
        return 39 + int(m.group(3))
    if m.group(1) == "UART0":
        return 50
    if m.group(4):
        return 50 + int(m.group(4))
    return -1


def find_config(configs: Path, board: str) -> Path:
    hits = sorted(configs.glob(f"*/{board}/config.h"))
    if len(hits) != 1:
        raise SystemExit(f"{len(hits)} configuration files for {board} under {configs}")
    return hits[0]


def generate(config: Path, overrides: dict) -> str:
    text = config.read_text()
    defines = {}
    for m in re.finditer(r"^#define\s+(\w+)(?:[ \t]+([^\n\\]*?))?[ \t]*$", text, re.M):
        defines[m.group(1)] = (m.group(2) or "").strip()
    defines.update(overrides)
    fixed = [f"UART{n}_{d}_PIN" for n in range(1, 7) for d in ("TX", "RX")] \
        + [f"SPI{n}_{d}_PIN" for n in range(1, 7) for d in ("SCK", "SDI", "SDO")] \
        + [f"I2C{n}_{d}_PIN" for n in range(1, 5) for d in ("SCL", "SDA")] \
        + ["LED0_PIN", "GYRO_1_CS_PIN", "GYRO_1_EXTI_PIN", "FLASH_CS_PIN", "SDCARD_SPI_CS_PIN", "SDCARD_DETECT_PIN"]
    pins = sorted((ada_name(k), pin_literal(v)) for k, v in defines.items()
                  if k.endswith("_PIN") and k not in fixed and re.fullmatch(r"P[A-K]\d{1,2}", v))
    # Every UART's and SPI bus's pins and the pins the crate reads by name, a placeholder where the board
    # lacks the pin, with the ports' presence.
    for k in fixed:
        v = defines.get(k, "")
        pins.append((ada_name(k), pin_literal(v) if re.fullmatch(r"P[A-K]\d{1,2}", v) else "(Port_A, 0)"))
    presence = [(f"Has_UART{n}", all(re.fullmatch(r"P[A-K]\d{1,2}", defines.get(f"UART{n}_{d}_PIN", "")) for d in ("TX", "RX")))
                for n in range(1, 7)] \
        + [(f"Has_SPI{n}", all(re.fullmatch(r"P[A-K]\d{1,2}", defines.get(f"SPI{n}_{d}_PIN", "")) for d in ("SCK", "SDI", "SDO")))
           for n in range(1, 7)] \
        + [(f"Has_I2C{n}", all(re.fullmatch(r"P[A-K]\d{1,2}", defines.get(f"I2C{n}_{d}_PIN", "")) for d in ("SCL", "SDA")))
           for n in range(1, 5)]
    pins += sorted((ada_name(k), pin_literal(v)) for k, v in defines.items()
                   if k.startswith("INVERTER_PIN_") and re.fullmatch(r"P[A-K]\d{1,2}", v))
    timer_map = []
    m = re.search(r"#define TIMER_PIN_MAPPING\s*\\\n((?:.*\\\n)*.*)", text)
    if m:
        # An entry names its pin or the define of one, such as MOTOR1_PIN.
        for t in re.finditer(r"TIMER_PIN_MAP\(\s*(\d+)\s*,\s*(\w+)\s*,\s*(\d+)\s*,\s*(-?\d+)\s*\)", m.group(0)):
            pin = defines.get(t.group(2), t.group(2))
            timer_map.append((int(t.group(1)), pin_literal(pin), int(t.group(3)), int(t.group(4))))
    width = max([len(n) for n, _ in pins] + [1])
    out = []
    out.append("--  Board pins and parameters generated by tools/boardgen.py from the board")
    out.append(f"--  configuration file of {defines.get('BOARD_NAME', config.parent.name)}. Do not edit.")
    out.append("with Adaflight.Pins; use Adaflight.Pins;")
    out.append("")
    out.append("package Adaflight.Board is")
    out.append("")
    out.append(f"   Board_Name      : constant String := \"{defines.get('BOARD_NAME', config.parent.name)}\";")
    out.append(f"   Manufacturer_ID : constant String := \"{defines.get('MANUFACTURER_ID', config.parent.parent.name)}\";")
    out.append(f"   MCU_Name        : constant String := \"{defines.get('FC_TARGET_MCU', '')}\";")
    out.append(f"   HSE_MHz         : constant := {int(defines.get('SYSTEM_HSE_MHZ', '8'))};")
    out.append(f"   Beeper_Inverted : constant Boolean := {'True' if 'BEEPER_INVERTED' in defines else 'False'};")
    out.append(f"   Beeper_PWM_Hz   : constant := {int(defines.get('BEEPER_PWM_HZ', '0'))};")
    out.append("")
    out.append("   --  The pin tags of the inputs, the beeper, the OSD chip's select, the SD")
    out.append("   --  card's select and detect, the flash chip's select, the USB cable")
    out.append("   --  detect and the UARTs' inverters, zero for none,")
    out.append("   --  the gyro's and their SPI buses from 1, the barometer's I2C or SPI bus and chip, whether the detect pin reads low")
    out.append("   --  for a card, the flight log device, the meter defaults, the PINIO")
    out.append("   --  outputs' pins, configurations and boxes by permanent id, and the")
    out.append("   --  motors' and the LED strip's pins, the host defaults where the board")
    out.append("   --  names none.")
    tags = [("Beeper_Tag", "BEEPER_PIN"), ("ADC_VBAT_Tag", "ADC_VBAT_PIN"), ("ADC_CURR_Tag", "ADC_CURR_PIN"),
            ("ADC_RSSI_Tag", "ADC_RSSI_PIN"), ("ADC_External1_Tag", "ADC_EXTERNAL1_PIN"),
            ("MAX7456_CS_Tag", "MAX7456_SPI_CS_PIN"), ("SDCARD_CS_Tag", "SDCARD_SPI_CS_PIN"),
            ("SDCARD_Detect_Tag", "SDCARD_DETECT_PIN"), ("FLASH_CS_Tag", "FLASH_CS_PIN"),
            ("USB_Detect_Tag", "USB_DETECT_PIN"), ("Baro_CS_Tag", "BARO_CS_PIN"), ("Baro_EOC_Tag", "BARO_EOC_PIN"),
            ("Baro_XCLR_Tag", "BARO_XCLR_PIN")] \
        + [(f"Inverter_UART{i}_Tag", f"INVERTER_PIN_UART{i}") for i in range(1, 7)] \
        + [(f"PINIO{i}_Tag", f"PINIO{i}_PIN") for i in range(1, 5)] \
        + [(f"MOTOR{i}_Tag", f"MOTOR{i}_PIN") for i in range(1, 9)] \
        + [("LED_Strip_Tag", "LED_STRIP_PIN")]
    defaults = [("Default_Voltage_Meter_Source", VOLTAGE_SOURCES[defines.get("DEFAULT_VOLTAGE_METER_SOURCE",
                                                                             "VOLTAGE_METER_NONE")]),
                ("Default_Current_Meter_Source", CURRENT_SOURCES[defines.get("DEFAULT_CURRENT_METER_SOURCE",
                                                                             "CURRENT_METER_VIRTUAL")]),
                ("Default_Voltage_Meter_Scale", number(defines.get("DEFAULT_VOLTAGE_METER_SCALE"), 110)),
                ("Default_Current_Meter_Scale", number(defines.get("DEFAULT_CURRENT_METER_SCALE"), 400)),
                ("Gyro_1_SPI_Device", spi_device(defines.get("GYRO_1_SPI_INSTANCE", ""))),
                ("Baro_I2C_Device", i2c_device(defines.get("BARO_I2C_INSTANCE", ""))),
                ("Baro_SPI_Device", spi_device(defines.get("BARO_SPI_INSTANCE", ""))),
                ("Baro_BMP280", "True" if "USE_BARO_BMP280" in defines else "False"),
                ("MAX7456_SPI_Device", spi_device(defines.get("MAX7456_SPI_INSTANCE", ""))),
                ("SDCARD_SPI_Device", spi_device(defines.get("SDCARD_SPI_INSTANCE", ""))),
                ("FLASH_SPI_Device", spi_device(defines.get("FLASH_SPI_INSTANCE", ""))),
                ("SDCARD_Detect_Low", "True" if "SDCARD_DETECT_INVERTED" in defines else "False"),
                ("Default_Blackbox_Device", BLACKBOX_DEVICES[defines.get("DEFAULT_BLACKBOX_DEVICE",
                                                                         "BLACKBOX_DEVICE_NONE")])] \
        + [(f"PINIO{i}_Config", pinio_config(defines.get(f"PINIO{i}_CONFIG"))) for i in range(1, 5)] \
        + [(f"PINIO{i}_Box", number(defines.get(f"PINIO{i}_BOX"), 255)) for i in range(1, 5)] \
        + [("MSP_UART", serial_port(defines.get("MSP_UART"))),
           ("Use_MSP_UART", serial_port(defines.get("USE_MSP_UART"))),
           ("MSP_Display_Port_UART", serial_port(defines.get("MSP_DISPLAYPORT_UART")))]
    column = max(len(n) for n, _ in tags + defaults)
    for name, define in tags:
        out.append(f"   {name.ljust(column)} : constant := {pin_tag(defines.get(define, ''))};")
    for name, value in defaults:
        kind = "Boolean " if value in ("True", "False") else ""
        out.append(f"   {name.ljust(column)} : constant {kind}:= {value};")
    out.append("")
    for name, lit in pins:
        out.append(f"   {name.ljust(width)} : constant Pin := {lit};")
    out.append("")
    out.append("   --  The UARTs and the SPI buses the board has.")
    for name, has in presence:
        out.append(f"   {name.ljust(width)} : constant Boolean := {'True' if has else 'False'};")
    out.append("")
    if timer_map:
        out.append("   Timer_Map : constant Timer_Pin_Map :=")
        rows = [f"({i}, {lit}, {opt}, {dma})" for i, lit, opt, dma in timer_map]
        if len(rows) == 1:
            out.append(f"     (1 => {rows[0]});")
        else:
            out.append("     (" + ",\n      ".join(rows) + ");")
    else:
        out.append("   Timer_Map : constant Timer_Pin_Map (1 .. 0) := (others => (0, (Port_A, 0), 0, 0));")
    out.append("")
    out.append("end Adaflight.Board;")
    return "\n".join(out) + "\n"


def main() -> None:
    if len(sys.argv) < 4 or any("=" not in a for a in sys.argv[4:]):
        raise SystemExit(__doc__)
    configs, board, output = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    overrides = dict(a.split("=", 1) for a in sys.argv[4:])
    text = generate(find_config(configs, board), overrides)
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists() or output.read_text() != text:
        output.write_text(text)


if __name__ == "__main__":
    main()
