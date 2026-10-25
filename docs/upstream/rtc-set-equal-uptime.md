# A clock set to the uptime reads as unset

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F95, `DESIGN.md` D74. Not reported upstream.

## Betaflight

The clock stores the set time less the millisecond uptime and treats a stored zero as no time. A time set equal to the uptime stores zero, so the clock reports no time until the next set. Read from the source; a host build of the unit shows it on two percent of the sets its generator draws.

## adaflight

The clock keeps a flag that a set raises, and the flag alone says whether the clock has a time. The clock vectors were recorded from a host build of Betaflight's unit with the same flag.

## Proposed change for Betaflight

Keep a `rtcIsSet` flag that rtcSet raises and return it from rtcHasTime.
