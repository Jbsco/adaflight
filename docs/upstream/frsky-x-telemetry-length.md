# FrSky X telemetry processing reads past its slot for a long length byte

Betaflight 2026.12 (master as of 2026-10-25). Finding F318, `DESIGN.md` D636. Not reported upstream.

## Betaflight

A FrSky X receiver copies each received telemetry slot from its packet: a length byte and five data bytes. Its frame processing hands data bytes to its SmartPort reader while their index is below that length byte. That length comes from a transmitter and can be anything up to 255, so a length above five reads a slot's processing flag, following slots and, from slot 3, memory past its slot array. Those bytes reach the SmartPort reader as received telemetry.

## adaflight

A slot gives at most its five data bytes, whatever its length byte claims. The FrSky X vectors draw lengths from zero to five, where both agree.

## Proposed change for Betaflight

Stop each slot's walk at the smaller of its length byte and its five data bytes.
