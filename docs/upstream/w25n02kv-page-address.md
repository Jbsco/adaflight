# W25N02KV upper-half pages address the lower half

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F267, `DESIGN.md` D348. Not reported upstream.

## Betaflight

The W25N flash driver's chip table gives the W25N02KV 2048 blocks of 64 pages, 131072 pages, whose addresses need 17 bits. The table also marks the chip as taking a dummy byte before its 16-bit page address, and the page address commands (block erase, program execute and page data read) then send 0 in the byte after the instruction and only the page's low 16 bits. The W25N02KV datasheet (revision M) gives these commands a 24-bit page address with PA16 to PA0 in its low bits. A page in the chip's upper half therefore erases, programs and reads the page 65536 below it, so the second gigabit is unusable and writes meant for it overwrite the first. This was found in the source and the datasheet, not on hardware.

## adaflight

The driver sends the page's bits 16 to 23 in the byte after the instruction for every chip, which is 0 for the chips with 65536 pages or fewer. The W25N vectors were recorded from a host build of Betaflight's driver with the same byte.

## Proposed change for Betaflight

Send bits 16 to 23 of the page address in the first address byte for the W25N02KV instead of a zero dummy byte.
