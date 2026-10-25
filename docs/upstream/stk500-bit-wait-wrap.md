# STK500v2 bit read waits forever when its deadline is the clock's last value

Betaflight 2026.12 (master as of 2026-10-25). Finding F251, `DESIGN.md` D316. Not reported upstream.

## Betaflight

The 4-way interface's STK500v2 reader times each bit against a deadline 250 microseconds after the bit's start and waits for each edge while the clock is not above the deadline. When the deadline is the clock's last value, 0xFFFFFFFF, no reading of the clock exceeds it, so a line without edges holds the wait until an edge comes. A deadline just past the 32-bit wrap is a small value the clock already exceeds, so that wait ends at once and the bit fails. Observed in the STK500v2 oracle: a sign-on without a reply, started at each microsecond from 9.5 to 11.5 ms before the wrap, hung in 4 of 2001 runs, each stopped after 20 s of simulated time.

## adaflight

The wait fails once the signed 32-bit difference of the clock and the deadline is positive, so a deadline at the clock's last value times out as any other and a deadline past the wrap keeps its length. The STK500v2 vectors were recorded from a host build of Betaflight's reader with the same test.

## Proposed change for Betaflight

Time out while the signed 32-bit difference of the clock and the deadline is positive, in both edge waits.
