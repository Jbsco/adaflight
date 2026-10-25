# RunCam request parser parks after an unsupported request

Betaflight 2026.12 (master as of 2026-10-25). Finding F77, `DESIGN.md` D62. Not reported upstream.

## Betaflight

The camera's request parser reads the byte after the header as the command. A command other than the attitude request sets the parser state to the header byte's value, which no state of the parser handles, so every later byte is dropped. The reset after 200 ms without bytes clears the context and sets the command state, so the first byte after a gap is read as a command, and a header byte there sends the parser back to the unhandled state. After one unsupported request, or a camera reply that arrives after its request timed out, the camera's attitude requests go unanswered until a gap of 200 ms falls between a header and its command byte. Observed in the RunCam device oracle: in three of ten sequences the parser parked between step 108 and step 173 of 1000 and stayed parked to the end.

## adaflight

An unsupported command returns the parser to the header state, and so does the 200 ms reset. The RunCam device vectors were recorded from a host build of Betaflight's device unit with the same transitions.

## Proposed change for Betaflight

Set the waiting-header state after an unsupported command and after the 200 ms reset, as the reset's comment says.
