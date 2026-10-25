# RMC clock request masks the time for its milliseconds

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F54, `DESIGN.md` D79. Not reported upstream.

## Betaflight

When the real-time clock has no time, an NMEA RMC sentence with a date and a time sets the clock. The time field holds hours, minutes, seconds and hundredths as one number, and the millisecond field of the clock set is computed as the time masked with 100, times ten, where a remainder by 100 was meant. The field reads 0 or 1000 and never the hundredths the sentence carries, so the clock starts up to 990 milliseconds off. Read from the source; not reproduced on hardware.

## adaflight

The millisecond field is the remainder of the time by 100, times ten. The GPS vectors with RMC clock sets were recorded from a host build of Betaflight's GPS unit with the same remainder.

## Proposed change for Betaflight

In the RMC branch of the NMEA frame handler, compute `temp_time.millis` as `(data->time % 100) * 10`.
