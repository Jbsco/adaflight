# The waypoint capture message clears only when the OSD reads it

Betaflight 2026.12 (master as of 2026-10-26). Finding F207, `DESIGN.md` D232. Not reported upstream.

## Betaflight

The capture module sets its message to expire 2.5 s after the edit, and only the OSD's read clears it, once the wrapping difference from the expiry is no longer negative. The warnings line reads the message only when no higher warning has returned first. A message left unread for 2^31 µs, 35.8 minutes, past its expiry has a negative difference again and shows for up to another 35.8 minutes, for example after a long RSSI LOW or while the warnings element is hidden. Observed in the warnings oracle: a WP FULL message whose expiry was 3201 s before the frame shows, and stays valid after the read.

## adaflight

The capture's step clears an expired message before the gesture runs, so a message nobody read ends at its expiry and the OSD's read cannot find it valid again. The capture vectors were recorded from a host build of Betaflight's capture module with the same clearing; two of their sequences leave windows without a read and jump the clock by 2^31 µs after some of them.

## Proposed change for Betaflight

Clear the expired message in the capture update, before the gesture, so the OSD's read is not the only path that ends it.
