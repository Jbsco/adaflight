# Transponder provider change over MSP

Betaflight 2026.12 (master as of 2026-10-15). Finding F195, `DESIGN.md` D736. Not reported upstream.

## Betaflight

A transponder configuration message stores a requested provider, then compares it with its stored one to stop a repeating transmission when they differ. After that store both are equal, so no stop ever runs. Its IR driver took a coding and a timer's counting rate and carrier from its provider at boot, and it encodes new data with them. After a provider change through this message a board sends new code in its boot provider's coding and on that carrier until a restart. Read from source, not run on hardware.

## adaflight

A write for a provider other than one already set up sets that timer up again for its coding and loads its code. Transmission goes on.

## Proposed change for Betaflight

Compare a requested provider with its stored one before storing, and on a change set up that IR driver again.
