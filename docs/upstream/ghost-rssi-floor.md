# Ghost RSSI below the long-range minimum reads as full strength

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F37, `DESIGN.md` D48. Not reported upstream.

## Betaflight

The Ghost receiver scales the statistics frame's RSSI from the -117 to -60 dBm range onto 0 to 1023 and stores the result in an unsigned 16-bit variable. A report weaker than -117 dBm gives a negative result, which wraps to a value above 64000. The minimum with 1023 that follows then sets the receiver's RSSI to its maximum, so the weakest links show full signal strength. This was found in the source, not on hardware.

## adaflight

The driver holds the scaled RSSI between 0 and 1023, so a report weaker than -117 dBm reads as zero. The Ghost vectors were recorded from a host build of Betaflight's receiver with the same bounds.

## Proposed change for Betaflight

Constrain the scaled RSSI to 0 .. RSSI_MAX_VALUE before storing it.
