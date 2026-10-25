# Tramp temperature reply leaves the driver in the temperature state

Betaflight 2026.12 (master as of 2026-10-25). Finding F74, `DESIGN.md` D86. Not reported upstream.

## Betaflight

The Tramp driver queries the temperature after each settings reply and waits for the answer in a temperature monitor state. The temperature reply handler sets the state to the temperature monitor state it is already in, against its own comment, which says it returns to the settings monitor. The return happens only when the 200 ms request period passes without a reply, so the settings monitor waits one period after every temperature reply. Read from the source; reproduced in the Tramp oracle.

## adaflight

A temperature reply returns the driver to the settings monitor at once. The Tramp, VTX control and VTX status vectors were recorded from a host build of Betaflight's driver with the same return.

## Proposed change for Betaflight

In the temperature monitor state's reply branch, set the state to the frequency, power and pit mode monitor state, as the comment says.
