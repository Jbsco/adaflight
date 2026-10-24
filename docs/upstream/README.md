# Write-ups for Betaflight

Each document describes a Betaflight bug that adaflight fixes: the Betaflight version it was found in, what Betaflight does and what that causes, what adaflight does instead, and a proposed change for Betaflight.

- [RTC6705 menu turns pit mode on at exit](rtc6705-menu-pit-mode.md)
- [RTC6705 menu stores band 0 at exit](rtc6705-menu-band-zero.md)
- [Deleting an empty file corrupts the FAT](fat-empty-file-delete.md)
- [Headfree mode deflects the sticks past full scale](headfree-deflection.md)
- [BMI270 accelerometer is not read in the experimental filter mode](bmi270-fifo-accelerometer.md)
- [BMP388 pressure reads 2.56 times too low](bmp388-pressure-scale.md)
- [QMP6988 calibration coefficients read unsigned](qmp6988-coefficient-sign.md)
- [LPS22DF temperatures below zero read 655.36 degrees too high](lps22df-temperature-sign.md)
- [2SMPB-02B pressure coefficient truncated to a whole number](2smpb-coefficient-truncation.md)
- [Ghost RSSI below the long-range minimum reads as full strength](ghost-rssi-floor.md)
- [Ghost legacy channel values below the minimum wrap to the top of the range](ghost-channel-floor.md)
- [ICM-20601 and ICM-20608-G get a gyro but no accelerometer](icm20689-accelerometer-detection.md)
- [LIS3MDL six-byte read lacks the auto-increment bit](lis3mdl-auto-increment.md)
- [GPS over MSP never recovers after a loss](gps-msp-recovery.md)
- [IST8310 reports its last reading as new after a data-ready timeout](ist8310-stale-reading.md)
- [NMEA fix state changes before the sentence is checked](nmea-fix-after-parity.md)
- [MPU6500 family temperature uses the MPU6000's conversion](mpu6500-temperature.md)
- [SD card free-cluster search reads the wrong FAT sectors past the free-space file](fat-free-cluster-sector.md)
- [SD card forward seek moves to twice the position](fat-forward-seek.md)
- [W25N02KV upper-half pages address the lower half](w25n02kv-page-address.md)
