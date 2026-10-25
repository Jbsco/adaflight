# FrSky SPI D8 hub telemetry stalls on a full buffer

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F122, `DESIGN.md` D115. Not reported upstream.

## Betaflight

The FrSky SPI D8 receiver collects a hub telemetry burst in a 64-byte buffer and sends it ten bytes a frame. The writer keeps at most 64 bytes, so a burst of 64 bytes or more leaves the count at 64. The send position wraps at 64, so it never equals that count, the count is never cleared, no new burst is generated, and the receiver resends the same 64 bytes from then on. A full hub cycle with GPS, battery and time values runs to 114 bytes. Reproduced with a host build of the receiver: with every sensor present and a GPS fix, the eighth hub cycle filled the buffer and it stayed full for the rest of the sequence.

## adaflight

The send position counts to the buffer's end, and the burst completes when the position reaches the count or the end, so a full buffer clears for the next burst. The D8 receiver vectors were recorded from a host build of Betaflight's receiver with the same send loop.

## Proposed change for Betaflight

In the send loop, increment `telemetryBytesSent` without the mask and end the burst when it reaches `telemetryBytesGenerated` or `MAX_SERIAL_BYTES`.
