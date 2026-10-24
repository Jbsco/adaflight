# RTC6705 menu turns pit mode on at exit

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F225, `DESIGN.md` D262. Not reported upstream.

## Betaflight

The PIT line of the RTC6705 video transmitter menu holds 0 for `---`, 1 for `OFF` and 2 for `ON`, and the RTC6705 always reports a status, so the line reads 1 or 2. Leaving the menu passes that raw value to the device's pit mode setter, which turns pit mode on for any value other than 0 and, on a board with a VTX power pin, switches the transmitter off. Leaving the menu with the line at `OFF` therefore puts the transmitter in pit mode. The SmartAudio, Tramp and MSP menus map their pit lines to 0 or 1 before they call their setters.

## adaflight

The menu maps the line to 0 or 1 at the exit, as the other transmitter menus do, so leaving it with the line at `OFF` keeps the transmitter out of pit mode. The menu vectors were recorded from a host build of Betaflight's menu with the same mapping.

## Proposed change for Betaflight

Map the RTC6705 menu's pit line to 1 for `ON` and 0 otherwise before calling the pit mode setter.
