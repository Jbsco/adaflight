# A mass storage write of no blocks waits for a data packet

Betaflight 2026.12 (master as of 2026-10-08). Finding F342, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In both copies of ST's mass storage class, WRITE(10) with a block count of 0 and a transfer length of 0 passes its checks, enters its data out state and asks its out endpoint for 0 bytes. A host has no data to send and waits for a status wrapper. SCSI defines that command as valid with no data.

Reproduced on a host build of F4's copy: no status wrapper went out until a packet arrived.

## adaflight

A write of no blocks gets its status wrapper at once. Vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In SCSI_Write10, after its length check, set a reply length of 0 and return when its block count is 0.
