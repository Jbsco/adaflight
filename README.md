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

- bounded maths with fast exponential and logarithm, filter set, three-axis vectors and rotations,
  sliding DFT, piecewise-linear tables, integrity codes, encodings, bit arrays, stream buffers,
  and Huffman encoder
- GPS coordinate conversion, sensor alignment, color conversion, and chirp generator
- rate curves and RC command path with smoothing and feedforward
- in-flight adjustments and simplified tuning of PID gains and filters
- PID profile with runtime configuration, filter initialization, rate loop, throttle-side
  features, crash recovery, and launch control
- motor mixer with mixer setup: frame tables, custom mixes, launch control mix
- gyro calibration, filtering chain, dynamic notch, RPM filter, and full-scale detections
- attitude estimator with compass heading, and angle and horizon level modes
- failsafe state machine, runtime modes with ground station overrides, and arming logic with
  launch control and runaway takeoff prevention
- accelerometer path, barometer altitude and read cycle, compass with bias calibration, battery
  meters (analog, ESC sensor, virtual, MSP) and states, and sensor and board alignment
- position Kalman filter, position estimator from barometer, accelerometer and GPS, altitude hold,
  position hold with autopilot's navigation modes, GPS rescue, and position navigation target
- flight plan storage with waypoint capture gesture, and executor's plan queries, leg geometry,
  carrot legs, dispatch, landing, update cycle, engagement, plan injection, geofence return,
  rescue plan and descent, and waypoint distance, bearing and time
- cooperative scheduler, beeper, and receiver's channel processing with MSP override
- SBUS, CRSF, SUMD, SUMH, IBUS, Spektrum, XBUS, Jeti EX Bus, Ghost, SRXL2 and FPORT protocols, and
  MSP and MAVLink receivers
- FrSky SPI D8 and X receivers with binding, hopping, hub data and telemetry transport
- S-FHSS receiver with offset tuning, hunt and hop code
- Redpine receiver with fast and slow modes, bind tuning and hop table
- FlySky AFHDS and AFHDS 2A receivers with binding, hopping and telemetry
- Spektrum DSM2 and DSMX SPI receiver with binding, hopping and telemetry
- V202, SYMA and H8_3D receivers over NRF24L01 driver with XN297 payloads
- RC statistics for full throttle time and count and average throttle
- receiver task's state machine with step time estimates
- MSP serial port, ExpressLRS hopping tables, telemetry link and receiver, flight log field
  encodings, header and recorder, text conversions, and DShot protocol
- flash filesystem for flight log, with ring buffer, erases and free space search
- serial feature map: port function bits and baud rates from feature settings, claims, mask and
  baud writes, conflict rule and configuration fix
- CRSF telemetry frames and ESC sensor telemetry
- SmartPort telemetry stream
- RunCam device protocol with camera buttons and five key cable
- FrSky hub telemetry stream
- iBus telemetry sensors
- HoTT telemetry link in binary mode
- Ghost telemetry frames
- race transponder codings and repeat schedule
- SRXL telemetry frames with text generator
- FrSky OSD device link
- LED strip with status, race and beacon profiles
- rangefinder readings with median, signal ratio and tilt correction
- optical flow readings with rotation and gyro compensation
- pitot airspeed with zeroing and source fallback
- real-time clock calendar with zone offset and ISO 8601 text
- internal ADC channels with supply and core temperature compensation
- flight statistics with save gate
- wing launch with throw detection and handover
- navigation trail with distance gate and decimation
- GPS frame decoders for NMEA sentences and UBX messages, UBX configuration messages, and GPS link
  with rate detection, autoconfiguration and home distances
- video transmitter table, SmartAudio, Tramp and MSP drivers, and transmitter settings update with
  stick, switch and Spektrum control
- LTM telemetry stream
- GPS lap timer with averaged gate and best three laps
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
- configuration storage image: structure and version checks, record lookup, load and save
- MSP state replies: status, sensor readings, motors, RC channels, attitude, altitudes, battery,
  debug values, GPS, ESC and motor telemetry, pitot, transmitter information and clock
- BLHeli 4-way interface for ESC configuration through flight controller
- gimbal control from a head tracker and sticks
- OSD custom text from a serial port
- PID audio tone
- PINIO outputs switched by boxes
- warning LED
- dispatch queue of delayed calls
- OSD warnings line with precedence, arming reason rotation and ESC alarms
- MSP tunnel over telemetry with chunked requests and replies
- OSD formatting of numbers, altitudes, distances, coordinates with plus codes, clock and timers,
  with battery and direction symbols
- MSP display port with payloads, attribute byte and canvas size
- OSD statistics with extremes and page texts
- OSD page with arming and boot screens and cycle steps around them
- OSD element set with alarms and renderers, warnings element, draw cycle, spec prearm screen and
  OSD task
- MAVLink telemetry streams with intervals and arming status text, and MAVLink commands with
  replies and requests
- MAVLink mission protocol with uploads, downloads, fence store and current item reports
- Jeti EX Bus telemetry with sensor descriptions and value messages

The state of `main`:

- Core proves at Silver and Gold: 19343 checks, nothing unproved, no `pragma Assume`, no justified
  suppression (`gnatprove` 16.1.0, level 2).
- Recorded vectors replay bit for bit: 1518737 lines over 358 cases, every case exact except
  twenty-three declared deviations in `DESIGN.md` D6.
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

- Every unit in `core/` is SPARK and proves free of run-time errors, except two bodies outside
  SPARK: accurate power (`DESIGN.md` D15) and GPS rescue arctangent (D6). The proof gate counts
  such bodies on every run.
- No `pragma Assume` and no justified suppression. `prove.do` prints both counts.
- A pull request proves the units whose sources it changed (`tools/changed-units.py`).
  A nightly run proves the whole core.
- A ported function keeps the operation order of its Betaflight original, so the host
  build reproduces its results bit for bit. The vector checker reports the distance in
  representable values for every case.
- A deliberate deviation carries a tolerance in the checker and an entry in `DESIGN.md`.
- Vectors under `tests/vectors` were recorded from a host build of Betaflight at commit af0638839
  by a tool outside this repository, so the checker holds the port to Betaflight's exact results.

## License

GPL-3.0-or-later. See `LICENSE`.
