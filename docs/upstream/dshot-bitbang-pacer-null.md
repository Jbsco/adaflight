# Bit-banged pacer search on an empty slot

Betaflight 2026.12 (master as of 2026-10-27). Finding F311, `DESIGN.md` D533. Not reported upstream.

## Betaflight

The bit-banged DShot driver searches a pacer timer channel for each of its four port group slots and rejects a
channel an earlier slot has. That check reads each earlier slot's timer, and a slot that found no pacer holds a null
timer. The check runs for every candidate, so once a slot comes up empty, for example with the TIM1 setting and a
TIM1 channel held by the LED strip, the next slot reads through the null pointer. On an STM32 the read at address 0
lands on the boot alias of flash, gives no timer number, and the check passes. A host build, or a part without memory
at address 0, faults.

## adaflight

A slot without a pacer is left out of the check.

## Proposed change for Betaflight

Test the earlier slot's timer before reading it.
