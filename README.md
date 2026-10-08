# adaflight

[![SPARK Proofs](https://github.com/Jbsco/adaflight/actions/workflows/prove.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/prove.yml)
[![Vector Checks](https://github.com/Jbsco/adaflight/actions/workflows/test.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/test.yml)
[![Style](https://github.com/Jbsco/adaflight/actions/workflows/style.yml/badge.svg)](https://github.com/Jbsco/adaflight/actions/workflows/style.yml)

Flight control firmware for multirotors and wings, written in SPARK and Ada. The goal is
feature and performance parity with the reference firmware named under
[Inspiration](#inspiration), with a proved core where proof gives assurance that testing
cannot: no filter or controller can produce an infinity or a NaN whatever its input
history, no decoder can index outside its buffer, and every motor command is in range by
type.

## Contents

- [Status](#status)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Verification policy](#verification-policy)
- [Inspiration](#inspiration)
- [License](#license)

## Status

The core holds the bounded maths with the fast exponential and logarithm, the filter
set, three-axis vectors and rotations, the sliding DFT, piecewise-linear tables,
integrity codes, the encodings, bit arrays, stream buffers, the Huffman encoder, GPS
coordinate conversion, sensor alignment, color conversion, the chirp generator, the rate
curves, and the PID profile with its runtime configuration, filter initialization, and
rate loop.

- The core proves at Silver and Gold: 2029 checks, nothing unproved, no
  `pragma Assume`, no justified suppression (`gnatprove` 16.1.0, level 2).
- The recorded vectors replay bit for bit: 46873 lines over 127 cases, every case
  exact except the six declared deviations in `DESIGN.md` D6.
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

- Every unit in `core/` is SPARK and proves free of run-time errors.
- No `pragma Assume` and no justified suppression. `prove.do` prints both counts.
- A ported function keeps the operation order of the reference, so the host build
  reproduces its results bit for bit. The vector checker reports the distance in
  representable values for every case.
- A deliberate deviation carries a tolerance in the checker and an entry in `DESIGN.md`.

## Inspiration

adaflight is a port of [Betaflight](https://github.com/betaflight/betaflight), the
flight control firmware this project measures itself against. Betaflight's algorithms,
feature set, and configuration surface define parity here. The test vectors under
`tests/vectors` were recorded from a host build of Betaflight at commit af0638839 by a
separate tool, so the checker holds the port to the reference's exact results. Betaflight
is licensed under the GPL-3.0, and so is this project. The rate curve families keep the
order of Betaflight's `rates_type` values and are named after their distinctive setting:
super rate, acro plus, RC curve, actual, quick.

## License

GPL-3.0-or-later. See `LICENSE`.
