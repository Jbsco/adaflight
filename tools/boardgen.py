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


RX_SPI_PROTOCOLS = {"RX_SPI_NRF24_V202_250K": 0, "RX_SPI_NRF24_V202_1M": 1, "RX_SPI_NRF24_SYMA_X": 2,
                    "RX_SPI_NRF24_SYMA_X5C": 3, "RX_SPI_NRF24_CX10": 4, "RX_SPI_NRF24_CX10A": 5,
                    "RX_SPI_NRF24_H8_3D": 6, "RX_SPI_FRSKY_D": 8, "RX_SPI_FRSKY_X": 9, "RX_SPI_A7105_FLYSKY": 10,
                    "RX_SPI_A7105_FLYSKY_2A": 11, "RX_SPI_NRF24_KN": 12, "RX_SPI_SFHSS": 13,
                    "RX_SPI_CYRF6936_DSM": 14, "RX_SPI_FRSKY_X_LBT": 15, "RX_SPI_REDPINE": 16,
                    "RX_SPI_FRSKY_X_V2": 17, "RX_SPI_FRSKY_X_LBT_V2": 18, "RX_SPI_EXPRESSLRS": 19}
RX_FEATURES = {"FEATURE_RX_PPM": 1, "FEATURE_RX_SERIAL": 8, "FEATURE_RX_PARALLEL_PWM": 2 ** 13,
               "FEATURE_RX_MSP": 2 ** 14, "FEATURE_RX_SPI": 2 ** 25}
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


# The MCU targets whose own headers name both SD card modes, and those naming the SPI mode alone; a board's
# configuration can name either mode itself, as F405 boards name the SPI mode.
SDCARD_SDIO_MCUS = {"STM32F411", "STM32F446", "STM32F722", "STM32F745", "STM32H562", "STM32H563", "STM32H723",
                    "STM32H725", "STM32H735", "STM32H743", "STM32H753", "STM32N657"}
SDCARD_SPI_MCUS = SDCARD_SDIO_MCUS | {"STM32C562", "STM32C591", "STM32C5A3"}


def sdcard_mode(defines: dict) -> int:
    """The SD card's default mode, 0 off, 1 SPI or 2 SDIO: none without USE_SDCARD, otherwise SDIO where the build
    has that mode, else SPI, then SPI for a named SPI bus and select pin, and SDIO for a named SDIO device."""
    if "USE_SDCARD" not in defines:
        return 0
    mcu = defines.get("FC_TARGET_MCU", "")
    sdio = mcu in SDCARD_SDIO_MCUS or "USE_SDCARD_SDIO" in defines
    spi = mcu in SDCARD_SPI_MCUS or "USE_SDCARD_SPI" in defines
    mode = 2 if sdio else 1 if spi else 0
    if spi and spi_device(defines.get("SDCARD_SPI_INSTANCE", "")) > 0 \
            and re.fullmatch(r"P[A-K]\d{1,2}", defines.get("SDCARD_SPI_CS_PIN", "")):
        mode = 1
    if sdio and defines.get("SDIO_DEVICE", "SDIOINVALID") not in ("", "SDIOINVALID"):
        mode = 2
    return mode


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


# The gyro drivers on an SPI bus: with one of them a board's gyro bus is its SPI instance.
SPI_GYROS = ("USE_SPI_GYRO", "USE_GYRO_SPI_ICM20689", "USE_GYRO_SPI_MPU6000", "USE_GYRO_SPI_MPU6500",
             "USE_GYRO_SPI_MPU9250", "USE_GYRO_SPI_ICM20601", "USE_GYRO_SPI_ICM20602", "USE_GYRO_SPI_ICM20608G",
             "USE_GYRO_L3GD20", "USE_ACCGYRO_BMI160", "USE_ACCGYRO_BMI270", "USE_ACCGYRO_BMI423",
             "USE_GYRO_SPI_ICM42605", "USE_GYRO_SPI_ICM42688P", "USE_ACCGYRO_ICM42622P", "USE_ACCGYRO_ICM42686P",
             "USE_ACCGYRO_ICM56686", "USE_ACCGYRO_ICM40609D", "USE_ACCGYRO_ICM45605", "USE_ACCGYRO_ICM45686",
             "USE_ACCGYRO_IIM42652", "USE_ACCGYRO_IIM42653", "USE_ACCGYRO_LSM6DSV16X", "USE_ACCGYRO_LSM6DSV32X",
             "USE_ACCGYRO_LSM6DSO", "USE_ACCGYRO_LSM6DSK320X")
