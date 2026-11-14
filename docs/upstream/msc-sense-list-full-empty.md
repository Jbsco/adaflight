# A full mass storage sense list reads as empty

Betaflight 2026.12 (master as of 2026-10-08). Finding F343, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In both copies of ST's mass storage class, SCSI_SenseCode adds to a ring of four entries and moves its tail with no check against its head. REQUEST SENSE reads that ring as empty when head equals tail. After four failures with no sense request between them, tail is back at head.

Reproduced on a host build of F4's copy: four refused commands, then REQUEST SENSE returned key 0.

## adaflight

A list that fills drops its oldest entry. Vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In SCSI_SenseCode, advance head when tail reaches it.
