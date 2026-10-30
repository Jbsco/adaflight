# DMA option number as a byte

Betaflight 2026.12 (master as of 2026-10-27). Finding F307, `DESIGN.md` D521. Not reported upstream.

## Betaflight

The dma command parses its option number into an int and hands it to the DMA lookups, whose option parameter
is a signed byte, then stores it in the group's byte-wide option. An option of 256 passes the lookup as option 0,
the command reports a change to 256, and the group holds 0. Any number equal to a valid option modulo 256
behaves the same way.

## adaflight

The dma command checks the number at its full width and refuses any option outside the device's or the pin's
list.

## Proposed change for Betaflight

Check the parsed number against the option count before the lookups.
