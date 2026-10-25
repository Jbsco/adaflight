# BMP085 uses 22 uninitialized bytes as its calibration when the read is refused

Betaflight 2026.12 (master as of 2026-10-25). Finding F272, `DESIGN.md` D352. Not reported upstream.

## Betaflight

The BMP085 driver reads its 22 calibration bytes into an uninitialized stack buffer without checking the read's answer, and builds every coefficient from that buffer. The detection calls the read after the identity check passed and returns found. A refused calibration read, which the I2C bus can give after a successful identity read, leaves whatever the stack held as the coefficients, including the divisors ac4 and md, so every pressure and temperature from then on is computed from arbitrary values, and a zero ac4 divides by zero in the pressure compensation, which the ARM processor answers with zero and the driver never checks. Read from the source. The BMP085 oracle answered every calibration read until this change.

## adaflight

A refused calibration read fails the detection the way a wrong identity does: the conversion-end pin and its interrupt are released, the clear pin is driven low and a default address is taken back. The BMP085 vectors were recorded from a host build of Betaflight's driver with the same check, with the calibration read refused in a drawn share of the cases.

## Proposed change for Betaflight

Return the calibration read's answer from the calibration routine and take the detection's failure path when it is false.
