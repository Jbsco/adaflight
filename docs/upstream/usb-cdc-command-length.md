# CDC class requests move their full length through an 8-byte buffer

Betaflight 2026.12 (master as of 2026-10-26). Finding F290, `DESIGN.md` D408. Not reported upstream.

## Betaflight

The CDC class of the F4 USB device library answers a device-to-host class request, such as GET_LINE_CODING,
by filling its command buffer and sending the request's length from it. It arms a host-to-device request's
data stage for the request's length into the same buffer. The buffer holds 8 bytes. A GET_LINE_CODING with a
length of 255 sends 247 bytes of the memory behind the buffer, and a class request with a long data stage
writes each packet's bytes past it, since the receive path copies the whole packet.

## adaflight

A class request's data stage is cut to the 8-byte command buffer in both directions, and the receive path
copies no more than the armed length. A line coding request of 7 bytes is unchanged.

## Proposed change for Betaflight

Cut the data stage to the buffer with `MIN(req->wLength, CDC_CMD_PACKET_SZE)`, as the later HAL CDC class does
with its own buffer.
