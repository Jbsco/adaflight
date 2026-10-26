# MSP restart into mass storage with UTC time skips the file system check

Betaflight 2026.12 (master as of 2026-10-25). Finding F199, `DESIGN.md` D223. Not reported upstream.

## Betaflight

The MSP restart message answers the mode back and, for the mass storage mode, checks that the mass storage file system is ready, answers the readiness after the mode, and restarts only when it is ready. The mass storage mode with UTC time takes neither the check nor the answer: it restarts at once, and the restart handler resets into mass storage for both modes. Observed in the command line oracle with the file system scripted as not ready: mode 2 answers 2 then 0 and does not restart, mode 3 answers 3 and restarts.

## adaflight

Both mass storage modes answer the readiness and restart only when the file system is ready. The MSP control vectors were recorded from a host build of Betaflight's MSP handler with the same check.

## Proposed change for Betaflight

Test for either mass storage mode before the file system check in the restart message.
