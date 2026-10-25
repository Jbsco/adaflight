# OSD timer alarm wraps past seventy-one minutes

Betaflight 2026.12 (master as of 2026-10-25). Finding F107, `DESIGN.md` D102. Not reported upstream.

## Betaflight

The timer element and the alarm update multiply the timer's alarm minutes, an int, by 60000000 in int arithmetic. From 36 minutes the product passes the signed range, which the compiled code wraps into the intended unsigned count; from 72 minutes the thirty-two-bit result is the count less a multiple of 2^32, so an alarm of 72 minutes becomes 25 seconds, and the timer blinks and shows critical almost at once. Observed in the OSD element oracle under random alarms.

## adaflight

The alarm is computed in sixty-four bits and compared with the thirty-two-bit timer value, so an alarm the timer cannot reach never fires. The OSD element, render, warnings element and statistics vectors were recorded from a host build of Betaflight's elements with the same computation.

## Proposed change for Betaflight

Compute the alarm time as a 64-bit product of the alarm minutes and 60000000, in both the timer element and the alarm update, and compare the timer value with it.
