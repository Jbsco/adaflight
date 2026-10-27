# The VCP receive buffer wraps to empty when a packet fills it

Betaflight 2026.12 (master as of 2026-10-26). Finding F291, `DESIGN.md` D408. Not reported upstream.

## Betaflight

The virtual COM port of the F4 targets keeps the bytes from the host in a ring of 2048 bytes. It refuses a
packet only when the waiting bytes plus the packet exceed 2048. A packet that brings the count to exactly
2048 is taken, the ring's in index reaches its out index, and the ring then reads empty. The 2048 waiting
bytes are lost and the stream resumes in the middle of a frame. A host that streams faster than the flight
software reads reaches it.

## adaflight

The ring takes a packet only while it stays one byte short of full, so it holds at most 2047 bytes and never
reads empty with bytes in it. A packet that does not fit is dropped, as the reference drops one past the
size.

## Proposed change for Betaflight

Refuse the packet when the waiting bytes plus the packet exceed `APP_TX_DATA_SIZE - 1`.
