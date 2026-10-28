# adaflight

[![SPARK Proofs](https://github.com/Jbsco/adaflight/actions/workflows/prove.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/prove.yml)
[![Vector Checks](https://github.com/Jbsco/adaflight/actions/workflows/test.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/test.yml)
[![Style](https://github.com/Jbsco/adaflight/actions/workflows/style.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/style.yml)

adaflight is flight control firmware for multirotors and fixed-wing aircraft, written in Ada and SPARK as a port of [Betaflight](https://github.com/betaflight/betaflight). It aims at parity with Betaflight in features and flight behaviour. Its core is proved free of run-time errors with SPARK: no filter or controller can produce an infinity or a NaN whatever its input history, no decoder can index outside its buffer, and every motor command is in range by type.

## Contents

- [Status](#status)
- [Features](#features)
- [Differences from Betaflight](#differences-from-betaflight)
- [Building and testing](#building-and-testing)
- [Verification](#verification)
- [Repository layout](#repository-layout)
- [License](#license)

## Status

The flight software is ported and runs on the host, where each ported function replays inputs recorded from a host build of Betaflight and must reproduce its results bit for bit. Phase 7 of `ROADMAP.md` has started: `targets/stm32f4` builds an image for the CLRacing F4S board family that blinks the LED, serves MSP and the command line on its USB port and UART1, so a configurator connects over USB, runs the scheduler with the gyro, filter, accelerometer, attitude and receiver tasks over the MPU6000 on SPI1 and a CRSF receiver on a UART with its telemetry, the arming logic and the modes, runs the rate controller and the mixer with the motors in DShot from the timers and their DShot commands, measures the battery, drives the beeper, draws the OSD and runs the menu system on the MAX7456 chip on SPI3, reads a GPS module and the ESC sensor on UARTs, writes its flight log to the SD card on SPI2, the flash chip on SPI3 or a serial port, controls a SmartAudio or Tramp video transmitter on a UART, drives its PINIO output from a mode box, keeps the clock the configurator or the GPS sets, and keeps its configuration in flash. `targets/host` runs the same flight software on the host with its UARTs on TCP ports, so a configurator connects without a board.

## Features

- **Flight control**: Betaflight, Raceflight, KISS, Actual and Quick rates, RC smoothing and feedforward, PID controller with anti-gravity, I-term relax, TPA and dynamic idle, launch control, crash flip, EZ landing, in-flight adjustments, simplified tuning, failsafe
- **Filters**: gyro and D-term lowpass and notch filters, dynamic notch over a sliding DFT, RPM filter
- **Motors and servos**: multirotor and wing mixers with custom mixes, servos, 3D mode, DShot with bidirectional telemetry and commands, PWM, OneShot, MultiShot and brushed outputs
- **Attitude and navigation**: attitude estimator with compass heading, accelerometer calibration, position estimate from barometer, accelerometer and GPS, altitude hold, position hold, GPS rescue, flight plans with waypoints, NMEA and UBX GPS with u-blox configuration
- **Gyros and accelerometers**: MPU6000, MPU6500, ICM20689 family, ICM426xx, ICM456xx, ICM40609, ICM56686, LSM6DSO, LSM6DSV16X, BMI160, BMI270, BMI423
- **Barometers**: BMP085, BMP280, BMP388, BMP5xx, DPS310, MS5611, LPS, LPS22DF, QMP6988, 2SMPB-02B
- **Compasses**: HMC5883L, QMC5883, IST8310, LIS3MDL, LIS2MDL, AK8963, AK8975, AK9916, MMC560X, BMM350
- **Rangefinders, optical flow and airspeed**: TF, Nooploop, HC-SR04 and MT rangefinders, MT and UP-T1 optical flow, pitot airspeed
- **Receivers**: SBUS, CRSF, SUMD, SUMH, IBUS, Spektrum, XBUS, Jeti EX Bus, Ghost, SRXL2, FPORT, PPM, PWM, MSP and MAVLink, and SPI receivers for ExpressLRS, FrSky D8 and X, Redpine, S-FHSS, FlySky AFHDS and AFHDS 2A, Spektrum DSM2 and DSMX and NRF24L01 protocols
- **Telemetry**: CRSF, SmartPort, FrSky hub, iBus, HoTT, Ghost, SRXL, LTM, MAVLink with the mission protocol, Jeti EX Bus, MSP over telemetry
- **Configuration**: command line with Betaflight's setting names, dump and diff, MSP with the messages Betaflight Configurator uses, configuration storage image
- **OSD and menus**: MAX7456, MSP display port, FrSky OSD and OLED dashboard, OSD elements, warnings, statistics and navigation map, menus over the OSD and CRSF
- **Flight log**: blackbox to SPI flash, to an SD card over SPI or SDIO with its FAT file system, or to a serial port
- **Peripherals**: video transmitter control over SmartAudio, Tramp, MSP and RTC6705, LED strip, beeper and DShot beacon, ESC sensor, BLHeli passthrough, RunCam, gimbal, PINIO, race transponder, GPS lap timer, real-time clock, USB virtual serial port and joystick
- **Scheduler**: cooperative scheduler with Betaflight's task set

## Differences from Betaflight

adaflight keeps the operation order of Betaflight's code, so a host build of each gives the same results for the same inputs. `DIVERGENCES.md` lists every place where adaflight differs on purpose. Most of them keep a value in range where Betaflight's result is undefined, overflows or reads outside a buffer. Some fix Betaflight bugs found while porting, and [`docs/upstream/`](docs/upstream/README.md) has a write-up of each for Betaflight.

## Building and testing

[Alire](https://alire.ada.dev) provides the compiler and the prover.

    cd core && alr build                      # build the core
    cd tests && alr build && ./bin/vector_check vectors
    bash target.do                            # STM32F4 image for the CLRacing F4S family
    bash host.do                              # host image, checked over its UART1 TCP port
    bash prove.do                             # SPARK proof of the core
    bash verify.do                            # every gate, cheapest first

A change is finished when `verify.do` passes.

The STM32F4 image is flashed through the STM32 bootloader over USB with the board in DFU mode, as two files, the code from sector 2 and then the vector table at the flash's start, so the configuration stored in sector 1 stays in place. The bootloader leaves through the address of the last write, so the vector table goes last:

    cd targets/stm32f4
    alr exec -- arm-eabi-objcopy -O binary --only-section=.vectors bin/adaflight_stm32f4 vectors.bin
    alr exec -- arm-eabi-objcopy -O binary --remove-section=.vectors bin/adaflight_stm32f4 code.bin
    dfu-util -a 0 -s 0x08008000 -D code.bin
    dfu-util -a 0 -s 0x08000000:leave -D vectors.bin

The image serves the board's USB port as a virtual serial port, where a configurator connects, and answers the firmware variant `ADFL`. The stock configurator opens its command line tab alone for that variant; [adaflight-configurator](https://github.com/Jbsco/adaflight-configurator) accepts it with the full tabs.

The host image runs the board's flight software on Linux, with each UART as a TCP server on port 5760 plus its number. A configurator connects to the virtual serial port at `tcp://localhost:5780` or to UART1 at `tcp://localhost:5761`, and a receiver's frames go to its UART's port, UART3 at 5763 in `tools/host-smoke.py`. A save or a reboot ends the process, so a loop starts it again:

    cd targets/host && alr build
    while ./bin/adaflight_host; do :; done

The configuration is kept in `adaflight-eeprom.bin` in the working directory, or in the file `ADAFLIGHT_EEPROM` names. With the OSD on, its screen is written to `adaflight-osd.txt`, or to the file `ADAFLIGHT_OSD_SCREEN` names.

## Verification

- Every unit in `core/` is SPARK and proved free of run-time errors at Silver or Gold, except the bodies outside SPARK that `DESIGN.md` names: the accurate power (D15), the rescue's arctangent (D83), the configuration codec (D166) and the configuration fix's call sequence (D167). The proof gate counts such bodies on every run.
- No `pragma Assume` and no justified suppression. `prove.do` counts both on every run.
- A pull request proves the units whose sources it changed (`tools/changed-units.py`). A nightly run proves every core unit in parallel groups. Both prove a generic unit through its instantiations.
- A ported function keeps the operation order of its Betaflight original, so the host build reproduces its results bit for bit. The vector checker reports the distance in representable values for every case, and each deliberate difference has a declared tolerance and a line in `DIVERGENCES.md`.
- Vectors under `tests/vectors` were recorded from a host build of Betaflight at commit af0638839 by a tool outside this repository.

## Repository layout

| Path | Contents |
|---|---|
| `core/` | SPARK library crate `adaflight_core`: the proved, hardware-independent core |
| `tests/` | Host crate `adaflight_tests`: replays `tests/vectors` through the core |
| `targets/stm32f4/` | Alire crate `adaflight_stm32f4`: the core on STM32F4 boards with the platform drivers |
| `targets/host/` | Alire crate `adaflight_host`: the STM32F4 flight software on the host, with its UARTs on TCP |
| `tools/` | Repository tooling: changed units for CI, markdown rendering check, board package generator |
| `third_party/` | Third-party material with its license and source, and the board configuration repository as a pinned submodule |
| `docs/upstream/` | Write-ups of Betaflight bugs that adaflight fixes |
| `style.do`, `test.do`, `target.do`, `host.do`, `prove.do`, `verify.do` | The gates, runnable with `bash` or `redo` |
| `DESIGN.md` | Numbered design decisions with their reasons |
| `DIVERGENCES.md` | Every place where adaflight differs from Betaflight on purpose |
| `ROADMAP.md` | Phases and the coverage of Betaflight's source areas |

## License

GPL-3.0-or-later. See `LICENSE`.

`core/src/adaflight-bmi270_config.ads` contains Bosch Sensortec's BMI270 configuration file under BSD-3-Clause license. `third_party/bosch-bmi270` contains that license and names the source.
