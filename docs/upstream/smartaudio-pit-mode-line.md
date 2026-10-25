# SmartAudio menu's pit mode kind line cannot reach out-of-range pit mode

Betaflight 2026.12 (master as of 2026-10-25). Finding F221, `DESIGN.md` D254. Not reported upstream.

## Betaflight

The SmartAudio configuration menu names the pit mode kinds `---`, `PIR` and `POR`, but gives the line a maximum of 1, so `POR` is never shown or chosen. The line's function sends out-of-range pit mode only for the value 2, which the line cannot reach. A version 2 device in out-of-range pit mode shows `PIR` on entry, as the responses set the value to 1 for that mode. Read from the source; reproduced in the menu oracle.

## adaflight

The line's maximum is 2, so the third value, `POR`, can be chosen and sends out-of-range pit mode to the device. The menu vectors were recorded from a host build of Betaflight's menu with the same maximum.

## Proposed change for Betaflight

In the SmartAudio configuration menu, give the pit mode kind line a maximum of 2, the last index of its names.
