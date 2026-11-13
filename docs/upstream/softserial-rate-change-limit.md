# Software serial rate change applies no rate limit

Betaflight 2026.12 (master as of 2026-10-08). Finding F328, `DESIGN.md` D739. Not reported upstream.

## Betaflight

openSerialPort refuses a software serial port at a rate above 19200, unless a build defines USE_OVERRIDE_SOFTSERIAL_BAUDRATE. softSerialSetBaudRate sets a time base for any rate.

A GPS search steps its port through 9600, 19200, 38400, 57600, 115200 and 230400 with gpsSetBaudRate. A GPS opened on a software serial port at 9600 is therefore taken to rates its open refuses. At 230400 that port's timer overflows 230400 times a second, each time with its bit handler's work. Read from source. Not run on hardware.

## adaflight

A rate change above 19200 leaves an open software serial port at its rate. No vector covers it: adaflight's engine has no rate, and its board driver applies that limit.

## Proposed change for Betaflight

In softSerialSetBaudRate, return without a change for a rate above that limit, under the same build switch as openSerialPort's check.
