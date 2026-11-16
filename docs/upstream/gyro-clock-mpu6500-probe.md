# ICM-42688-P clock input skipped behind MPU6500 probe

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-16). Finding F361, `DESIGN.md` D784. Not reported upstream.

## Betaflight

`icm426xxSpiDetect` turns an ICM-42688-P's clock input on. `mpu6500SpiDetect` runs earlier in that probe table and also answers for an ICM-42688-P's identity, with that chip's own sensor code. On a build with both drivers that first probe ends detection. `icm426xxSpiDetect` never runs, so that chip keeps its own oscillator and its clock pin stays undriven.

No board configuration with `USE_GYRO_CLKIN` builds an MPU6500 driver today, so released boards are not affected.

## adaflight

Board gyro code turns that clock on after either probe finds an ICM-42688-P. A host image builds every gyro driver, and its smoke test showed this fault before that change.

## Proposed change for Betaflight

Turn that clock input on after detection, wherever an ICM-42688-P's sensor code is known. Dropping ICM426xx identities from `mpu6500SpiDetect` would also do it.
