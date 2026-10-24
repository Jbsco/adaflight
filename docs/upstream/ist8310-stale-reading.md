# IST8310 reports its last reading as new after a data-ready timeout

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F264, `DESIGN.md` D341. Not reported upstream.

## Betaflight

The IST8310 driver reads in three steps: it polls the status register until data is ready, reads the six data bytes and triggers the next single measurement. After 15 polls without data ready it moves to a separate trigger step. That step writes the trigger and reports a new reading, although it has read no data, so the compass task takes the axes of the previous reading as a fresh sample. With every status read answered, this repeats every 17 calls while the chip reports no data. The trigger step was meant for a trigger the bus refused right after a data read, where the data was fresh and not yet reported. This was found in the source and reproduced in a host build of the driver.

## adaflight

The read step reports its reading whether or not its trigger goes out, and the trigger step reports none. The IST8310 vectors were recorded from a host build of Betaflight's driver with the same reporting.

## Proposed change for Betaflight

Return true from the data read step even when the trigger write cannot start, and return false from the trigger step.
