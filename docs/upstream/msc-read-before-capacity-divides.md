# A mass storage read of no blocks before a capacity request divides by zero

Betaflight 2026.12 (master as of 2026-10-08). Finding F344, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In both copies of ST's mass storage class, block size and block count are set only by READ CAPACITY(10) and start at 0. READ(10) with a block count of 0 passes its range check against a block count of 0 and reaches SCSI_ProcessRead, which divides by block size. On a Cortex-M that division gives 0, or a usage fault where divide traps are on. Hosts read capacity first.

Reproduced on host builds of both copies: each stopped with a divide error on that command as a first command.

## adaflight

Block size is a constant 512. Vectors were recorded from a host build that starts with that block size.

## Proposed change for Betaflight

Read capacity in MSC_BOT_Init, or refuse a read or write while block size is 0.
