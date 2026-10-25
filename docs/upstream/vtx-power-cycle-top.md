# VTX power cycle never reaches the highest level

Betaflight 2026.12 (master as of 2026-10-25). Finding F71, `DESIGN.md` D85. Not reported upstream.

## Betaflight

The power cycle command wraps the next power index to one when it reaches the level count. Power indices run from one to the count, so the top level, whose index equals the count, is skipped: a four-level table cycles through one, two and three. The cycle serves the RTC6705 button. Read from the source; reproduced in the VTX control oracle.

## adaflight

The cycle wraps to one when the next index passes the level count, so the top level takes its turn. The VTX control vectors were recorded from a host build of Betaflight's control with the same comparison.

## Proposed change for Betaflight

In the power cycle, wrap to one when the next power index is above the level count, not when it equals it.