ALIGNMENT_CODES = {"ALIGN_DEFAULT": 0, "CW0_DEG": 1, "CW90_DEG": 2, "CW180_DEG": 3, "CW270_DEG": 4, "CW0_DEG_FLIP": 5,
                   "CW90_DEG_FLIP": 6, "CW180_DEG_FLIP": 7, "CW270_DEG_FLIP": 8, "ALIGN_CUSTOM": 9}


def gyro_alignment(defines: dict, n: int):
    """A gyro's alignment code and its custom angles in decidegrees: the board's standard alignment, CW0 where
    it names none, or the custom code with the board's angles cut to whole degrees."""
    angles = [defines.get(f"GYRO_{n}_ALIGN_{axis}") for axis in ("ROLL", "PITCH", "YAW")]
    if any(a is not None for a in angles):
        return (ALIGNMENT_CODES.get(defines.get(f"GYRO_{n}_ALIGN", "ALIGN_CUSTOM"), 9),
                [int(number(a, 0) / 10) * 10 for a in angles])
    return ALIGNMENT_CODES.get(defines.get(f"GYRO_{n}_ALIGN", "CW0_DEG"), 1), [0, 0, 0]


def gyro_count(defines: dict) -> int:
    """The gyros a board names by their select pins, one at least, and two at most as the configuration has
    two gyro device entries."""
    return max(1, min(2, sum(1 for n in range(1, 5) if f"GYRO_{n}_CS_PIN" in defines)))


def default_gyros_enabled(defines: dict) -> int:
    """The mask of the gyros a board enables by default: the first, the second or both by name or by number,
    the first where the board says nothing."""
    choice = re.sub(r"//.*|/\*.*?\*/", "", defines.get("DEFAULT_GYRO_TO_USE", "")).strip()
    return {"GYRO_CONFIG_USE_GYRO_1": 1, "0": 1, "GYRO_CONFIG_USE_GYRO_2": 2, "1": 2,
            "GYRO_CONFIG_USE_GYRO_BOTH": 3, "2": 3}.get(choice, 1)


def either(defines: dict, *names: str) -> str:
    """The value of the first of these names the configuration defines, empty for none."""
    return next((defines[n] for n in names if n in defines), "")


def timer_number(text) -> int:
    """A timer instance's number, as TIM5 gives 5, zero when the board names none."""
    m = re.fullmatch(r"TIM(\d+)", (text or "").strip())
    return int(m.group(1)) if m else 0


def rx_spi_protocol(text) -> int:
    """A receiver protocol name's number, zero when the board names none."""
    text = (text or "").strip()
    if not text:
        return 0
    if text not in RX_SPI_PROTOCOLS:
        raise SystemExit(f"boardgen: unknown SPI receiver protocol {text}")
    return RX_SPI_PROTOCOLS[text]


def rx_feature(text) -> int:
    """The default receiver feature's bit, the serial receiver when the board names none."""
    text = (text or "FEATURE_RX_SERIAL").strip()
    if text not in RX_FEATURES:
        raise SystemExit(f"boardgen: unknown receiver feature {text}")
    return RX_FEATURES[text]


