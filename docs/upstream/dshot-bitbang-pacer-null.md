# Bit-banged pacer search on an empty slot

Betaflight 2026.12 (master as of 2026-10-27). Finding F311, `DESIGN.md` D533. Not reported upstream.

## Betaflight

Bit-banged DShot searches a pacer timer channel for each of its four port group slots and rejects a channel an earlier
slot has. That check reads each earlier slot's timer, and a slot that found no pacer holds a null timer. The check runs
for every candidate, so once a slot comes up empty, for example with TIM1 chosen and a TIM1 channel held by an LED
strip, a next slot reads through a null pointer. On an STM32 a read at address 0 lands on flash's boot alias, gives no
timer number, and lets the check pass. A host build, or a part without memory at address 0, faults.

## adaflight

A slot without a pacer is left out of the check.

## Proposed change for Betaflight

Test an earlier slot's timer before reading it.
