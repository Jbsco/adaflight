# Mass storage address range check wraps at 32 bits

Betaflight 2026.12 (master as of 2026-10-08). Finding F340, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In both copies of ST's mass storage class, SCSI_CheckAddressRange adds a command's block address and block count in 32 bits before it compares that sum with a storage's block count. An address near 2^32 wraps to a small sum and passes.

Reproduced on a host build of F4's copy. READ(10) of block 0xFFFFFFFF, 1 block, passed on a 5000 block storage and reached its storage read. F7's copy has that same expression, read from source.

## adaflight

That sum is taken in 64 bits. Vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In SCSI_CheckAddressRange, widen blk_offset to 64 bits before its addition, in both copies.
