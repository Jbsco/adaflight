# GPS over MSP never recovers after a loss

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F62, `DESIGN.md` D80. Not reported upstream.

## Betaflight

With the GPS provider set to MSP, the GPS task moves from its initialized state to receiving data when the first solution arrives over MSP. After 2.5 s without a solution it counts a loss and enters the baud detection state, which configures the serial port. The MSP provider has no port, so that step returns at once and the state never changes again. The next solutions over MSP are stored, and the loss counter stops, but the task stays in detection and never reports the GPS as receiving data again. The virtual GPS provider handles the same case by leaving the detection state when fresh data arrives. This was found in the source and reproduced in a host build of the GPS task.

## adaflight

The MSP provider leaves the detection state as well as the initialized state when a solution arrives. The GPS link vectors were recorded from a host build of Betaflight's GPS task with the same transition.

## Proposed change for Betaflight

In the MSP branch of the GPS update, move to the receiving state from the baud detection state as well as from the initialized state, as the virtual GPS branch does.
