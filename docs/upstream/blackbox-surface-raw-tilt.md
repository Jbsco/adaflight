# The flight log's surfaceRaw field holds the tilt-corrected altitude

Betaflight 2026.12 (master as of 2026-10-27). Finding F299, `DESIGN.md` D460. Not reported upstream.

## Betaflight

The flight log writes the rangefinder's value into the `surfaceRaw` field under a comment that says it stores
the raw value without the tilt correction. The value it takes is the rangefinder's corrected altitude: the
median-filtered distance times the cosine of the craft's tilt, and out of range once the tilt passes the
sensor's cone. The rangefinder keeps the raw distance beside it, with its own getter, which the writer never
calls. A log of a tilted craft records the corrected altitude, and past the cone it records -1 while the
sensor still reads a distance.

## adaflight

The flight log's `surfaceRaw` field holds the rangefinder's distance after the median filter and before the
tilt correction. The altitude the MSP sonar reply carries stays the corrected one.

## Proposed change for Betaflight

Write the rangefinder's raw distance into the `surfaceRaw` field, as the comment and the field name say.
