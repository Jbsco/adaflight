# F7 mass storage status residue wraps on a short transfer

Betaflight 2026.12 (master as of 2026-10-08). Finding F338, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In F7's copy of ST's mass storage class, MSC_BOT_SendData cuts a reply to a host's transfer length, then subtracts its uncut length from a status wrapper's residue. F4's copy subtracts what it sends.

Reproduced on host builds of both copies. An inquiry for supported pages with a transfer length of 0 left a residue of 4294967289 on F7's copy and 0 on F4's.

## adaflight

A short reply reduces that residue by what was sent.

## Proposed change for Betaflight

In F7's MSC_BOT_SendData, subtract length, not len, from csw.dDataResidue.
