# BMI270 accelerometer is not read in the experimental filter mode

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F285, `DESIGN.md` D376. Not reported upstream.

## Betaflight

With the gyro hardware filter set to EXPERIMENTAL, the BMI270 driver reads the gyro from the chip's FIFO at 6.4 kHz. Only the register read's first call moves the read mode on from its initial value, and the FIFO path never makes that call. In the initial mode the accelerometer read does nothing and reports success, so the accelerometer reads zero for the whole flight, although the driver configures it and powers it. Every target offers the setting. This was found in the source and a host build of the driver, not on hardware.

## adaflight

The driver takes the interrupt-driven read mode at initialization in the experimental setting, so the accelerometer read makes its transfer. The scheduler and the status output handle the two modes the same way. The BMI270 vectors were recorded from a host build of Betaflight's driver with the same change.

## Proposed change for Betaflight

Set the interrupt-driven read mode at the end of the BMI270 configuration when the FIFO mode is on.
