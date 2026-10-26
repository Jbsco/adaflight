# A MAX7456 full refresh after a font write never returns

Betaflight 2026.12 (master as of 2026-10-26). Finding F255, `DESIGN.md` D322. Not reported upstream.

## Betaflight

A font character write sets the driver's font loading flag and nothing clears it. The draw call skips its work while the flag is set and returns whether its screen position is past the start, and the full refresh repeats the draw call until it returns false. When the last draw pass stopped mid-screen, the position never moves again and the refresh loops forever. The display port's redraw runs that refresh whenever the craft is disarmed, so a font upload while disarmed can stop the flight controller. Observed in the MAX7456 oracle: 10 of its first 66 cases hung in such a refresh after a font write until the generator stopped choosing it.

## adaflight

The font character write is one synchronous call, so the driver keeps no font loading flag: drawing goes on after a font write and a full refresh ends. The MAX7456 and display port vectors were recorded from a host build of Betaflight's driver that clears the flag at the end of the write, and the chip generator takes full refreshes after font writes.

## Proposed change for Betaflight

Clear the font loading flag at the end of the NVM write, after the busy wait.
