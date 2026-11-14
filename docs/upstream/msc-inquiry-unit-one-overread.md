# A mass storage inquiry for unit 1 sends memory past its inquiry data

Betaflight 2026.12 (master as of 2026-10-08). Finding F346, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In both copies of ST's mass storage class, a command wrapper passes its check with unit 0 or 1, while Betaflight's storages have one unit. SCSI_Inquiry reads its reply at 36 bytes times that unit into a storage's inquiry data and takes its length from byte 4 there plus 5.

Reproduced on a host build of F4's copy. An inquiry for unit 1 sent 36 bytes that follow its inquiry data in memory, and one with an allocation length of 115 sent 114 bytes. A host can read up to 260 bytes that follow that table in a board's flash.

## adaflight

A command wrapper for any unit but 0 is not valid. Vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In MSC_BOT_CBW_Decode, compare bLUN with a storage's GetMaxLun result.
