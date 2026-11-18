# Sensor alignment reply reads before the gyro device entries when no gyro is enabled

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-17). Finding F363, `DESIGN.md` D796. Not reported upstream.

## Betaflight

`MSP_SENSOR_ALIGNMENT` takes its gyro alignment from `gyroDeviceConfig(firstEnabledGyro())`. `firstEnabledGyro` returns -1 when no gyro is enabled, and the accessor indexes its array with that value. The reply's first two bytes are then a byte that lies before the gyro device entries.

No gyro is enabled when none was detected: `gyroInit` returns before it sets the enabled mask. The firmware goes on without a gyro, with arming disabled, and still answers MSP. This was read from source and not run.

## adaflight

The reply reports the first gyro device entry when no gyro is enabled.

## Proposed change for Betaflight

Use entry 0 when `firstEnabledGyro` returns a negative value.
