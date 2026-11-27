# Roadmap

Mission: a flight controller in SPARK and Ada at feature and performance parity with
[Betaflight](https://github.com/betaflight/betaflight), proved where proof buys assurance
that tests cannot. Every phase serves that sentence.

A phase is complete when its modules replay the recorded vectors bit for bit, prove at
Silver with no assume, and pass the gates on `main`.

## Phases

- Phase 0, complete 2026-10-08. Foundation. Core crate, bounded maths and filters, vector checker,
  gates, CI, design ledger.
- Phase 1, complete 2026-11-23. Control core. PID controller, rate profiles and stick curves, RC
  smoothing, mixer and motor output limits, arming logic, failsafe, runtime modes.
- Phase 2, complete 2026-11-24. Sensor pipeline. Gyro filtering chain, dynamic notch, RPM filter,
  accelerometer calibration, attitude estimation, board alignment, barometer, compass, rangefinders,
  optical flow, pitot, battery and current sensing, each with its task. Position estimate fuses
  barometer, rangefinder, optical flow, accelerometer and GPS.
- Phase 3, complete 2026-11-19. Scheduler and task set. Cooperative scheduler, Betaflight's task table
  numbered by what a build contains, main loop, initialization order.
- Phase 4, complete 2026-11-18. Receivers. Serial and SPI receivers, channel mapping, link statistics,
  bind. The KN receiver stays out, as no Betaflight build compiles it.
- Phase 5, complete 2026-11-23. Configuration and ground link. Parameter groups, settings table,
  command line, MSP with the messages Betaflight Configurator reads and writes. A build without a feature
  lists the settings, commands, pins and MSP replies of Betaflight's build without it.
- Phase 6, complete 2026-11-24. Flight features. Blackbox, OSD, menu system, telemetry protocols, LED
  strip, beeper, VTX control, GPS with rescue and position modes, flight plans, servos and wing support.
  `docs/building.md` lists what each board size leaves out.
- Phase 7, in progress. Targets. `targets/stm32f4` builds STM32F405, STM32F411 and STM32F446 images,
  `targets/stm32f7` STM32F7 images. `targets/stm32h7` builds an STM32H743 image with UARTs, external
  interrupts, timers, DMA, SPI, I2C, USB and configuration store. `targets/host` runs flight software on host, with UARTs
  and USB on TCP ports and a simulator link. Drivers cover SPI, I2C, DMA, timers, USB, flash, SD card, ADC
  on DMA, and DShot on timers and bit-banged on GPIO ports. 512 KB boards pack initialized data and start-up code.
  Left: H7 flight software, other families Betaflight runs on, and USB mass storage, which no board has run yet.
- Phase 8, in progress. Tooling. adaflight-configurator, the upstream configurator with adaflight's
  changes, builds and flashes from an adaflight checkout and shows a fit view for boards short of flash.
  `tools/dfu` flashes over DFU on Linux, and `tools/msp` sends MSP requests and backs up a configuration.
  MSP reads and writes were checked against a host image and Betaflight's own host build. Closed-loop
  flights through the simulator link match that build within 0.002 in motor output, apart from recorded
  divergences, and its SITL scenario harness passes on host. Left: a pass through each configurator tab on a board.

## After parity

Parity comes first. Then the size and speed of the port get measured on the STM32F4, F7
and H7 boards against Betaflight's images for the same feature set. A proved core runs
with its run-time checks off at no loss of safety, so its generated code starts at the
size and speed of the C. It seems plausible that the port ends up smaller on the F4
boards. Whatever room that opens goes to features the F4 builds have to leave out today,
with more room on F7 and H7. The measurement decides.

## Coverage

Each Betaflight source area at commit af0638839, the commit the vectors were recorded from. Ported means proved and checked against the recorded vectors.

- **common** (maths, filters, vectors, DFT, tables, encodings, buffers, codecs): ported
- **flight** (pid, mixer, imu, failsafe, rescue, nav): ported
- **fc** (core loop, rc, modes, adjustments, tasks): ported
- **sensors**: ported
- **scheduler**: ported
- **rx**: ported, apart from the KN receiver, which no build compiles
- **pg, config, cli, msp**: ported
- **blackbox, osd, cms, telemetry, io**: ported
- **drivers, target, build, msc**: sensor, radio, OSD chip, display, flash and SD card drivers, the DShot protocol and its command queue, and USB mass storage ported. Bus, timer, DMA, UART and USB drivers are written for STM32F4 and F7 in Phase 7
- **platform** (STM32, AT32, APM32, PICO, ESP32, SITL): STM32F4, STM32F7 and the host target in Phase 7, STM32H7 started. AT32, APM32, PICO and ESP32 not started
