# STK500v2 read of 253 bytes always fails

Betaflight 2026.12 (master as of 2026-10-25). Finding F252, `DESIGN.md` D316. Not reported upstream.

## Betaflight

The 4-way interface's STK500v2 reader rejects a reply whose length has a low byte below 1. The protocol answers a memory read with a body of the command, its status, the data and a second status byte, so a read of 253 bytes has a body of 256 bytes, a length of 0x0100 and a low byte of 0. The reader drops that valid reply and the read fails. Observed in the STK500v2 oracle: in a run of clean flash reads of 250 to 255 bytes, every read succeeded except those of 253 bytes.

## adaflight

The reader rejects a 16-bit length below 2, the command and status bytes every body holds, and accepts 0x0100. The STK500v2 vectors were recorded from a host build of Betaflight's reader with the same check.

## Proposed change for Betaflight

Check the 16-bit length against 2 once both of its bytes are read, in place of the low byte check.
