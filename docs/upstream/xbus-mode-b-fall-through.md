# XBUS Mode B frames fall through into the RJ01 unpacker

Betaflight 2026.12 (master as of 2026-10-25). Finding F35, `DESIGN.md` D46. Not reported upstream.

## Betaflight

When a Mode B frame completes, the receive path unpacks it and then falls through, under a TODO comment, into the RJ01 outer-frame unpacker. That unpacker accepts the frame when its second byte reads 30 and the Dallas CRC-8 over the frame matches its last byte, and then unpacks the bytes from offset 3 as an inner Mode B frame with its own CRC-16, reading past a 27-byte frame's end into the stale tail of the 35-byte buffer. The second byte of a Mode B frame is the high byte of the first channel word, which stays below 16 for the twelve-bit words receivers send, so the path needs a frame with an out-of-range first word and two matching checksums. When it is taken, the channels take values from the middle of the frame and the stale bytes. Read from the source; reproduced in the XBUS oracle with a built frame pair.

## adaflight

The Mode B case ends at its own unpack. The XBUS vectors were recorded from a host build of Betaflight's receiver with the fall-through replaced by a break, and each Mode B sequence contains a frame pair built to take the fall-through.

## Proposed change for Betaflight

End the Mode B case of the frame completion switch with a break in place of the fall-through into the RJ01 unpacker.
