# A MAX7456 found by a later rescan keeps a display port of 0 rows and 0 columns

Betaflight 2026.12 (master as of 2026-10-25). Finding F259, `DESIGN.md` D323. Not reported upstream.

## Betaflight

When the MAX7456 does not answer at initialization, the display port initialization returns before it sets the port's rows and columns. A later readiness check with rescan initializes the chip and redraws, but leaves the rows and columns at 0. The MSP OSD configuration request runs that rescan, for example once a battery powers an OSD chip that USB does not. The OSD task waits for the port to be ready, then completes its initialization with a middle row and column of 0, registers the port with the menu system and skips its canvas check. Observed in the MAX7456 display port oracle: all 41 cases whose chip powered up after initialization and was then found kept 0 rows and 0 columns.

## adaflight

The readiness check with rescan sets the rows and columns as the initialization does, through one helper, before it redraws. The MAX7456 display port vectors were recorded from a host build of Betaflight's display port with the same helper.

## Proposed change for Betaflight

Move the rows and columns computation of the display port initialization into a helper and call it on the rescan path after the chip initializes.
