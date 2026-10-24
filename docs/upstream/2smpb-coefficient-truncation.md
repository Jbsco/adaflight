# 2SMPB-02B pressure coefficient truncated to a whole number

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F274, `DESIGN.md` D357. Not reported upstream.

## Betaflight

The 2SMPB-02B driver scales eight of its nine calibration coefficients in single precision, each a float literal times the register value over 32767. The ninth, bp, is scaled as 10 times the register value over 32767 plus 30, with the 10 written as an integer, so the product and the quotient are integer arithmetic and the quotient is truncated to a whole number between -10 and 10 before the 30 is added. The coefficient therefore loses its fraction, which shifts the compensated pressure by up to a few hundredths of a percent of the quadratic term. This was found in the source, not on hardware.

## adaflight

The driver scales bp in single precision like the other eight coefficients. The 2SMPB-02B vectors were recorded from a host build of Betaflight's driver with the same scaling.

## Proposed change for Betaflight

Write the literal as 10.0f in the bp coefficient's scaling.
