# Roadmap

Mission: a flight controller in SPARK and Ada at feature and performance parity with
[Betaflight](https://github.com/betaflight/betaflight), proved where proof buys assurance
that tests cannot. Every phase serves that sentence.

A phase is complete when its modules replay the recorded vectors bit for bit, prove at
Silver with no assume, and pass the gates on `main`.

## Phases

- Phase 0, complete 2026-10-08. Foundation. Core crate, bounded maths and filters, vector checker,
  gates, CI, design ledger.
- Phase 1, open. Control core. PID controller, rate profiles and stick curves, RC
  smoothing, mixer and motor output limits, arming logic, failsafe, runtime modes.
- Phase 2, open. Sensor pipeline. Gyro filtering chain, dynamic notch, RPM filter,
  accelerometer calibration, attitude estimation, board alignment, barometer,
  compass, battery and current sensing. The sensor task set remains, apart from the
  barometer and compass read cycles.
- Phase 3, open. Scheduler and task set. Cooperative scheduler, task table, the main loop,
  initialization order. The scheduler and the task table are in.
- Phase 4, open. Receivers. Serial protocol decoders, SPI receivers, channel mapping,
  link statistics, bind. The channel processing and the link statistics are in.
- Phase 5, open. Configuration and ground link. Parameter groups, settings table, the CLI,
  the MSP protocol so the existing configurator connects.
- Phase 6, open. Flight features. Blackbox, OSD, menu system, telemetry protocols, LED
  strip, beeper, VTX control, GPS with rescue and position modes, servos and wing
  support.
- Phase 7, in progress. Targets. STM32F4 first: `targets/stm32f4` builds for the CLRacing F4S board
  family from the pinned board configuration repository, and its image blinks the LED, serves MSP and
  the command line on its USB port and UART1, runs the scheduler with the gyro, filter, accelerometer,
  attitude and receiver tasks over SPI1 and a CRSF or Ghost receiver with its telemetry and MSP over
  CRSF, or an SBUS, IBUS, SUMD, Spektrum, XBUS, FPORT or Jeti EX Bus receiver on a UART, the arming
  logic and the modes, runs the rate controller and the mixer with the motors in DShot from the timers
  and their DShot commands, measures the battery, drives the beeper, draws the OSD and runs the menu
  system on the MAX7456 chip on SPI3, reads a GPS module and the ESC sensor on UARTs, estimates its
  altitude and position from the accelerometer and the GPS with its heading from the GPS course, holds
  them in the altitude and position hold modes, flies the GPS rescue home, writes its flight log to
  the SD card, the flash chip or a serial port, controls a SmartAudio or Tramp video transmitter on a
  UART, sends FrSky hub, SmartPort, LTM, MAVLink and iBus telemetry on a UART, drives its PINIO output
  from a mode box, keeps the clock the configurator or the GPS sets, and keeps its configuration in
  flash. `targets/host` runs the same flight software on the host with its UARTs and USB port on TCP
  ports. Then F7 and H7, then the other families Betaflight runs on, and a physics simulator link for
  the host target. Drivers for SPI, I2C, DMA, timers, USB, flash, SD card, DShot.
- Phase 8, open. Tooling. The configurator as the adaflight-configurator repository, the upstream
  configurator with adaflight's changes, starting with the firmware variant. A native Linux flashing
  tool over DFU with the features of the Betaflight flasher and faster transfers, then the
  configuration path.

## After parity

Parity comes first. Then the size and speed of the port get measured on the STM32F4, F7
and H7 boards against Betaflight's images for the same feature set. A proved core runs
with its run-time checks off at no loss of safety, so its generated code starts at the
size and speed of the C, and it seems plausible that the port ends up smaller on the F4
boards. Whatever room that opens goes to features the F4 builds have to leave out today,
with more room on F7 and H7. The measurement decides.

## Coverage

Each Betaflight source area at commit af0638839, the commit the vectors were recorded from. Ported means proved and checked against the recorded vectors.

- **common** (maths, filters, vectors, DFT, tables, encodings, buffers, codecs): ported
- **flight** (pid, mixer, imu, failsafe, rescue, nav): ported
- **fc** (core loop, rc, modes, adjustments, tasks): ported
- **sensors**: ported
- **scheduler**: ported, apart from the main loop and the initialization order
- **rx**: ported, apart from the KN receiver, which no build compiles
- **pg, config, cli, msp**: ported, apart from the parameter groups and the remaining commands
- **blackbox, osd, cms, telemetry, io**: ported, with the remaining parts in Phase 6
- **drivers, target, build, msc**: sensor, radio, OSD chip, display, flash and SD card drivers and the DShot protocol and its command queue ported, with the bus, timer, DMA, UART and USB drivers in Phase 7
- **platform** (STM32, AT32, APM32, PICO, ESP32, SITL): Phase 7
