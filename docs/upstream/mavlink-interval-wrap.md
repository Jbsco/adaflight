# MAVLink message interval reads back short above 4294967 ms

Betaflight 2026.12 (master as of 2026-10-25). Finding F115, `DESIGN.md` D110. Not reported upstream.

## Betaflight

The MESSAGE_INTERVAL reply converts a stream message's interval from milliseconds to microseconds in 32-bit unsigned arithmetic and saturates at INT32_MAX only when that product compares above it. An interval above 4294967 ms wraps before the comparison, so a long interval reads back as a short one. A SET_MESSAGE_INTERVAL of 5000 s stores 5000000 ms and reads back as 705032704 µs. In the telemetry oracle, GPS_GLOBAL_ORIGIN set to 2195816385 ms read back as 1088096744 µs where INT32_MAX was due.

## adaflight

The reply compares the milliseconds against INT32_MAX / 1000 first and multiplies only when the product fits, so every interval above 2147483 ms reads back as INT32_MAX. The telemetry vectors were recorded from a host build of Betaflight's telemetry with the same comparison, with interval sets at the saturation and wrap edges.

## Proposed change for Betaflight

In the message interval getter, compare the milliseconds with INT32_MAX / 1000 and multiply only at or below it. Above it, return INT32_MAX.
