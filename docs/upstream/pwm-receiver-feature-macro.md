# Parallel PWM receiver feature hangs on a macro no build defines

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-18). Finding F366, `DESIGN.md` D809. Not
reported upstream.

## Betaflight

`featuresSupportedByBuild` offers `FEATURE_RX_PARALLEL_PWM` only under `#ifdef USE_PWM`. No build defines
`USE_PWM`. Every build defines `USE_RX_PWM`, which compiles the PWM receiver input. The CLI answers
`feature RX_PARALLEL_PWM` with "Unavailable". `validateAndFixConfig` clears unsupported features when a
configuration loads and when one is saved, so a feature mask set over MSP loses the bit as well. `pwmRxInit`
never runs. PR #13494 wrote the list with `USE_PPM` and `USE_PWM`, and PR #14072 corrected the first to
`USE_RX_PPM`.

## adaflight

The build offers the parallel PWM receiver feature. The command line enables it, the configuration check keeps
it, and the feature listing names it as available.

## Proposed change for Betaflight

Offer the feature under `USE_RX_PWM`, as PR #14072 did for PPM.
