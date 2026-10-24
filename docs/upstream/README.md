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
