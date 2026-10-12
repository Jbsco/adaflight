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
  compass, battery and current sensing. The sensor task set remains.
- Phase 3, open. Scheduler and task set. Cooperative scheduler, task table, the main loop,
  initialization order. The scheduler and the task table are in.
- Phase 4, open. Receivers. Serial protocol decoders, SPI receivers, channel mapping,
  link statistics, bind. The channel processing and the link statistics are in.
- Phase 5, open. Configuration and ground link. Parameter groups, settings table, the CLI,
  the MSP protocol so the existing configurator connects.
- Phase 6, open. Flight features. Blackbox, OSD, menu system, telemetry protocols, LED
  strip, beeper, VTX control, GPS with rescue and position modes, servos and wing
  support.
- Phase 7, open. Targets. STM32F4 first, then F7 and H7, then the other families Betaflight
  runs on, plus a host simulator target. Drivers for SPI, I2C, DMA, timers, UART, USB,
  flash, SD card, DShot.
- Phase 8, open. Tooling. A native Linux flashing tool over DFU with the features of the
  Betaflight flasher and faster transfers, then the configuration path.

## After parity

Parity comes first. Then the size and speed of the port get measured on the STM32F4, F7
and H7 boards against Betaflight's images for the same feature set. A proved core runs
with its run-time checks off at no loss of safety, so its generated code starts at the
size and speed of the C, and it seems plausible that the port ends up smaller on the F4
boards. Whatever room that opens goes to features the F4 builds have to leave out today,
with more room on F7 and H7. The measurement decides.

## Parity inventory

Line counts of the Betaflight modules, C sources and headers, at commit af0638839, the
commit the vectors were recorded from. The adaflight column counts Ada lines on `main`.

| Betaflight module | Betaflight lines | adaflight lines | Status |
|---|---|---|---|
| common (maths, filters, vectors, DFT, tables, encodings, buffers, codecs) | 5481 | 5075 | maths with exp and log, filters, vectors, sliding DFT, piecewise-linear tables, integrity codes, encodings, bit arrays, stream buffers, Huffman encoder, GPS coordinates, sensor alignment, color conversion, the chirp generator, the wrapping clock difference, and the text conversions proved and vector-checked |
| flight (pid, mixer, imu, failsafe, rescue, nav) | 17554 | 4311 | PID profile, runtime configuration, filter initialization, the rate loop, the throttle-side features, the crash recovery, the launch control, the motor mixer, the attitude estimator with the compass heading, the failsafe state machine, the angle and horizon level modes, the dynamic notch filter, the RPM filter, the position Kalman filter, the altitude estimator from the barometer and the accelerometer, and the altitude hold with the autopilot's altitude controller proved and vector-checked; the horizontal position estimate, position hold, rescue, and navigation open |
| fc (core loop, rc, modes, adjustments, tasks) | 8228 | 2795 | rate curves, the RC command path (deadbands, throttle curve, setpoints, feedforward, smoothing), the runtime modes, the arming logic (flags and disable reasons, throttle status, stick arming and commands, automatic disarm, flight mode selection, launch control activation, runaway takeoff prevention), and the in-flight adjustments (steps, dials, selections, display, beeps) proved and vector-checked; the rest of the core loop and the tasks open |
| sensors | 8893 | 2085 | gyro calibration, filtering chain, and overflow and yaw spin detection, the dynamic and RPM notches, the accelerometer path, the barometer altitude, the compass with its bias calibration, the battery meters and states, the sensor and board alignment, and the ESC telemetry over the serial line proved and vector-checked |
| scheduler | 1144 | 890 | the cooperative scheduler (task table, queue, gyro lock, dynamic priorities, check functions, fit and guard margins, statistics) proved and vector-checked; the main loop and the initialization order open |
| rx | 16964 | 4722 | the receiver core (channel map and ranges, pulse validity, signal loss behaviour, failsafe channel settings, pulse receiver averaging, link quality, RSSI sources and smoothing) and the SBUS, CRSF, SUMD, SUMH, IBUS, Spektrum, XBUS, Jeti EX Bus, Ghost, SRXL2 and FPORT protocols and the MSP receiver proved and vector-checked; the other protocol decoders, the SPI receivers, and bind open | | the receiver core (channel map and ranges, pulse validity, signal loss behaviour, failsafe channel settings, pulse receiver averaging, link quality, RSSI sources and smoothing) and the MAVLink receiver proved and vector-checked; the protocol decoders, the SPI receivers, and bind open | | rx | 16964 | 400 | the ExpressLRS hopping tables, link quality counter, packet CRC, and conversions proved and vector-checked; the receiver core, the protocol decoders, the SPI receivers, and bind open | | rx | 16964 | 305 | the ExpressLRS telemetry link (the stubborn sender and the MSP receiver) proved and vector-checked; the receiver core, the protocol decoders, the SPI receivers, and bind open |
| pg, config, cli, msp | 21377 | 79 | simplified tuning of the PID gains proved and vector-checked; the rest Phase 5 | | pg, config, cli, msp | 21377 | 455 | the MSP serial port (the frame decoder for the three framings, the requests between frames, the reply encoder) proved and vector-checked; the parameter groups, the command set, and the command line open |
| blackbox, osd, cms, telemetry, io | 59977 | 3681 | the beeper (sound table, sequences, multi-beep fills, bench suppression, DShot beacon) proved and vector-checked; the rest Phase 6 | | the flight log field encodings proved and vector-checked; the rest Phase 6 | | the CRSF telemetry frames with their schedule and speed negotiation proved and vector-checked | | the SmartPort telemetry stream proved and vector-checked; the rest Phase 6 | | the RunCam device protocol proved and vector-checked; the rest Phase 6 | | the FrSky hub telemetry stream proved and vector-checked; the rest Phase 6 |
| drivers, target, build, msc | 55927 | 0 | Phase 7 | | drivers, target, build, msc | 55927 | 691 | the DShot frame, command conversions, output endpoints, reply decoder, telemetry state, and quality counters proved and vector-checked |
| platform (STM32, AT32, APM32, PICO, ESP32, SITL) | not counted | 0 | Phase 7 |
| total measured | 195545 | 25134 | |
