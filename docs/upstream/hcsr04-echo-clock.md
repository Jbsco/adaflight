# HC-SR04 reports hardware failure after 71.6 minutes

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F273, `DESIGN.md` D356. Not reported upstream.

## Betaflight

The HC-SR04 echo interrupt stamps the end of a pulse with the microsecond clock divided by 1000, and the update compares that stamp with the millisecond clock of the last trigger. Both clocks count the same system tick, but the microsecond clock wraps every 2^32 microseconds, 71.58 minutes, while the millisecond clock runs for 49.7 days. After the first wrap the stamp lies below the trigger time by 4294967 ms per wrap, the valid window test fails, the unsigned difference exceeds 60 ms, and every update reports a hardware failure until the millisecond clock wraps as well. A rising edge more than 2^31 microseconds before its falling edge, possible between 35.8 and 71.6 minutes of uptime, gives a negative travel time, since the unsigned difference lands in a signed 32-bit count, and a negative distance that the update does not catch. Read from the source; not reproduced on hardware.

## adaflight

The echo interrupt stamps the end of a pulse with the millisecond clock and keeps a pulse only when its falling edge follows the rise by less than 2^31 microseconds. The HC-SR04 vectors were recorded from a host build of Betaflight's driver with the same stamp and guard.

## Proposed change for Betaflight

In the echo interrupt handler, read the millisecond clock in place of the microsecond time over 1000, and accept a pulse only while its length fits a signed 32-bit count.
