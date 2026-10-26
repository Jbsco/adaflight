# A request for several MSP replies wraps the size of a sub-reply past 255 bytes

Betaflight 2026.12 (master as of 2026-10-26). Finding F288, `DESIGN.md` D381. Not reported upstream.

## Betaflight

The multiple-reply command answers a list of out commands in one reply, each sub-reply behind a one-byte
size. The first pass measures each sub-reply into a byte, the size byte included, and takes it off the room
left. The second pass writes the size as the low byte of the sub-reply's length. A sub-reply longer than 255
bytes, the OSD configuration with 99 elements or the adjustment ranges, wraps both: the room accounting
under-counts, so the reply runs past the port's output buffer, and the size byte misframes every sub-reply
after it. A host build of the dispatch answered 19 such requests of 718 with replies of up to 629 bytes from
a 512-byte buffer.

## adaflight

The processor measures each sub-reply in full and answers an error for a request whose sub-reply exceeds
255 bytes, so a reply the client cannot frame is never sent. The configuration view vectors were recorded
from the host build with the same check.

## Proposed change for Betaflight

Measure the sub-reply as an int and answer MSP_RESULT_ERROR when it exceeds 255 bytes, or stop the list
before it.
