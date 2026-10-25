# SDIO card read failures loop or report the wrong operation

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F278, `DESIGN.md` D368. Not reported upstream.

## Betaflight

When a block read on the SDIO card driver times out or the card reports an error, the poll jumps back to the reading state without a reset or a completion, so it loops until the controller reports the block and the card ready; the SPI card driver resets the card and reports the failure. When the controller refuses to start a read, the driver resets the card and calls the completion with the pending operation's block and data, which belong to the previous operation, since the new ones are stored only when the controller accepts. Read from the source; not reproduced on hardware.

## adaflight

A read that times out or fails resets the card and reports the failure through the read's completion, and a refused read reports the failure through the completion of the read asked for. The SDIO card vectors were recorded from a host build of Betaflight's driver with the same handling.

## Proposed change for Betaflight

In the poll's receive error case, reset the card and call the pending operation's completion with a null buffer before continuing; in the read's refused path, call the completion given to the read with its block index.
