# SmartAudio queued commands share one buffer per kind

Betaflight 2026.12 (master as of 2026-10-25). Finding F65, `DESIGN.md` D84. Not reported upstream.

## Betaflight

The SmartAudio driver queues a pointer to the frame buffer of each command, and the settings query, the frequency set, the mode set, the band and channel set, the power set and the pit power frame each rebuild one static buffer per call. Two requests of the same kind between two task calls leave two queue entries pointing at one buffer with the later bytes, so the first request goes out twice with the second's content. Read from the source; reproduced in the SmartAudio oracle by a double band and channel request.

## adaflight

Each queue entry holds its own frame bytes, so a request goes out as it was built whatever follows it. The SmartAudio, VTX control and VTX status vectors were recorded from a host build of Betaflight's driver with the queue entries holding copies.

## Proposed change for Betaflight

In the command queue entry, replace the buffer pointer with a seven-byte array and copy the frame into it when the command is queued.
