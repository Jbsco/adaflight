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

The core holds the bounded maths with the fast exponential and logarithm, the filter
set, three-axis vectors and rotations, the sliding DFT, piecewise-linear tables,
integrity codes, the encodings, bit arrays, stream buffers, the Huffman encoder, GPS
coordinate conversion, sensor alignment, color conversion, the chirp generator, the rate
curves, the RC command path with its smoothing and feedforward, the PID profile with its
runtime configuration, filter initialization, rate loop, throttle-side features, crash
recovery, and launch control, the motor mixer, the gyro calibration, filtering chain,
dynamic notch, RPM filter, and full-scale detections, the attitude estimator with the
compass heading, the failsafe state machine, the runtime modes, the accelerometer path,
the barometer altitude, the compass with its bias calibration, the battery meters and
states, the sensor and board alignment, the arming logic with launch control and runaway
takeoff prevention, the angle and horizon level modes, the position Kalman filter, the
altitude estimator, the altitude hold, the in-flight adjustments, the simplified tuning of
the PID gains, the cooperative scheduler, the beeper, the receiver's channel processing,
and the SBUS, CRSF, SUMD, SUMH, IBUS, Spektrum, XBUS, Jeti EX Bus, Ghost, SRXL2 and FPORT
protocols, the MSP and MAVLink receivers, the MSP serial port, the ExpressLRS hopping
tables, the ExpressLRS telemetry link, the flight log field encodings, the text
conversions, the DShot protocol, and the CRSF telemetry frames.

- The core proves at Silver and Gold: 6961 checks, nothing unproved, no
  `pragma Assume`, no justified suppression (`gnatprove` 16.1.0, level 2).
- The recorded vectors replay bit for bit: 342853 lines over 236 cases, every case
  exact except the seventeen declared deviations in `DESIGN.md` D6.
- No target builds yet. `ROADMAP.md` carries the parity inventory and the phases.

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
