# BMP388 pressure reads 2.56 times too low

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F253, `DESIGN.md` D321. Not reported upstream.

## Betaflight

The BMP388 driver's pressure compensation is Bosch's 64-bit integer routine, which returns the pressure in hundredths of a pascal. The driver divides that result by 256 and reports the quotient as pascals, so the reported pressure is 100/256 of the true value. The driver's unit test expects 39535 Pa from a sample that compensates to 10121128 hundredths, which is 101211 Pa, a sea-level pressure. The altitude comes from the reported pressure through the barometric formula, so on a BMP388 or BMP390 board an altitude change reads at about 0.84 of its size. This was found in the source and a host build of the driver, not on hardware.

## adaflight

The driver divides the compensated pressure by 100 and reports pascals. The BMP388 vectors were recorded from a host build of Betaflight's driver with the same division.

## Proposed change for Betaflight

Divide the compensated pressure by 100 instead of 256 in the BMP388 driver's calculation, and change the unit test's expected pressure to 101211.
