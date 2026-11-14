# F7 mass storage class reports refused SCSI commands as passed

Betaflight 2026.12 (master as of 2026-10-08). Finding F336, `DESIGN.md` D750. Not reported upstream.

## Betaflight

Betaflight builds two copies of ST's mass storage class, one for F4 boards and one for F7 and later boards. In F7's copy, SCSI_ProcessCmd calls each command's function and drops its result. Only an unknown command returns a failure. F4's copy returns each result.

Reproduced on a host build of F7's usbd_msc_bot.c and usbd_msc_scsi.c over stand-in endpoint and storage calls. A write to a write-protected storage got a status wrapper with a passed result and no endpoint halt. TEST UNIT READY on a storage that was not ready got a passed result. A refused command with a nonzero transfer length sent bytes of an earlier reply. Betaflight's flash log disk is write-protected, so any host write there takes this path.

## adaflight

Mass storage engine returns each command's refusal. A refused command halts its endpoints and ends with a failed status. Vectors were recorded from a host build of F4's copy.

## Proposed change for Betaflight

In F7's SCSI_ProcessCmd, return each command function's result, as F4's copy does.
