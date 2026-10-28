# A transmitter's menu close leaves the OSD held when the menu moved there

Betaflight 2026.12 (master as of 2026-10-27). Finding F301, `DESIGN.md` D468. Not reported upstream.

## Betaflight

A Crossfire transmitter opens the menu on its own screen with a display port command and closes it with
another. The close exits the menu with the transmitter's display, whatever display the menu shows on. The exit
releases the display it is given. The menu stick command moves an open menu to the next display and releases
the one it leaves. A menu opened from the transmitter, moved to the OSD with the sticks and then closed from the
transmitter releases the transmitter's display a second time and leaves the OSD's display held. The OSD draws
nothing of its own while its display is held, so it keeps showing the last menu frame. The exit also clears the
menu's arming block, so the craft can arm with the OSD frozen.

## adaflight

The transmitter's close leaves the menu through the menu's exit on the display the menu shows on, which
releases that display. After the move and the close, the OSD draws its elements again.

## Proposed change for Betaflight

Exit with the current display in the CRSF display port's close, as the other exits do.
