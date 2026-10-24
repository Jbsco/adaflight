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

Flight software is ported and runs on host, where each ported function replays inputs recorded from Betaflight's host build and must reproduce its results bit for bit. Phase 7 of `ROADMAP.md` is in progress: `targets/stm32f4` builds STM32F405 images.

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

`core/src/adaflight-bmi270_config.ads` contains Bosch Sensortec's BMI270 configuration file under
BSD-3-Clause license. `third_party/bosch-bmi270` contains that license and names the source.
