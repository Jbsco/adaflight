# Mass storage reports success for a block its SD card failed

Betaflight 2026.12 (master as of 2026-10-08). Finding F350, `DESIGN.md` D756. Not reported upstream.

## Betaflight

STORAGE_Read and STORAGE_Write for an SD card over SPI pass no callback to their card driver and return 0 after their polls. That driver reports a failed read or write only through its callback, then resets its card, which is ready again after its start. A block that a card failed to read reaches a host as whatever its transfer buffer had, with a passed status. A failed write is reported as written.

Reproduced on a host build of that storage code over a stand-in card that fails one block. A failed read returned 0 with its buffer unchanged, and a failed write returned 0 with its card's block unchanged. Not measured on a card.

## adaflight

Raw reads and writes take that driver's completion, and a failed block fails its command.

## Proposed change for Betaflight

Pass a callback that records a NULL buffer, and return -1 from STORAGE_Read and STORAGE_Write when it did.
