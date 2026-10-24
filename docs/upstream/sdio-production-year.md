# SDIO card production year reads at most 2015

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F278, `DESIGN.md` D368. Not reported upstream.

## Betaflight

The SDIO card driver forms the card's production year from the manufacturing date field of the card identification. The field holds the year offset from 2000 in its upper eight bits and the month in its lower four. The driver ORs the upper nibble of the year with the lower nibble instead of placing it above, so the year offset is at most 15 and the year at most 2015; a card made in 2023, offset 0x17, reads as 2007. Read from the source; not reproduced on hardware.

## adaflight

The production year is 2000 plus the eight year bits of the date field. The SDIO card vectors were recorded from a host build of Betaflight's driver with the same expression.

## Proposed change for Betaflight

Form the year as the date field masked to its year bits and shifted down by four, plus 2000.
