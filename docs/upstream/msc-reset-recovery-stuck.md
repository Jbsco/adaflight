# Mass storage status stays in recovery after a transport reset

Betaflight 2026.12 (master as of 2026-10-08). Finding F345, `DESIGN.md` D750. Not reported upstream.

## Betaflight

In both copies of ST's mass storage class, MSC_BOT_Reset sets a status of recovery. Only a class start, or a cleared halt after a wrapper that is not valid, sets it back to normal. In recovery a refused command halts only its in endpoint, and MSC_BOT_CplClrFeature sends no status wrapper when that halt is cleared.

Reproduced on a host build of F4's copy. After one reset and its two halt clears, a refused write and an unknown command each got an in endpoint halt and, after its clear, nothing. A host then waits for a status wrapper until it times out and resets again.

## adaflight

Recovery ends at a next command wrapper. Vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In MSC_BOT_CBW_Decode, set a status of recovery back to normal before a wrapper is checked.
