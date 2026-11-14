# F7 mass storage class loses every sense code

Betaflight 2026.12 (master as of 2026-10-08). Finding F337, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In F7's copy of ST's mass storage class, a sense entry's union has an ASC and ASCQ byte pair beside a single byte named ASC. SCSI_SenseCode stores its code shifted left by 8 in that single byte, which leaves 0. F4's copy declares that member as an unsigned int, so its shifted code lands in a byte that REQUEST SENSE sends.

Reproduced on host builds of both copies. After an unknown command, REQUEST SENSE byte 12 was 0x20 on F4's copy and 0 on F7's. A host on an F7 board gets a sense key with no reason: medium not present and write protected both read as no additional sense.

## adaflight

Each kept failure has its sense code as its own byte.

## Proposed change for Betaflight

In F7's SCSI_SenseCode, store its code in w.b.ASC and 0 in w.b.ASCQ, and send those two bytes as bytes 12 and 13.
