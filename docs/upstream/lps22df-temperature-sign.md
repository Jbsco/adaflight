# LPS22DF temperatures below zero read 655.36 degrees too high

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F270, `DESIGN.md` D350. Not reported upstream.

## Betaflight

The LPS22DF driver builds the raw temperature from its two output bytes without sign extension and reports that count as the temperature in hundredths of a degree. The chip's temperature output is a signed 16-bit value, as the Linux kernel's driver for the same chip family treats it. A temperature below zero therefore reads 655.36 degrees too high: -29.75 degrees arrives as 62561, which reads as 625.61 degrees. The barometer's temperature feeds the OSD and telemetry, not the altitude. This was found in the source, not on hardware.

## adaflight

The driver sign-extends the 16-bit temperature count. The LPS22DF vectors were recorded from a host build of Betaflight's driver with the same sign extension.

## Proposed change for Betaflight

Cast the assembled 16-bit temperature to a signed 16-bit value before widening it to 32 bits.