BMP280_BARO = ("USE_BARO_BMP280", "USE_BARO_SPI_BMP280")
BMP388_BARO = ("USE_BARO_BMP388", "USE_BARO_SPI_BMP388")
MS5611_BARO = ("USE_BARO_MS5611", "USE_BARO_SPI_MS5611")
LPS22DF_BARO = ("USE_BARO_LPS22DF", "USE_BARO_SPI_LPS22DF")
QMP6988_BARO = ("USE_BARO_QMP6988", "USE_BARO_SPI_QMP6988")
BMP085_BARO = ("USE_BARO_BMP085",)
DPS310_BARO = ("USE_BARO_DPS310", "USE_BARO_SPI_DPS310", "USE_BARO_SPA06_003")
W25N_FLASH = ("USE_FLASH_W25N01G", "USE_FLASH_W25N02K")
# The sensors the MPU6500 driver detects: a board naming one builds that driver.
MPU6500_GYRO = ("USE_GYRO_SPI_MPU6500", "USE_GYRO_SPI_ICM20601", "USE_GYRO_SPI_ICM20602", "USE_GYRO_SPI_ICM20608G")
MPU6500_ACC = ("USE_ACC_SPI_MPU6500", "USE_ACC_SPI_MPU9250", "USE_ACC_SPI_ICM20601", "USE_ACC_SPI_ICM20602",
               "USE_ACC_SPI_ICM20608G")
ICM426XX_SHARED = ("USE_ACCGYRO_ICM42622P", "USE_ACCGYRO_ICM42686P", "USE_ACCGYRO_IIM42652", "USE_ACCGYRO_IIM42653")
ICM426XX_GYRO = ("USE_GYRO_SPI_ICM42605", "USE_GYRO_SPI_ICM42688P") + ICM426XX_SHARED
ICM426XX_ACC = ("USE_ACC_SPI_ICM42605", "USE_ACC_SPI_ICM42688P") + ICM426XX_SHARED
ICM456XX = ("USE_ACCGYRO_ICM45686", "USE_ACCGYRO_ICM45605")


def find_config(configs: Path, board: str) -> Path:
    hits = sorted(configs.glob(f"*/{board}/config.h"))
    if len(hits) != 1:
        raise SystemExit(f"{len(hits)} configuration files for {board} under {configs}")
    return hits[0]


def condition(expr: str, defines: dict) -> bool:
    """An #if or #elif expression's truth, with names defined above it: defined tests, integer values, the
    logical and comparison operators."""
    expr = re.sub(r"defined\s*\(\s*(\w+)\s*\)|defined\s+(\w+)",
                  lambda m: " 1 " if (m.group(1) or m.group(2)) in defines else " 0 ", expr)
    expr = re.sub(r"\b[A-Za-z_]\w*\b",
                  lambda m: " " + (defines[m.group(0)] if re.fullmatch(r"\d+", defines.get(m.group(0), "")) else "0")
                  + " ", expr)
    expr = re.sub(r"\b(\d+)[UuLl]+\b", r"\1", expr)
    expr = expr.replace("&&", " and ").replace("||", " or ")
    expr = re.sub(r"!(?!=)", " not ", expr)
    if not re.fullmatch(r"(?:[\d\s()<>=!+\-*%]|\band\b|\bor\b|\bnot\b)*", expr):
        raise SystemExit(f"boardgen: a condition this generator does not read: {expr}")
    return bool(eval(expr, {"__builtins__": {}}, {}))


def config_defines(text: str) -> dict:
    """A board configuration file's object-like defines and their values, read as the C preprocessor reads the file
    alone: continued lines joined, comments dropped, conditional blocks decided and undefined names removed."""
    text = re.sub(r"\\\n", "", text)
    text = re.sub(r"/\*.*?\*/|//[^\n]*", " ", text, flags=re.S)
    defines = {}
    # Each open conditional block: whether its current branch is read, and whether a branch of it was taken.
    blocks = []
    for line in text.split("\n"):
        m = re.match(r"[ \t]*#[ \t]*(\w+)[ \t]*(.*?)[ \t]*$", line)
        if not m:
            continue
        word, rest = m.groups()
        live = all(read for read, _ in blocks)
        if word in ("if", "ifdef", "ifndef"):
            if not live:
                blocks.append((False, True))
                continue
            name = rest.split()[0] if rest.split() else ""
            read = (name in defines if word == "ifdef" else name not in defines if word == "ifndef"
                    else condition(rest, defines))
            blocks.append((read, read))
        elif word in ("elif", "else") and blocks:
            _, taken = blocks.pop()
            outer = all(read for read, _ in blocks)
            read = outer and not taken and (word == "else" or condition(rest, defines))
            blocks.append((read, taken or read))
        elif word == "endif" and blocks:
            blocks.pop()
        elif not live:
            continue
        elif word == "define":
            d = re.match(r"(\w+)(?:[ \t]+(.*))?$", rest)
            if d:
                defines[d.group(1)] = re.sub(r"\s+", " ", d.group(2) or "").strip()
        elif word == "undef" and rest.split():
            defines.pop(rest.split()[0], None)
    return defines


