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
  barometer read cycle.
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
| common (maths, filters, vectors, DFT, tables, encodings, buffers, codecs) | 5481 | 5562 | maths with exp and log, filters, vectors, sliding DFT, piecewise-linear tables, integrity codes, encodings, bit arrays, stream buffers, Huffman encoder, GPS coordinates, sensor alignment, color conversion, chirp generator, wrapping clock difference, text conversions, real-time clock calendar proved and vector-checked |
| flight (pid, mixer, imu, failsafe, rescue, nav) | 17554 | 12016 | PID profile, runtime configuration, filter initialization, rate loop, throttle-side features, crash recovery, launch control, motor mixer with mixer setup (frame tables, custom mixes, launch control mix), attitude estimator with the compass heading, failsafe state machine, angle and horizon level modes, dynamic notch filter, RPM filter, position Kalman filter, position estimator from the barometer, the accelerometer and the GPS, altitude hold with the autopilot's altitude controller, wing launch, navigation trail, position hold with the autopilot's horizontal and yaw control and its navigation modes, GPS rescue, position navigation target, flight plan storage with waypoint capture, executor's plan queries, leg geometry, carrot legs, dispatch, landing, update cycle and rescue plan proved and vector-checked |
| fc (core loop, rc, modes, adjustments, tasks) | 8228 | 3739 | rate curves, RC command path (deadbands, throttle curve, setpoints, feedforward, smoothing), runtime modes with ground station overrides, arming logic (flags and disable reasons, throttle status, stick arming and commands, automatic disarm, flight mode selection, launch control activation, runaway takeoff prevention), in-flight adjustments (steps, dials, selections, display, beeps), flight statistics, GPS lap timer, dispatch queue, receiver task state machine, task setup (boot enables and periods) proved and vector-checked; the rest of the core loop and the task functions open |
| sensors | 8893 | 3233 | gyro calibration, filtering chain, overflow and yaw spin detection, dynamic and RPM notches, accelerometer path, barometer altitude and read cycle, compass with its bias calibration, battery meters (analog, ESC sensor, virtual, MSP) and states, sensor and board alignment, ESC telemetry over the serial line, rangefinder readings, optical flow readings, pitot airspeed, internal ADC channels proved and vector-checked |
| scheduler | 1144 | 903 | cooperative scheduler (task table, queue, gyro lock, dynamic priorities, check functions, fit and guard margins, statistics) proved and vector-checked; main loop and initialization order open |
| rx | 16964 | 11568 | receiver core (channel map and ranges, pulse validity, signal loss behaviour, failsafe channel settings, pulse receiver averaging, link quality, RSSI sources and smoothing, MSP override), SBUS, CRSF, SUMD, SUMH, IBUS, Spektrum, XBUS, Jeti EX Bus, Ghost, SRXL2 and FPORT protocols, MSP receiver, MAVLink receiver, ExpressLRS hopping tables, link quality counter, packet CRC and conversions, ExpressLRS telemetry link (stubborn sender and MSP receiver), ExpressLRS receiver (packet decoding, telemetry response, phase lock, connection states), FrSky SPI D8 and X receivers (binding, hopping, D8 telemetry with hub data, X telemetry transport), S-FHSS receiver (offset tuning, hunt, hop code), Redpine receiver (fast and slow modes, bind tuning, hop table), FlySky AFHDS and AFHDS 2A receivers (binding, hopping, telemetry), Spektrum DSM2 and DSMX SPI receiver (binding, hopping, telemetry), V202, SYMA, H8_3D, CX10 and CX10A receivers over the NRF24L01 driver with XN297 payloads (binding, bind answers, hopping), RC statistics proved and vector-checked; other protocol decoders and other SPI receivers open |
| pg, config, cli, msp | 21377 | 4751 | simplified tuning of the PID gains and filters, MSP serial port (frame decoder for the three framings, requests between frames, reply encoder), MSP box table (names, permanent ids, paged replies, status bits), MSP state replies (status, sensor readings, motors, RC channels, attitude, altitudes, battery, debug, GPS, ESC and motor telemetry, pitot, transmitter information, clock), MSP common replies (versions, board and build information, unique id, feature and beeper configuration, meters and their sensors, battery and transponder configuration, OSD canvas), MSP tuning replies (PID gains, rate profile, advanced, filter and advanced PID configuration, alignments, arming configuration, 3D throttle, deadbands), MSP receiver replies (mode and adjustment ranges, receiver, failsafe and channel failsafe configuration, RSSI channel, channel map), MSP hardware replies (mixer, motors, compass, GPS, rescue, trims, flight log, sensors, flash and SD card storage), MSP peripheral replies (servos, motor order, LED strip, video transmitter, wing tuning), MSP text replies (names, texts by type, transmitter table rows, LED strip values, battery profiles), MSP simplified tuning messages (slider read, gain and filter calculations, validation, slider write), MSP OSD replies (configuration, warnings line), MSP serial port replies (legacy and common layouts), MSP transmitter device status, configuration storage image (checks, lookup, load, save) proved and vector-checked; parameter groups, command set and command line open |
| blackbox, osd, cms, telemetry, io | 59977 | 26569 | beeper (sound table, sequences, multi-beep fills, bench suppression, DShot beacon), flight log field encodings, header (field tables, condition cache, byte budget, chunked writers) and recorder (log states, intra, delta, slow, GPS and event frames, iteration policy), CRSF telemetry frames with their schedule and speed negotiation, SmartPort telemetry stream, RunCam device protocol, FrSky hub telemetry stream, iBus telemetry sensors, HoTT telemetry link, Ghost telemetry frames, race transponder codings, SRXL telemetry frames, FrSky OSD device link, LED strip, GPS frame decoders for NMEA sentences and UBX messages, UBX configuration messages, GPS link with its rate detection, autoconfiguration, data timeout and home distances, video transmitter table, SmartAudio and Tramp drivers, transmitter settings update with the stick, switch and Spektrum control, LTM telemetry stream, OSD warnings line, MSP tunnel over telemetry, OSD formatting with the plus codes, transmitter driver over MSP, MSP display port, OSD statistics, OSD page with the arming and boot screens, OSD alarms and active element list, OSD element renderers for readings, GPS, link, ESC, names, graphics and VTX channel, OSD warnings element, OSD draw cycle, OSD spec prearm screen, OSD task, MAVLink telemetry streams, commands and mission protocol, Jeti EX Bus telemetry, BLHeli 4-way interface, gimbal control, OSD custom text, PID audio, PINIO boxes, warning LED, flash filesystem, serial feature map with its conflict rule and configuration fix proved and vector-checked; the rest Phase 6 |
| drivers, target, build, msc | 55927 | 720 | DShot frame, command conversions, output endpoints, reply decoder, telemetry state and quality counters proved and vector-checked; the rest Phase 7 |
| platform (STM32, AT32, APM32, PICO, ESP32, SITL) | not counted | 0 | Phase 7 |
| total measured | 195545 | 69061 | |
