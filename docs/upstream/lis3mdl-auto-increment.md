# LIS3MDL six-byte read lacks the auto-increment bit

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F265, `DESIGN.md` D342. Not reported upstream.

## Betaflight

The LIS3MDL driver reads its six data bytes in one transfer from register 0x28. The LIS3MDL datasheet (DocID024204) states for I2C that the seven low bits of the sub-address give the register and the most significant bit enables address auto-increment, and that reading multiple bytes requires that bit. For SPI it states that with the MS bit at 0 the address stays unchanged in multiple read commands. The driver sets neither bit, and the bus layer adds only the SPI read bit. The chip then answers its X low byte for all six bytes, so every axis reads the same byte pair. The Linux kernel's driver enables multi-byte reads for this chip for the same reason. This was found in the source and the datasheet, not on hardware.

## adaflight

The driver sets the auto-increment bit in the read address, the top bit on I2C and the MS bit on SPI. The LIS3MDL vectors were recorded from a host build of Betaflight's driver with the same addresses.

## Proposed change for Betaflight

Set bit 7 of the data register address for an I2C read and bit 6 for an SPI read in the LIS3MDL driver's six-byte read.
