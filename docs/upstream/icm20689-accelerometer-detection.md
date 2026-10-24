# ICM-20601 and ICM-20608-G get a gyro but no accelerometer

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F262, `DESIGN.md` D329. Not reported upstream.

## Betaflight

The ICM20689 driver's chip probe identifies the ICM-20601, ICM-20602, ICM-20608-G and ICM-20689, and its gyro detection accepts all four. Its accelerometer detection accepts only the ICM-20602 and ICM-20689, so a board with an ICM-20601 or ICM-20608-G flies with its gyro and without an accelerometer: no level modes, no accelerometer-based features, and the configurator shows no accelerometer. All four chips have the same accelerometer registers and the driver already configures them. This was found in the source, not on hardware.

## adaflight

The accelerometer detection accepts all four chips. The ICM20689 vectors were recorded from a host build of Betaflight's driver with the same acceptance.

## Proposed change for Betaflight

Add the ICM-20601 and ICM-20608-G cases to the accelerometer detection's switch.
