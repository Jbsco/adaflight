# Ghost legacy channel values below the minimum wrap to the top of the range

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F38, `DESIGN.md` D48. Not reported upstream.

## Betaflight

The Ghost receiver rescales a legacy ten-bit frame's primary channels as five quarters of the count less 430 and the aux channels as five times a quarter of the count less 108, into unsigned 16-bit channel values. The protocol's minimum counts are 344 and 88. A primary count below 344 or an aux count below 88 gives a negative result, which wraps to above 65000, so the channel reads near 17000 or 66000 microseconds instead of its minimum. This was found in the source, not on hardware.

## adaflight

The driver holds a negative rescaled count at zero. The Ghost vectors were recorded from a host build of Betaflight's receiver with the same floor.

## Proposed change for Betaflight

Take the maximum of each rescaled value and zero before storing it in the channel array.
