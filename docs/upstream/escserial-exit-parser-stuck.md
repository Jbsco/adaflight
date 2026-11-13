# ESC passthrough exit parser stops after any other MSP request

Betaflight 2026.12 (master as of 2026-10-08). Finding F330, `DESIGN.md` D740. Not reported upstream.

## Betaflight

processExitCommand reads a host's bytes for an MSP request with command 0xF4 and no payload, which ends escEnablePassthrough. A request with a good checksum sets its state to COMMAND_RECEIVED, and only that exit request sets it back to IDLE. No branch reads COMMAND_RECEIVED. After any other well-formed request of up to ten payload bytes it returns false for every later byte, so a passthrough then ends only at a reset.

Reproduced on a host build of serial_escserial.c with drawn host bytes and requests mixed in. Its parser read half of those bytes in COMMAND_RECEIVED and saw 19 exit requests. With that state set back to IDLE it saw 42.

## adaflight

Exit parser returns to idle after any request. ESC serial vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In processExitCommand, set c_state to IDLE after a checked request that is not an exit request.
