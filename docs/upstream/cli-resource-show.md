# resource show without a second word compares a null pointer

Betaflight 2026.12 (master as of 2026-10-27). Finding F304, `DESIGN.md` D479. Not reported upstream.

## Betaflight

The resource command's show option takes the next word to decide whether to add the timer and DMA lists, and
compares it with "all". For `resource show` alone that word is a null pointer, and the comparison reads through it.
On an STM32 the read at address 0 lands on the boot alias of flash, the comparison fails, and the command prints
its list. A host build, or a part without memory at address 0, faults.

## adaflight

No second word reads as not "all".

## Proposed change for Betaflight

Test the word before the comparison.
