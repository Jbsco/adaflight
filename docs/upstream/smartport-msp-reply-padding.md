# SmartPort MSP reply pads with stack bytes

Betaflight 2026.12 (master as of 2026-10-08). Finding F315, `DESIGN.md` D571. Not reported upstream.

## Betaflight

Shared MSP reply code hands each chunk to a link callback with its length, and a last chunk is shorter than six bytes when fewer reply bytes remain. SmartPort's callback copies only that length into a payload struct on its stack, sets its frame id and writes all six payload bytes to the line. Bytes past that length are whatever its stack held, so a receiver reads padding that differs from run to run. Most replies end in a short chunk: an API version reply is three header bytes and three payload bytes in its first chunk, then a one-byte chunk of its sequence number followed by five stack bytes.

## adaflight

`SmartPort_Telemetry` writes each reply chunk from a buffer zeroed past its length, so a short last chunk reads as its bytes then zeros. Vectors come from a copy of SmartPort's source whose callback zeroes its payload struct before copying.

## Proposed change for Betaflight

In SmartPort's MSP response callback, zero its payload struct before copying a chunk into it.
