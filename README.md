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

The core holds:

- the bounded maths with the fast exponential and logarithm, the filter set, three-axis
  vectors and rotations, the sliding DFT, piecewise-linear tables, integrity codes, the
  encodings, bit arrays, stream buffers, and the Huffman encoder
- GPS coordinate conversion, sensor alignment, color conversion, and the chirp generator
- the rate curves and the RC command path with its smoothing and feedforward
- the in-flight adjustments and the simplified tuning of the PID gains
- the PID profile with its runtime configuration, filter initialization, rate loop,
  throttle-side features, crash recovery, and launch control
- the motor mixer
- the gyro calibration, filtering chain, dynamic notch, RPM filter, and full-scale
  detections
- the attitude estimator with the compass heading, and the angle and horizon level modes
- the failsafe state machine, the runtime modes, and the arming logic with launch
  control and runaway takeoff prevention
- the accelerometer path, the barometer altitude, the compass with its bias calibration,
  the battery meters and states, and the sensor and board alignment
- the position Kalman filter, the position estimator from the barometer, the accelerometer
  and the GPS, the altitude hold, the position hold, and the GPS rescue
- the cooperative scheduler, the beeper, and the receiver's channel processing
- the SBUS, CRSF, SUMD, SUMH, IBUS, Spektrum, XBUS, Jeti EX Bus, Ghost, SRXL2 and FPORT
  protocols, and the MSP and MAVLink receivers
- the MSP serial port, the ExpressLRS hopping tables and telemetry link, the flight log
  field encodings, the text conversions, and the DShot protocol
- the CRSF telemetry frames and the ESC sensor telemetry
- the SmartPort telemetry stream
- the RunCam device protocol with the camera buttons and the five key cable
- the FrSky hub telemetry stream
- the iBus telemetry sensors
- the HoTT telemetry link in its binary mode
- the Ghost telemetry frames
- the race transponder codings and their repeat schedule
- the SRXL telemetry frames with the text generator
- the FrSky OSD device link
- the LED strip with its status, race and beacon profiles
- the rangefinder readings with their median, signal ratio and tilt correction
- the optical flow readings with their rotation and gyro compensation
- the pitot airspeed with its zeroing and its source fallback
- the real-time clock calendar with its zone offset and its ISO 8601 text
- the internal ADC channels with the supply and core temperature compensation
- the flight statistics with their save gate
- the wing launch with its throw detection and its handover
- the navigation trail with its distance gate and its decimation
- the GPS frame decoders for NMEA sentences and UBX messages, the UBX configuration messages,
  and the GPS link with its rate detection, autoconfiguration and home distances
- the video transmitter table, the SmartAudio and Tramp drivers, and the transmitter settings
  update with the stick, switch and Spektrum control
- the LTM telemetry stream
- the GPS lap timer with its averaged gate and its best three laps

The state of `main`:

- The core proves at Silver and Gold: 10960 checks, nothing unproved, no
  `pragma Assume`, no justified suppression (`gnatprove` 16.1.0, level 2).
- The recorded vectors replay bit for bit: 702990 lines over 290 cases, every case
  exact except the eighteen declared deviations in `DESIGN.md` D6.
- No target builds yet. `ROADMAP.md` carries the parity inventory, the phases, and the
  question for after parity: whether a proved core leaves room on the F4 boards for
  features Betaflight has to leave out for these targets.

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

- Every unit in `core/` is SPARK and proves free of run-time errors, except the one body
  outside SPARK that `DESIGN.md` D15 names. The proof gate counts such bodies on every run.
- No `pragma Assume` and no justified suppression. `prove.do` prints both counts.
- A pull request proves the units it changed and the units that depend on a changed
  specification (`tools/changed-units.py`). A nightly run proves the whole core.
- A ported function keeps the operation order of its Betaflight original, so the host
  build reproduces its results bit for bit. The vector checker reports the distance in
  representable values for every case.
- A deliberate deviation carries a tolerance in the checker and an entry in `DESIGN.md`.
- The vectors under `tests/vectors` were recorded from a host build of Betaflight at
  commit af0638839 by a tool outside this repository, so the checker holds the port to
  Betaflight's exact results.

## License

GPL-3.0-or-later. See `LICENSE`.
