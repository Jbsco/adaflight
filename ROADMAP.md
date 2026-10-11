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
  initialization order.
- Phase 4, open. Receivers. Serial protocol decoders, SPI receivers, channel mapping,
  link statistics, bind.
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

## Parity inventory

Line counts of the Betaflight modules, C sources and headers, at commit af0638839, the
commit the vectors were recorded from. The adaflight column counts Ada lines on `main`.

| Betaflight module | Betaflight lines | adaflight lines | Status |
|---|---|---|---|
| common (maths, filters, vectors, DFT, tables, encodings, buffers, codecs) | 5481 | 4587 | maths with exp and log, filters, vectors, sliding DFT, piecewise-linear tables, integrity codes, encodings, bit arrays, stream buffers, Huffman encoder, GPS coordinates, sensor alignment, color conversion, the chirp generator, and the wrapping clock difference proved and vector-checked; type conversion and the string helpers open |
| flight (pid, mixer, imu, failsafe, rescue, nav) | 17554 | 4298 | PID profile, runtime configuration, filter initialization, the rate loop, the throttle-side features, the crash recovery, the launch control, the motor mixer, the attitude estimator with the compass heading, the failsafe state machine, the angle and horizon level modes, the dynamic notch filter, the RPM filter, the position Kalman filter, the altitude estimator from the barometer and the accelerometer, and the altitude hold with the autopilot's altitude controller proved and vector-checked; the horizontal position estimate, position hold, rescue, and navigation open |
| fc (core loop, rc, modes, adjustments, tasks) | 8228 | 1880 | rate curves, the RC command path (deadbands, throttle curve, setpoints, feedforward, smoothing), the runtime modes, and the arming logic (flags and disable reasons, throttle status, stick arming and commands, automatic disarm, flight mode selection) proved and vector-checked; the rest of the core loop, adjustments, and tasks open |
| sensors | 8893 | 1817 | gyro calibration, filtering chain, and overflow and yaw spin detection, the dynamic and RPM notches, the accelerometer path, the barometer altitude, the compass with its bias calibration, the battery meters and states, and the sensor and board alignment proved and vector-checked |
| scheduler | 1144 | 0 | Phase 3 |
| rx | 16964 | 0 | Phase 4 |
| pg, config, cli, msp | 21377 | 0 | Phase 5 |
| blackbox, osd, cms, telemetry, io | 59977 | 0 | Phase 6 |
| drivers, target, build, msc | 55927 | 0 | Phase 7 |
| platform (STM32, AT32, APM32, PICO, ESP32, SITL) | not counted | 0 | Phase 7 |
| total measured | 195545 | 12597 | |
