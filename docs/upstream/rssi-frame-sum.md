# Frame-error RSSI sum wraps above 64 good frames per window

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F30, `DESIGN.md` D40. Not reported upstream.

## Betaflight

The RSSI from frame errors adds the full RSSI value of 1023 for every good frame over a 100 millisecond window and divides the sum by the count of receiver polls at the window's end. The sum is a 16-bit variable, so it holds 64 good frames. Past 64 good frames in a window the sum wraps and the RSSI reads a fraction of its value that moves with the frame rate. The SBUS driver is the one driver that selects this source, when `rssi_src_frame_errors` is on, and SBUS delivers under 150 frames per second, so no current link reaches the wrap. A driver on this source above 640 good frames per second would reach it. Read from the source; not reproduced on hardware.

## adaflight

The sum holds up to 65535 good frames of full RSSI and the poll count stops at 65535, so the mean of a window is exact at any frame rate. The receiver vectors were recorded from a host build of Betaflight's receiver with the sum widened to 32 bits, with eight sessions on this source at 500 to 1500 microsecond poll intervals.

## Proposed change for Betaflight

In setLinkQuality, declare rssiSum as uint32_t.
