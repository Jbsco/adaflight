# MSP jumbo reply in the combined framing puts its size after the version 2 header

Betaflight 2026.12 (master as of 2026-10-25). Finding F43, `DESIGN.md` D53. Not reported upstream.

## Betaflight

A reply in the version 2 over version 1 framing places the version 2 header right after the version 1 header and advances the header length past it before it tests the jumbo limit, so a reply whose version 1 payload reaches 255 bytes goes out as the start, the size byte 255, the command byte 255, the five version 2 header bytes, then the two jumbo size bytes. The version 1 framing places the jumbo size right after the version 1 header. A decoder that follows the version 1 layout, as the configurator's does, reads the two bytes after the command byte as the jumbo size, which in such a reply are the version 2 flags and the low command byte. Betaflight's own decoder drops any version 1 size over its 192-byte receive buffer, so the jumbo marker never reaches it. Read from the source; reproduced in the MSP serial oracle.

## adaflight

The encoder writes the jumbo size right after the version 1 header and the version 2 header after it, as in the version 1 framing. The MSP serial vectors were recorded from a host build of Betaflight's encoder with the same order.

## Proposed change for Betaflight

In the combined framing branch of the reply encoder, compute the version 1 payload size and place the jumbo header before taking the version 2 header's position, so the version 2 header follows the jumbo size.
