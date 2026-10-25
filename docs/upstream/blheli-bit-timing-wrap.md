# BLHeli bootloader bit timing loses its deadline at the microsecond wrap

Betaflight 2026.12 (master as of 2026-10-25). Finding F249, `DESIGN.md` D315. Not reported upstream.

## Betaflight

The 4-way interface's BLHeli bootloader line times each bit against an absolute deadline: a received byte waits until the microsecond clock reaches its start time plus 39 microseconds and then 52 more per bit, and a sent byte waits the same way from its start. Each wait runs while the clock is below the deadline. When a deadline passes the 32-bit wrap of the clock, which comes every 71.6 minutes, the deadline is a small value the clock already exceeds, every wait of that byte ends at once, and the remaining bits go out or get sampled within microseconds. A received byte then reads its start bit in place of its stop bit and fails, so a transfer in progress at the wrap fails once. Observed in the bootloader oracle: of 60 keep-alive exchanges started every 61 microseconds from 3 ms before the wrap, 6 failed, exactly those whose reply byte spans it.

## adaflight

Each wait ends when the signed 32-bit difference of the clock and the deadline turns non-negative, so a wait across the wrap keeps its length. The bootloader vectors were recorded from a host build of Betaflight's bootloader line with the same test.

## Proposed change for Betaflight

Wait while the signed 32-bit difference of the clock and the deadline is negative, in the receive loop and the send loop.
