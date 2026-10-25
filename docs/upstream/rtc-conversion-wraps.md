# Clock conversions wrap in 2038 and 2068

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Findings F91 and F104, `DESIGN.md` D74. Not reported upstream.

## Betaflight

The clock keeps milliseconds since 1970 in a 64-bit count, but both conversions pass through a signed 32-bit count of seconds. A date converts to a time through an unsigned count of the seconds since 2000 plus the 1970 offset, stored in 32 signed bits, so a date from 19 January 2038 on wraps negative and reads back as a date in 1901. A time converts to a date through the seconds since 2000 in 32 signed bits, so a time from 19 January 2068 on wraps negative and the remainders that follow give a day, an hour and a minute outside their ranges. The zone offset passes through the same 32-bit seconds. Read from the source; a host build of the unit read a time in 2070 back as a date with a day of 58 and an hour of 251.

## adaflight

Both conversions count the seconds in 64 bits, and the zone offset adds its milliseconds to the time directly. The clock and OSD vectors were recorded from a host build of Betaflight's units with the same counts, with a tenth of the clock's set dates between 2038 and 2099 and the OSD's dates up to 2099.

## Proposed change for Betaflight

In dateTimeToRtcTime, hold the seconds in an int64_t and build the time from it without the 32-bit make helper; in rtcTimeToDateTime, hold the seconds in an int64_t; in dateTimeWithOffset, add the offset in milliseconds to the time.
