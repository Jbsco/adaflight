# DMA table's SDIO entry without the group

Betaflight 2026.12 (master as of 2026-10-27). Finding F305, `DESIGN.md` D521. Not reported upstream.

## Betaflight

The command line's DMA option table names the SDIO group for every build, while the SDIO group registers only in a
build with an SDIO card. On a board without SDIO, the dump's dma section and the dma command look the group up,
get no registry entry, and read the group's address through the null pointer. On an STM32 the read at address 0
lands on the boot alias of flash, and the dump prints an option read from the vector table. A host build, or a
part without memory at address 0, faults.

## adaflight

The dma command and the dump's dma section list no SDIO device, since the configuration has no SDIO group.

## Proposed change for Betaflight

Leave a table entry whose group the build lacks out of the dump, and report its device as bad in the dma command.
