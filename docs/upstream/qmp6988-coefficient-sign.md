# QMP6988 calibration coefficients read unsigned

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F271, `DESIGN.md` D351. Not reported upstream.

## Betaflight

The QMP6988 driver builds its ten 16-bit calibration coefficients (a1, a2, bt1, bt2, bp1, b11, bp2, b12, b21, bp3) from two OTP bytes without sign extension, so each lies between 0 and 65535. It sign-extends only the two 20-bit coefficients a0 and b00. The vendor's driver, as published in the M5Stack unit library, casts all ten to signed 16-bit values. A coefficient with its top bit set therefore enters the compensation 65536 too high, which moves the compensated pressure by an amount that depends on the chip's calibration. This was found in the source, not on hardware.

## adaflight

The driver reads the ten coefficients as signed 16-bit values. The QMP6988 vectors were recorded from a host build of Betaflight's driver with the same reading.

## Proposed change for Betaflight

Cast each of the ten 16-bit coefficients to a signed 16-bit value when it is assembled from its two bytes.
