# The AK8963 detection turns a shared I2C bus into an MPU slave bus

Betaflight 2026.12 (master as of 2026-10-26). Finding F263, `DESIGN.md` D337. Not reported upstream.

## Betaflight

The compass detection sets the configured I2C bus through a function-static array, which gives every device on one I2C bus the same bus structure. When the scan reaches the AK8963 case and the gyro is an MPU9250 on SPI, the detection writes the MPU slave type and the gyro as master into that structure before the AK8963 probe, and nothing writes the I2C type back when the probe fails. The compass drivers after it probe on the MPU slave type with the address the last failing driver left, since the per-driver address reset applies only to the I2C type, and the generic bus transfers return false for the retyped bus, so a barometer on the same bus stops reading. Two board configurations build an MPU9250 gyro with the compass and the barometer on the first I2C bus. Observed in the compass detection oracle; the barometer effect follows from the code and was not observed on hardware.

## adaflight

The scan remembers the bus type before it moves the AK8963 probe onto the MPU slave bus and puts it back when the probe fails, so the drivers after it probe on the configured bus. The compass detection vectors were recorded from a host build of Betaflight's detection with the same restore.

## Proposed change for Betaflight

Save the bus structure before the AK8963 case retypes it and restore it when the probe fails.
