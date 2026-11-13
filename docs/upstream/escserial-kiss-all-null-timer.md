# KISS passthrough on every motor sets up a null timer when no motor timer can be taken

Betaflight 2026.12 (master as of 2026-10-08). Finding F332, `DESIGN.md` D740. Not reported upstream.

## Betaflight

For KISS on every motor, openEscSerial takes each enabled motor's timer with timerAllocate and keeps its last one as bit timer. When timerAllocate returns none for every motor, txTimerHardware keeps its earlier value, null after start, and serialTimerTxConfigBL is called with it. Read from source. Not run on hardware.

## adaflight

That open is refused. ESC serial vectors were recorded from a host build that refuses.

## Proposed change for Betaflight

Return NULL from openEscSerial when outputCount is zero after its motor loop.
