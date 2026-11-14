# MSP passthrough mode 3 opens KISS on every motor at 19200 baud

Betaflight 2026.12 (master as of 2026-10-08). Finding F334, `DESIGN.md` D744. Not reported upstream.

## Betaflight

escEnablePassthrough picks its rate from its mode argument: 38400 for PROTOCOL_KISS, 18880 for PROTOCOL_CASTLE, 19200 for any other. A command line request for KISS on output 255 arrives as PROTOCOL_KISS, gets 38400, and then becomes PROTOCOL_KISSALL. MSP passthrough mode 3 is PROTOCOL_KISSALL from its start, so it falls to 19200. A KISS ESC, addressed at 38400 on both other KISS paths, then gets its bytes at half that rate. Read from source. Not run on hardware.

## adaflight

Mode 3 opens at 38400. A host image run reads that bit period from its timer log.

## Proposed change for Betaflight

Add PROTOCOL_KISSALL to escEnablePassthrough's BAUDRATE_KISS case.
