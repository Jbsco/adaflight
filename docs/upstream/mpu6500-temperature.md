# MPU6500 family temperature uses the MPU6000's conversion

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F261, `DESIGN.md` D327. Not reported upstream.

## Betaflight

The MPU6500 driver initializes the MPU-6500, MPU-9250, ICM-20601, ICM-20602 and ICM-20608-G, and gives every one of them the MPU-6000's temperature conversion: 340 counts per degree and 36.53 degrees at a count of zero. InvenSense's register maps give the MPU-6500 and MPU-9250 333.87 counts per degree and 21 degrees at zero, and the ICM-2060x family 326.8 counts per degree and 25 degrees at zero. The Linux inv_mpu6050 driver encodes the same three conversions. With the MPU-6000's constants an MPU-6500 at 25 degrees reads about 60 degrees. The gyro temperature feeds the OSD, telemetry and the flight log. This was found in the source and the register maps, not on hardware.

## adaflight

The driver sets the conversion by chip: 333.87 and 21 for the MPU-6500 and MPU-9250, 326.8 and 25 for the ICM-2060x family. The MPU6500 vectors were recorded from a host build of Betaflight's driver with the same conversions.

## Proposed change for Betaflight

Set tempScale and tempZero in the MPU6500 driver's initialization by the detected sensor: 1/333.87 and 21 for MPU_65xx_SPI and MPU_9250_SPI, 1/326.8 and 25 for the ICM-2060x sensors.
