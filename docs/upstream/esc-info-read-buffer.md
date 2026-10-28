# ESC information read leaves the ESC sensor writing into a dead stack frame

Betaflight 2026.12 (master as of 2026-10-27). Finding F298, `DESIGN.md` D423. Not reported upstream.

## Betaflight

The command line's ESC information command points the ESC sensor's receive buffer at a 64-byte array on
its own stack, sends the information command, waits 10 ms and prints the bytes that arrived. Nothing points
the buffer back when the command returns. The receive interrupt keeps storing bytes until the position
reaches 64, now into stack memory the command line reuses, until the ESC sensor task resets the buffer for
its next poll. The task does nothing while the motors are disabled, and dshotprog keeps them disabled
until its whole line is done. A KISS ESC answers the information command with 15 or 21 bytes, and each
repeat of a later blocking command in the same line asks every motor for telemetry, so the ESCs' telemetry
frames land in the running stack. `dshotprog 0 6 7` with a KISS ESC on the ESC sensor line writes up to
49 bytes over it.

## adaflight

The board keeps the information frame in its ESC sensor package for the length of the read. Bytes received
before the read go to the telemetry frame in flight, bytes during the read fill the information frame, and
bytes after it go back to the telemetry frame.

## Proposed change for Betaflight

Make the information buffer static, or restore the telemetry buffer with its position and size before
the information command returns.
