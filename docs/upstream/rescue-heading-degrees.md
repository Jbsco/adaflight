# GPS rescue steers in whole degrees

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F60, `DESIGN.md` D83. Not reported upstream.

## Betaflight

The attitude's yaw comes in decidegrees. The GPS rescue converts it to degrees with a macro that divides as integers, both for the aircraft heading it compares with the direction home and for the yaw target it hands the autopilot at the start of a rescue. The fraction of a degree is lost before the float conversion, so the heading error, the bearing target and the yaw target each carry up to a degree of quantization. Read from the source; not reproduced on hardware.

## adaflight

Both conversions divide in floating point, so the rescue works in tenths of a degree. The rescue vectors were recorded from a host build of Betaflight's rescue with the same floating point division.

## Proposed change for Betaflight

At both uses in the multirotor rescue, divide `attitude.values.yaw` by `10.0f` in place of the integer macro.
