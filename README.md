# adaflight

[![SPARK Proofs](https://github.com/Jbsco/adaflight/actions/workflows/prove.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/prove.yml)
[![Vector Checks](https://github.com/Jbsco/adaflight/actions/workflows/test.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/test.yml)
[![Style](https://github.com/Jbsco/adaflight/actions/workflows/style.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/style.yml)

Flight control firmware for multirotors and wings, written in SPARK and Ada as a port of
[Betaflight](https://github.com/betaflight/betaflight). The goal is feature and performance
parity with Betaflight, with a proved core where proof gives assurance that testing cannot:
no filter or controller can produce an infinity or a NaN whatever its input history, no
decoder can index outside its buffer, and every motor command is in range by type.

## Contents

- [Status](#status)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Verification policy](#verification-policy)
- [License](#license)

## Status

The core contains:

<details>
<summary><b>Maths and encodings</b> (2)</summary>

- bounded maths with fast exponential and logarithm, filter set, three-axis vectors and rotations,
  sliding DFT, piecewise-linear tables, integrity codes, encodings, bit arrays, stream buffers,
  and Huffman encoder
- GPS coordinate conversion, sensor alignment, color conversion, and chirp generator

</details>

<details>
<summary><b>Flight control</b> (75)</summary>

- rate curves and RC command path with smoothing, feedforward, low voltage cutoff and 3D throttle
- in-flight adjustments and simplified tuning of PID gains and filters
- PID profile with runtime configuration, filter initialization, rate loop, throttle-side
  features, crash recovery, launch control, yaw spin recovery, landing disarm, and wing airspeed
  TPA with S term, setpoint attenuation, pitch offset, passthrough and launch level mode
- motor mixer with mixer setup: frame tables, custom mixes, launch control mix, launch control,
  altitude hold and GPS rescue throttles, RPM limiter, crash flip mixing, DShot failsafe floor,
  battery sag compensation, dynamic idle, 3D throttle with motor reversal, wing RMS output and
  launch throttle
- gyro calibration and averaging over up to four sensors with selection at startup, filtering
  chain, dynamic notch, RPM filter, and full-scale detections
- attitude estimator with compass heading and headfree frame, and angle and horizon level modes
  with GPS rescue, altitude hold and position hold
- failsafe state machine with rescue and autopilot stages, runtime modes with ground station
  overrides, and arming logic with launch control, runaway takeoff prevention, DShot checks, crash
  flip arming, GPS checks, hold mode selection, statistics events, OSD menu gate, telemetry port
  sharing, VTX control, wing launch mode and in-flight accelerometer calibration
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason
- core loop cadence: PID loop sample counter, filter and controller readiness, yaw reset at low
  throttle while arming by stick
- PID loop pass: unit order of task, with launch wing, runaway check, PID audio, servos and flight
  log conditions
- analog motor endpoints: output range and disarm output of PWM, OneShot, MultiShot and brushed
  protocols, with 3D limits and deadband
- arming load check: scheduler's late task share against configured limit as disable reason

</details>

<details>
<summary><b>Sensors and estimation</b> (1)</summary>

- accelerometer path with in-flight calibration, barometer altitude and read cycle, compass with
  bias calibration and read cycle, battery meters (analog with sag filter, ESC sensor, virtual,
  MSP), states and pack connection, and sensor and board alignment

</details>

<details>
<summary><b>Sensor drivers and detection</b> (1)</summary>

- BMP280 barometer driver: I2C and SPI detection with address fallback, read cycle calls,
  datasheet integer compensation

</details>

<details>
<summary><b>Navigation</b> (2)</summary>

- position Kalman filter, position estimator from barometer, accelerometer and GPS, altitude hold,
  position hold with autopilot's navigation modes, GPS rescue, and position navigation target
- flight plan storage with waypoint capture gesture, and executor's plan queries, leg geometry,
  carrot legs, dispatch, landing, update cycle, engagement, plan injection, geofence return,
  rescue plan and descent, and waypoint distance, bearing and time

</details>

<details>
<summary><b>Receivers</b> (10)</summary>

- SBUS, CRSF, SUMD, SUMH, IBUS, Spektrum, XBUS, Jeti EX Bus, Ghost, SRXL2 and FPORT protocols, PPM
  and parallel PWM inputs, and MSP and MAVLink receivers
- FrSky SPI D8 and X receivers with binding, hopping, hub data and telemetry transport
- S-FHSS receiver with offset tuning, hunt and hop code
- Redpine receiver with fast and slow modes, bind tuning and hop table
- FlySky AFHDS and AFHDS 2A receivers with binding, hopping and telemetry
- Spektrum DSM2 and DSMX SPI receiver with binding, hopping and telemetry
- NRF24L01 driver, XN297 payloads, and V202, SYMA, H8_3D, CX10 and acknowledgment payload
  receivers
- SPI receiver layer: receiver family per protocol, frame checks and processing, channel reads and
  stop
- RC statistics for full throttle time and count and average throttle
- receiver task's state machine with step time estimates

</details>

<details>
<summary><b>Telemetry</b> (30)</summary>

- CRSF telemetry frames with link type check, ESC sensor telemetry
- SmartPort telemetry stream
- FrSky hub telemetry stream
- iBus telemetry sensors
- HoTT telemetry link in binary and text modes, text mode screen for menu system
- Ghost telemetry frames
- race transponder codings and repeat schedule
- SRXL telemetry frames with text generator and display port for menu system
- LTM telemetry stream
- MSP tunnel over telemetry with chunked requests and replies
- MAVLink telemetry streams with intervals and arming status text, and MAVLink commands with
  replies and requests
- MAVLink mission protocol with uploads, downloads, fence store and current item reports
- Jeti EX Bus telemetry with sensor descriptions and value messages
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies
- MSP tunnel over telemetry with chunked requests and replies

</details>

<details>
<summary><b>MSP</b> (42)</summary>

- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- MSP box table with paged replies and status bits
- MSP common replies: versions, board and build information, unique id, feature and beeper
  configuration, meters and sensors, battery and transponder configuration, OSD canvas
- MSP tuning replies: PID gains, rate profile, advanced, filter and advanced PID configuration,
  alignments, arming configuration, 3D throttle and deadbands
- MSP receiver replies: mode and adjustment ranges, receiver, failsafe and channel failsafe
  configuration, RSSI channel and channel map
- MSP hardware replies: mixer, motors, compass, GPS, rescue, trims, flight log, sensors, and flash
  and SD card storage
- MSP peripheral replies: servos, motor order, LED strip, video transmitter and wing tuning
- MSP text replies: names, texts by type, transmitter table rows, LED strip values and battery
  profiles
- MSP simplified tuning messages: slider read and write, gain and filter calculations, validation
- MSP OSD replies: configuration and warnings line
- MSP serial port replies: available ports with baud rates in legacy and common layouts
- MSP transmitter device status: type, readiness, band and channel, power, frequency, status,
  power levels and device block
- MSP state replies: status, sensor readings, motors, RC channels, attitude, altitudes, battery,
  debug values, GPS, ESC and motor telemetry, pitot, transmitter information and clock
- MSP tuning writes: PID gains, rate tuning, arming, trims, 3D throttle, deadbands, alignments and
  PID reset, whole-request range check
- MSP filter and advanced writes: advanced configuration, filters and advanced PID settings with
  gyro checks of configuration fix
- MSP receiver writes: mode and adjustment ranges, receiver and failsafe settings, channel
  failsafe values, RSSI channel and channel map
- MSP hardware writes: mixer, sensors, motors, GPS, compass declination, GPS rescue and gains
- MSP battery writes: voltage and current meters, cell voltages, capacity and meter sources
- MSP feature writes: features, beeper and beacon conditions, beacon tone, motor output order
- MSP blackbox write: device, sample rate from rate or frame ratio, fields left out
- MSP servo writes: servo parameters and servo mix rules with servo and smix command bounds
- MSP LED writes: colors, LED configurations and mode colors with command line bounds
- MSP text writes: craft name, texts by type, LED strip values and battery profiles
- MSP peripheral writes: wing tuning, transponder provider and data, VTX table bands and power
  levels
- MSP control writes: flash erase, arming switch per link, calibrations, configuration write,
  restart into a mode, DShot commands
- MSP OSD writes: general settings with video system switch, timers, element positions,
  statistics, canvas
- MSP profile writes: profile selection and copy
- MSP VTX configuration write: band and channel or frequency, power, pit mode, table counts and
  clearing
- MSP runtime writes: raw receiver channels, raw GPS solution, GPS sensor solution, transmitter
  RSSI, clock, MT sensor readings
- MSP board writes: board information and signature set once, configuration reset with reply
- MSP motor test: disarmed motor values converted for motor protocol
- MSP OSD font character write: four request forms, character handed to OSD display port
- MSP command line setting message: settings read by name, strict writes by name with new value in
  reply
- MSP command line setting information message: parameter group, type, range or values, default

</details>

<details>
<summary><b>Configuration and command line</b> (688)</summary>

- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line gyro registers: identity and configuration registers of each enabled gyro
- command line flash tools: whole erase, verify, writes and reads at an address
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line gyro registers: identity and configuration registers of each enabled gyro
- command line flash tools: whole erase, verify, writes and reads at an address
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line gyro registers: identity and configuration registers of each enabled gyro
- command line flash tools: whole erase, verify, writes and reads at an address
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line gyro registers: identity and configuration registers of each enabled gyro
- command line flash tools: whole erase, verify, writes and reads at an address
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line gyro registers: identity and configuration registers of each enabled gyro
- command line flash tools: whole erase, verify, writes and reads at an address
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line gyro registers: identity and configuration registers of each enabled gyro
- command line flash tools: whole erase, verify, writes and reads at an address
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line gyro registers: identity and configuration registers of each enabled gyro
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line passthrough starts: ESC serial links by protocol and output, GPS receiver
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line environment: status readings and build identity as name and value lines with a name
  filter
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line status: MCU, clock, stack, configuration, bus devices, gyros, sensors, GPS
  receiver, OSD, storage, uptime, load, battery, arming disable reasons
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line peripherals: serial ports with claims, detected gyros and sensors with buses
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line build options: option numbers of build, one per line
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line DShot programming: commands to one ESC or all, ESC information of KISS v1, KISS v2
  and BLHeli_32 ESCs
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line help: command list with descriptions and arguments, search by name or description
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line restarts: ROM bootloader, and mass storage with timezone offset
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line storage information: SD card state, identity and file system, flash chip geometry,
  partitions and file system use
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule, configuration fix, port sharing and telemetry provider ports
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule, configuration fix, port sharing and telemetry provider ports
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule, configuration fix, port sharing and telemetry provider ports
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule, configuration fix, port sharing and telemetry provider ports
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule, configuration fix, port sharing and telemetry provider ports
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule, configuration fix, port sharing and telemetry provider ports
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule, configuration fix, port sharing and telemetry provider ports
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule and configuration fix
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule and configuration fix
- configuration storage image: structure and version checks, record lookup, load and save
- settings table: names, types, scopes, ranges and lookup tables of command line's 789 settings
- configuration groups: a record per parameter group with Betaflight's defaults, every setting's
  value and write, and groups' bytes for storage image
- configuration fix: checks of every load and save over mixer mode, telemetry slots, serial ports,
  filter cutoffs, receiver features, mode links, DShot settings, PID loop rate, profile
  selections, rates and battery voltages
- command line get and set: line handling, setting values, ranges and defaults, value parsing and
  error lines
- command line profiles, dump and diff: profile selection, profile and rate sections with defaults
- command line features and beepers: feature, beeper and beacon lists and switches
- command line mode conditions: aux lists and writes
- command line receiver channels: channel map, stick ranges and failsafe values
- command line adjustment ranges: adjrange lists and writes
- command line serial ports: claim lists and legacy port lines
- command line mixer and motor mix: mixer names, custom motor mixes, float reading and text
- command line servos: servo parameters, servo rules with loads and reversed sources
- command line LEDs: LED configurations, colors and mode colors
- command line VTX settings: VTX channel conditions and VTX table
- command line flight plan: waypoint lists, edits and status with executor's report
- command line master dump: section commands, master settings and selected profiles, version line
- command line master diff: changed lines with defaults, hardware section
- command line dump of every profile: profile restores and save, MCU id and signature lines
- command line board information: board name, manufacturer and signature commands
- command line simplified tuning: apply and disable over stored profiles and gyro settings
- command line defaults: whole and single-group resets without save
- command line batches: batch start and end with error flag, unknown line reply
- command line tasks: task list with rates, execution times and loads, check functions and total
  load lines, peak time resets
- command line save and exit: save with board persistence and batch refusal, exit, defaults with
  save, requests to write, restart and leave
- command line information: VTX power levels, receiver frame rate and RC smoothing cutoffs
- command line motors and sounds: disarmed values for one or every motor, beeper table sounds
- command line sensor hardware: hardware names of every sensor type or of one
- command line DShot telemetry: driver counts, direction change time, each motor's replies, RPM
  and invalid share, decoder edge times
- command line tasks late columns: late and run counts and anticipated time per task
- runtime records from stored configuration: PID profile, rate profile, gyro, arming, failsafe,
  receiver, RC command, adjustment, mixer, accelerometer, attitude, barometer, compass, battery,
  beeper, GPS link, GPS rescue, position, altitude, flight plan, blackbox, scheduler, LED strip,
  VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD, telemetry and
  receiver link settings and mode conditions with range holds, fix's postcondition as precondition

</details>

<details>
<summary><b>Scheduler and tasks</b> (144)</summary>

- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main with SD card poll, serial, battery alerts, accelerometer, GPS rescue,
  barometer, pitot, compass, position, rangefinder, optical flow, telemetry and camera control
  tasks over units, sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- task setup: tasks enabled at boot and periods from build, features, sensors and settings
- scheduler late task statistics: run and late counts per task, anticipated times, late share per
  timing window
- scheduler debug values: pass overhead, gyro cycle determinism, timing accuracy and debug task
  values
- task functions: main, serial, battery alerts, accelerometer, GPS rescue, barometer, pitot,
  compass, position, rangefinder, optical flow, telemetry and camera control tasks over units,
  sensor tasks rescheduled by updates
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls

</details>

<details>
<summary><b>OSD and menus</b> (401)</summary>

- OLED dashboard: pages of board state with cycling, armed page, failsafe and receiver corner
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OLED dashboard: pages of board state with cycling, armed page, failsafe and receiver corner
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OLED dashboard: pages of board state with cycling, armed page, failsafe and receiver corner
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OLED dashboard: pages of board state with cycling, armed page, failsafe and receiver corner
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OLED dashboard: pages of board state with cycling, armed page, failsafe and receiver corner
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry
- OSD custom text from a serial port
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- OSD navigation map: home, flight plan waypoints and flown trail with automatic width
- OSD flight plan items: waypoint number, coordinates, altitude, distance, direction, next
  waypoint, arrival time and airspeed
- OSD flight plan warnings: waypoint aborts, capture messages, landing and plan complete cues,
  rescue descent failure
- OSD warnings reports: visual beeper and capture message reads passed to target through draw
  cycle and OSD task
- menu system lines and page layout: element and flag encoding, screen geometry, page count and
  selection, cursor row, skip rule, fixed-point text, field alignment and display character set
- menu draw: page labels, values and cursor within display's byte budget, element value forms,
  slider marks and page arrows
- menu navigation: open on current display or next one, menu changes over context stack with enter
  and leave hooks, page selection, draw with update hook, exits of every kind with target's
  actions in order
- menu keys: cursor moves over rows and pages, value edits at widths and ranges, submenu,
  function, exit and back lines, save menu by reboot state, edits delivered to target
- menu update: open gesture, sticks read as keys with delay and repeat, external keys, draw,
  heartbeat and drawing transactions per pass
- menu hook effects: menu changes and exits made inside enter hooks and line functions, exit lines
  calling own functions
- menu line refresh: current menu's lines refreshed from target's variables before draw and key
  edits
- menu target state: configuration, readings and menu values kept in target's state, passed to
  every hook
- menus: quick menu with throttle and motor output limits and forced cells, main menu with
  features menu and setup popup for accelerometer calibration and battery restore, profile menu
  with PID, rate, simplified tuning, misc, launch control, filter and profile copy menus, VTX
  selection with error menu, MSP, Tramp and SmartAudio VTX menus with confirmations, RTC6705 VTX
  menu, SmartAudio configuration, statistics and frequency menus, save and exit menus, OSD menu
  with active elements, timers and alarms, blackbox menu with flash erase and mass storage, LED
  strip, power, failsafe with GPS rescue and rescue PID, RPM limit, misc, RC preview, GPS lap
  timer, persistent statistics, firmware and calibration menus
- menu hook operations: clears, texts, redraws, background types and configuration saves, and save
  menu inhibition from hooks
- menu over CRSF: display port screen with clears, delays and transmitter commands, run-length
  chunks and clear frames in CRSF telemetry

</details>

<details>
<summary><b>Peripherals and storage</b> (67)</summary>

- BLHeli 4-way interface for ESC configuration through flight controller
- BLHeli bootloader protocol: software serial on ESC signal pin with connect, keep-alive, restart,
  reads, writes, erases and verifies
- STK500v2 bootloader protocol: pulse-coded ESC signal pin with learned bit threshold, sign-on,
  signature, chip erase, reads and writes
- USB joystick: report of eight axes and eight buttons while disarmed, joystick test that stops
  stick commands
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- BLHeli bootloader protocol: software serial on ESC signal pin with connect, keep-alive, restart,
  reads, writes, erases and verifies
- STK500v2 bootloader protocol: pulse-coded ESC signal pin with learned bit threshold, sign-on,
  signature, chip erase, reads and writes
- USB joystick: report of eight axes and eight buttons while disarmed, joystick test that stops
  stick commands
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- BLHeli bootloader protocol: software serial on ESC signal pin with connect, keep-alive, restart,
  reads, writes, erases and verifies
- STK500v2 bootloader protocol: pulse-coded ESC signal pin with learned bit threshold, sign-on,
  signature, chip erase, reads and writes
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- BLHeli bootloader protocol: software serial on ESC signal pin with connect, keep-alive, restart,
  reads, writes, erases and verifies
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- flash filesystem for flight log, with ring buffer, erases and free space search
- SD card file system: sector cache, partition table and volume ID, FAT entries, 8.3 names,
  cluster search and appends, file cursor with seeks, reads and writes, free-space search, file
  opens, closes, deletes and truncations, directory walks, makes and changes, start with
  free-space file, poll and shutdown
- flight log on SD card: log directory, log numbers from names in it, a new file per log, log ends
  that close or delete, flushes and device state
- flash filesystem for flight log, with ring buffer, erases and free space search
- SD card file system: sector cache, partition table and volume ID, FAT entries, 8.3 names,
  cluster search and appends, file cursor with seeks, reads and writes, free-space search, file
  opens, closes, deletes and truncations, directory walks, makes and changes, start with
  free-space file, poll and shutdown
- flight log on SD card: log directory, log numbers from names in it, a new file per log, log ends
  that close or delete, flushes and device state
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- flash filesystem for flight log, with ring buffer, erases and free space search
- SD card file system: sector cache, partition table and volume ID, FAT entries, 8.3 names,
  cluster search and appends, file cursor with seeks, reads and writes, free-space search, file
  opens, closes, deletes and truncations, directory walks, makes and changes, start with
  free-space file, poll and shutdown
- flash filesystem for flight log, with ring buffer, erases and free space search
- SD card file system: sector cache, partition table and volume ID, FAT entries, 8.3 names,
  cluster search and appends, file cursor with seeks, reads and writes, free-space search, file
  opens, closes, deletes and truncations, directory walks, makes and changes
- flash filesystem for flight log, with ring buffer, erases and free space search
- SD card file system: sector cache, partition table and volume ID, FAT entries, 8.3 names,
  cluster search and appends, file cursor with seeks, reads and writes, free-space search
- flash filesystem for flight log, with ring buffer, erases and free space search
- SD card file system: sector cache, partition table and volume ID, FAT entries, 8.3 names
- flash filesystem for flight log, with ring buffer, erases and free space search
- flash filesystem for flight log, with ring buffer, erases and free space search
- flash filesystem for flight log, with ring buffer, erases and free space search
- RunCam device protocol with camera buttons and five key cable
- FrSky OSD device link
- LED strip with status, race and beacon profiles
- real-time clock calendar with zone offset and ISO 8601 text
- video transmitter table, SmartAudio, Tramp, MSP and RTC6705 drivers, transmitter settings update
  over all four with stick, switch and Spektrum control, and SmartAudio menu state from each
  device response
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks

</details>

The state of `main`:

- Core proves at Silver and Gold: 31134 checks, nothing unproved, no `pragma Assume`, no justified
  suppression (`gnatprove` 16.1.0, level 2).
- Recorded vectors replay bit for bit: 1753568 lines over 384 cases, every case exact except
  fifty-four declared deviations in `DESIGN.md` D6.
- No target builds yet. `ROADMAP.md` contains phases, parity inventory, and one question for after
  parity: whether a proved core leaves room on F4 boards for features Betaflight has to leave out
  there.

## Repository layout

| Path | Contents |
|---|---|
| `core/` | SPARK library crate `adaflight_core`: the proved, hardware-independent core |
| `tests/` | Host crate `adaflight_tests`: replays `tests/vectors` through the core |
| `tools/` | Repository tooling (markdown rendering check) |
| `style.do`, `test.do`, `prove.do`, `verify.do` | The gates, runnable with `bash` or `redo` |
| `DESIGN.md` | Numbered design decisions with their reasons |
| `ROADMAP.md` | Phases and the parity inventory |

## Development

[Alire](https://alire.ada.dev) provides the compiler and the prover.

    cd core && alr build                      # build the core
    cd tests && alr build && ./bin/vector_check vectors
    bash prove.do                             # SPARK proof of the core
    bash verify.do                            # every gate, cheapest first

A change is finished when `verify.do` is green.

## Verification policy

- Every unit in `core/` is SPARK and proves free of run-time errors, except the four bodies
  outside SPARK that `DESIGN.md` names: the accurate power (D15), the rescue's arctangent (D83),
  the configuration codec (D166) and the configuration fix's call sequence (D167). The proof gate
  counts such bodies on every run.
- No `pragma Assume` and no justified suppression. `prove.do` prints both counts.
- A pull request proves the units whose sources it changed (`tools/changed-units.py`).
  A nightly run proves every core unit in four parallel groups. Both prove a generic unit
  through its instantiations, a generic child through its instantiations under its parent's
  instances.
- A ported function keeps the operation order of its Betaflight original, so the host
  build reproduces its results bit for bit. The vector checker reports the distance in
  representable values for every case.
- A deliberate deviation carries a tolerance in the checker and an entry in `DESIGN.md`.
- Vectors under `tests/vectors` were recorded from a host build of Betaflight at commit af0638839
  by a tool outside this repository, so the checker holds the port to Betaflight's exact results.

## License

GPL-3.0-or-later. See `LICENSE`.
