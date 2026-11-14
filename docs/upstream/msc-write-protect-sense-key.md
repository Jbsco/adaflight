# Mass storage reports a protected storage under sense key NOT READY

Betaflight 2026.12 (master as of 2026-10-08). Finding F341, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In both copies of ST's mass storage class, WRITE(10) to a write-protected storage keeps sense key NOT READY with code WRITE PROTECTED. SCSI pairs that code with key DATA PROTECT. Betaflight's flash log disk is write-protected, so this is its answer to any host write.

Reproduced on a host build of F4's copy: REQUEST SENSE after that write returned key 2 with code 0x27.

## adaflight

That failure is kept under key DATA PROTECT. Vectors were recorded from a host build with that change.

## Proposed change for Betaflight

Add DATA_PROTECT (0x07) to usbd_msc_scsi.h and use it in SCSI_Write10's write protect branch, in both copies.