def timer_entries(defines: dict) -> list:
    """The timer map's entries in order: timer index, pin or the define naming it, occurrence and DMA option."""
    return [(int(t.group(1)), t.group(2), int(t.group(3)), int(t.group(4)))
            for t in re.finditer(r"TIMER_PIN_MAP\(\s*(\d+)\s*,\s*(\w+)\s*,\s*(\d+)\s*,\s*(-?\d+)\s*\)",
                                 defines.get("TIMER_PIN_MAPPING", ""))]


def mpu6500_drivers(defines: dict) -> tuple:
    """Whether a board builds the SPI MPU6500 gyro driver, and the accelerometer one."""
    return any(d in defines for d in MPU6500_GYRO), any(d in defines for d in MPU6500_ACC)


def generate(config: Path, overrides: dict) -> str:
    text = config.read_text()
    defines = config_defines(text)
    defines.update(overrides)
    fixed = [f"UART{n}_{d}_PIN" for n in range(1, 7) for d in ("TX", "RX")] \
        + [f"SPI{n}_{d}_PIN" for n in range(1, 7) for d in ("SCK", "SDI", "SDO")] \
        + [f"I2C{n}_{d}_PIN" for n in range(1, 5) for d in ("SCL", "SDA")] \
        + ["LED0_PIN", "GYRO_1_CS_PIN", "GYRO_1_EXTI_PIN", "GYRO_2_CS_PIN", "GYRO_2_EXTI_PIN", "FLASH_CS_PIN",
           "SDCARD_SPI_CS_PIN", "SDCARD_DETECT_PIN"]
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
    # An entry names its pin or the define of one, such as MOTOR1_PIN.
    timer_map = [(index, pin_literal(defines.get(pin, pin)), occurrence, dma)
                 for index, pin, occurrence, dma in timer_entries(defines)]
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
    out.append("   --  the gyro's and their SPI buses from 1, each gyro's select, interrupt and clock pins, whether a gyro")
    out.append("   --  driver takes an SPI bus, each gyro's alignment code and custom angles in decidegrees, the gyros the")
    out.append("   --  board names, two at most, and the mask of those it enables by default,")
    out.append("   --  the barometer's I2C or SPI bus and chip, whether the detect pin reads low")
    out.append("   --  for a card, the flight log device, the meter defaults, the PINIO")
    out.append("   --  outputs' pins, configurations and boxes by permanent id, and the")
    out.append("   --  motors', the LED strip's, the camera control and the ESC serial pins,")
    out.append("   --  the ADC devices' DMA options, the SPI receiver's pins, bus, protocol,")
    out.append("   --  radio pins and ExpressLRS timer, and the default receiver feature,")
    out.append("   --  the host defaults where the board names none.")
    ALIGNMENTS = {"ALIGN_DEFAULT": 0, "CW0_DEG": 1, "CW90_DEG": 2, "CW180_DEG": 3, "CW270_DEG": 4, "CW0_DEG_FLIP": 5,
                  "CW90_DEG_FLIP": 6, "CW180_DEG_FLIP": 7, "CW270_DEG_FLIP": 8}
    tags = [("Beeper_Tag", "BEEPER_PIN"), ("ADC_VBAT_Tag", "ADC_VBAT_PIN"), ("ADC_CURR_Tag", "ADC_CURR_PIN"),
            ("ADC_RSSI_Tag", "ADC_RSSI_PIN"), ("ADC_External1_Tag", "ADC_EXTERNAL1_PIN"),
            ("MAX7456_CS_Tag", "MAX7456_SPI_CS_PIN"), ("SDCARD_CS_Tag", "SDCARD_SPI_CS_PIN"),
            ("SDCARD_Detect_Tag", "SDCARD_DETECT_PIN"), ("FLASH_CS_Tag", "FLASH_CS_PIN"),
            ("USB_Detect_Tag", "USB_DETECT_PIN"), ("Baro_CS_Tag", "BARO_CS_PIN"), ("Baro_EOC_Tag", "BARO_EOC_PIN"),
            ("Baro_XCLR_Tag", "BARO_XCLR_PIN"), ("Mag_CS_Tag", "MAG_CS_PIN"), ("Mag_EXTI_Tag", "MAG_INT_EXTI"),
            ("Gyro_Clkin_Tag", "GYRO_1_CLKIN_PIN"), ("Gyro_1_CS_Tag", "GYRO_1_CS_PIN"),
            ("Gyro_1_EXTI_Tag", "GYRO_1_EXTI_PIN"), ("Gyro_2_Clkin_Tag", "GYRO_2_CLKIN_PIN"),
            ("Gyro_2_CS_Tag", "GYRO_2_CS_PIN"), ("Gyro_2_EXTI_Tag", "GYRO_2_EXTI_PIN")] \
        + [(f"Inverter_UART{i}_Tag", f"INVERTER_PIN_UART{i}") for i in range(1, 7)] \
        + [(f"PINIO{i}_Tag", f"PINIO{i}_PIN") for i in range(1, 5)] \
        + [(f"MOTOR{i}_Tag", f"MOTOR{i}_PIN") for i in range(1, 9)] \
        + [("PPM_Tag", "RX_PPM_PIN")] + [(f"PWM{i}_Tag", f"RX_PWM{i}_PIN") for i in range(1, 5)] \
        + [("LED_Strip_Tag", "LED_STRIP_PIN"), ("Camera_Control_Tag", "CAMERA_CONTROL_PIN"),
           ("ESC_Serial_Tag", "ESCSERIAL_PIN"), ("RX_SPI_CS_Tag", "RX_SPI_CS_PIN"),
           ("RX_SPI_EXTI_Tag", "RX_SPI_EXTI_PIN"), ("RX_SPI_Bind_Tag", "RX_SPI_BIND_PIN"),
           ("RX_SPI_LED_Tag", "RX_SPI_LED_PIN"), ("VTX_CS_Tag", "RTC6705_CS_PIN"),
           ("VTX_Power_Tag", "RTC6705_POWER_PIN"), ("VTX_Clock_Tag", "RTC6705_SPICLK_PIN"),
           ("VTX_Data_Tag", "RTC6705_SPI_SDO_PIN"), ("LED0_Tag", "LED0_PIN"), ("LED1_Tag", "LED1_PIN"),
           ("LED2_Tag", "LED2_PIN")]
    tags = [(name, defines.get(define, "")) for name, define in tags] \
        + [(name, either(defines, *alternatives)) for name, alternatives in
           (("ELRS_Reset_Tag", ("RX_EXPRESSLRS_SPI_RESET_PIN", "RX_SPI_EXPRESSLRS_RESET_PIN")),
            ("ELRS_Busy_Tag", ("RX_EXPRESSLRS_SPI_BUSY_PIN", "RX_SPI_EXPRESSLRS_BUSY_PIN")),
            ("CC2500_TX_En_Tag", ("RX_CC2500_SPI_TX_EN_PIN", "RX_SPI_CC2500_TX_EN_PIN")),
            ("CC2500_LNA_En_Tag", ("RX_CC2500_SPI_LNA_EN_PIN", "RX_SPI_CC2500_LNA_EN_PIN")),
            ("CC2500_Ant_Sel_Tag", ("RX_CC2500_SPI_ANT_SEL_PIN", "RX_SPI_CC2500_ANT_SEL_PIN")))]
    defaults = [("Default_Voltage_Meter_Source", VOLTAGE_SOURCES[defines.get("DEFAULT_VOLTAGE_METER_SOURCE",
                                                                             "VOLTAGE_METER_NONE")]),
                ("Default_Current_Meter_Source", CURRENT_SOURCES[defines.get("DEFAULT_CURRENT_METER_SOURCE",
                                                                             "CURRENT_METER_VIRTUAL")]),
                ("Default_Voltage_Meter_Scale", number(defines.get("DEFAULT_VOLTAGE_METER_SCALE"), 110)),
                ("Default_Current_Meter_Scale", number(defines.get("DEFAULT_CURRENT_METER_SCALE"), 400)),
                ("Gyro_1_SPI_Device", spi_device(defines.get("GYRO_1_SPI_INSTANCE", ""))),
                ("Gyro_SPI", "True" if any(d in defines for d in SPI_GYROS) else "False"),
                ("Gyro_1_Align", gyro_alignment(defines, 1)[0]),
                ("Gyro_1_Align_Roll", gyro_alignment(defines, 1)[1][0]),
                ("Gyro_1_Align_Pitch", gyro_alignment(defines, 1)[1][1]),
                ("Gyro_1_Align_Yaw", gyro_alignment(defines, 1)[1][2]),
                ("Gyro_Count", gyro_count(defines)),
                ("Default_Gyros_Enabled", default_gyros_enabled(defines)),
                ("Gyro_2_SPI_Device", spi_device(defines.get("GYRO_2_SPI_INSTANCE", ""))),
                ("Gyro_2_Align", gyro_alignment(defines, 2)[0]),
                ("Gyro_2_Align_Roll", gyro_alignment(defines, 2)[1][0]),
                ("Gyro_2_Align_Pitch", gyro_alignment(defines, 2)[1][1]),
                ("Gyro_2_Align_Yaw", gyro_alignment(defines, 2)[1][2]),
                ("Gyro_MPU6000", "True" if "USE_GYRO_SPI_MPU6000" in defines else "False"),
                ("Gyro_MPU6500", str(mpu6500_drivers(defines)[0])),
                ("Acc_MPU6000", "True" if "USE_ACC_SPI_MPU6000" in defines else "False"),
                ("Acc_MPU6500", str(mpu6500_drivers(defines)[1])),
                ("Gyro_MPU9250", "True" if "USE_GYRO_SPI_MPU9250" in defines else "False"),
                ("Acc_MPU9250", "True" if "USE_ACC_SPI_MPU9250" in defines else "False"),
                ("Gyro_LSM6DSV16X", "True" if "USE_ACCGYRO_LSM6DSV16X" in defines else "False"),
                ("Gyro_LSM6DSV32X", "True" if "USE_ACCGYRO_LSM6DSV32X" in defines else "False"),
                ("Gyro_LSM6DSK320X", "True" if "USE_ACCGYRO_LSM6DSK320X" in defines else "False"),
                ("Gyro_ICM20689", "True" if "USE_GYRO_SPI_ICM20689" in defines else "False"),
                ("Acc_ICM20689", "True" if "USE_ACC_SPI_ICM20689" in defines else "False"),
                ("Gyro_BMI270", "True" if "USE_ACCGYRO_BMI270" in defines else "False"),
                ("Acc_BMI270", "True" if "USE_ACCGYRO_BMI270" in defines else "False"),
                ("Gyro_ICM426xx", "True" if any(d in defines for d in ICM426XX_GYRO) else "False"),
                ("Acc_ICM426xx", "True" if any(d in defines for d in ICM426XX_ACC) else "False"),
                ("Gyro_ICM456xx", "True" if any(d in defines for d in ICM456XX) else "False"),
                ("Gyro_LSM6DSO", "True" if "USE_ACCGYRO_LSM6DSO" in defines else "False"),
                ("Acc_LSM6DSO", "True" if "USE_ACCGYRO_LSM6DSO" in defines else "False"),
                ("Acc_ICM456xx", "True" if any(d in defines for d in ICM456XX) else "False"),
                ("Baro_I2C_Device", i2c_device(defines.get("BARO_I2C_INSTANCE", ""))),
                ("Baro_SPI_Device", spi_device(defines.get("BARO_SPI_INSTANCE", ""))),
                ("Baro_BMP280", "True" if any(d in defines for d in BMP280_BARO) else "False"),
                ("Baro_DPS310", "True" if any(d in defines for d in DPS310_BARO) else "False"),
                ("Baro_MS5611", "True" if any(d in defines for d in MS5611_BARO) else "False"),
                ("Baro_BMP388", "True" if any(d in defines for d in BMP388_BARO) else "False"),
                ("Baro_LPS22DF", "True" if any(d in defines for d in LPS22DF_BARO) else "False"),
                ("Baro_QMP6988", "True" if any(d in defines for d in QMP6988_BARO) else "False"),
                ("Baro_BMP085", "True" if any(d in defines for d in BMP085_BARO) else "False"),
                ("Baro_SPA06", "True" if "USE_BARO_SPA06_003" in defines else "False"),
                ("Flash_W25N", "True" if any(d in defines for d in W25N_FLASH) else "False"),
                ("Gyro_Clkin", "True" if "USE_GYRO_CLKIN" in defines else "False"),
                ("Mag_I2C_Device", i2c_device(defines.get("MAG_I2C_INSTANCE", ""))),
                ("Mag_SPI_Device", spi_device(defines.get("MAG_SPI_INSTANCE", ""))),
                ("Mag_Align", ALIGNMENTS.get(defines.get("MAG_ALIGN", "ALIGN_DEFAULT"), 0)),
                ("MAX7456_SPI_Device", spi_device(defines.get("MAX7456_SPI_INSTANCE", ""))),
                ("VTX_SPI_Device", spi_device(defines.get("RTC6705_SPI_INSTANCE", ""))),
                ("LED_Inversion", sum(1 << n for n in range(3) if f"LED{n}_INVERTED" in defines)),
                ("SDCARD_SPI_Device", spi_device(defines.get("SDCARD_SPI_INSTANCE", ""))),
                ("SDCARD_Mode", sdcard_mode(defines)),
                ("FLASH_SPI_Device", spi_device(defines.get("FLASH_SPI_INSTANCE", ""))),
                ("SDCARD_Detect_Low", "True" if "SDCARD_DETECT_INVERTED" in defines else "False"),
                ("Default_Blackbox_Device", BLACKBOX_DEVICES[defines.get("DEFAULT_BLACKBOX_DEVICE",
                                                                         "BLACKBOX_DEVICE_NONE")])] \
        + [(f"PINIO{i}_Config", pinio_config(defines.get(f"PINIO{i}_CONFIG"))) for i in range(1, 5)] \
        + [(f"PINIO{i}_Box", number(defines.get(f"PINIO{i}_BOX"), 255)) for i in range(1, 5)] \
        + [("MSP_UART", serial_port(defines.get("MSP_UART"))),
           ("Use_MSP_UART", serial_port(defines.get("USE_MSP_UART"))),
           ("MSP_Display_Port_UART", serial_port(defines.get("MSP_DISPLAYPORT_UART")))] \
        + [(f"ADC{i}_DMA_Option", number(defines.get(f"ADC{i}_DMA_OPT"), -1)) for i in range(1, 4)] \
        + [("RX_SPI_Device", spi_device(defines.get("RX_SPI_INSTANCE", ""))),
           ("RX_SPI_Default_Protocol", rx_spi_protocol(defines.get("RX_SPI_DEFAULT_PROTOCOL"))),
           ("RX_SPI_LED_Inverted", "True" if "RX_SPI_LED_INVERTED" in defines else "False"),
           ("CC2500_Chip_Detection", "False" if "RX_CC2500_SPI_DISABLE_CHIP_DETECTION" in defines else "True"),
           ("ELRS_Timer", timer_number(defines.get("RX_EXPRESSLRS_TIMER_INSTANCE"))),
           ("Default_RX_Feature", rx_feature(defines.get("DEFAULT_RX_FEATURE")))]
    column = max(len(n) for n, _ in tags + defaults)
    for name, define in tags:
        out.append(f"   {name.ljust(column)} : constant := {pin_tag(define)};")
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
