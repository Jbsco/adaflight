# Menu runtime flags drop the option string and ticker flags

Betaflight 2026.12 (master as of 2026-10-26). Finding F183, `DESIGN.md` D193, D194 and D254. Not reported upstream.

## Betaflight

The menu draw keeps each row's flags in a byte, copied from the sixteen-bit line flags on every page select. The option string flag, bit eight, and the scrolling ticker flag, bit ten, read from that byte and are therefore never set: a submenu with an option string never shows its value, so the SmartAudio frequency submenus show no frequency, and the ticker flag set into the byte is lost, so a lookup table text longer than its space never scrolls. Observed in the menu oracle's page vectors, where the copied flags hold bits zero to seven only.

## adaflight

The draw keeps each row's flags in sixteen bits. A submenu with an option string shows its line's text before the arrow, the SmartAudio frequency submenus their frequencies in four characters, and a lookup table text longer than its space scrolls, holding 20 draw cycles at each end and 3 between steps. The menu vectors were recorded from a host build of Betaflight's menu with sixteen-bit runtime flags.

## Proposed change for Betaflight

Keep the runtime entry flags in a sixteen-bit array and pass them to the entry draw as such.
