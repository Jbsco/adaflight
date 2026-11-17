# QMP6988 temperature in whole degrees

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-16). Finding F362, `DESIGN.md` D790. Not reported upstream.

## Betaflight

`qmp6988Calculate` compensates a temperature in 1/256 of a degree and stores it divided by 256, in whole degrees. Barometer code and telemetry read `baro.temperature` as hundredths of a degree, which every other barometer driver gives. With a QMP6988, 25 degrees reads as 0.25 degrees in FrSky, IBUS and CRSF telemetry and in debug values. Altitude drift correction for temperature then acts at a hundredth of its setting.

## adaflight

A QMP6988's temperature is its compensated value times 100 over 256, in hundredths of a degree.

## Proposed change for Betaflight

Store `tr * 100 / 256` in `qmp6988Calculate`.
