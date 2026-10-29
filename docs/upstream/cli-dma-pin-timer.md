# DMA pin outside the timer map

Betaflight 2026.12 (master as of 2026-10-27). Finding F306, `DESIGN.md` D521. Not reported upstream.

## Betaflight

The dma command's pin form takes the pin's timer from the timer map. For a pin without a map entry that timer is a
null pointer, and the option listing and the option check read the timer and the channel through it. On an STM32
the reads at address 0 land on the boot alias of flash, match no timer channel, and the command lists nothing or
refuses the option. A host build, or a part without memory at address 0, faults.

## adaflight

A pin without a timer map entry lists no option, and every option is refused for it.

## Proposed change for Betaflight

Test the timer before the reads.
