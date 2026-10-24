# Tab completion lists commands that do not match

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F286, `DESIGN.md` D378. Not reported upstream.

## Betaflight

The command line's tab completion walks the command table once and keeps the first and the last entry whose name starts with the typed text. It then extends the text while the first and the last names agree and, when they differ, lists every name from the first to the last. The walk assumes the table is sorted, and the table keeps `battery_profile` after `play_sound`. A typed `b` matches batch, beacon, beeper, bind_rx, bl, board_name and battery_profile, so the extension stops at `bat` instead of `b`, and the list runs from batch to battery_profile: 38 names, 31 of which do not match. Observed in the command line oracle; not reproduced on hardware.

## adaflight

The completion extends the typed text while every matching name agrees and lists only the matching names. The terminal vectors were recorded from a host build of Betaflight's command line with the same completion.

## Proposed change for Betaflight

Move `battery_profile` to its alphabetical place in the command table, which the help output's order would follow, or collect the matching names in the completion instead of the range between the first and the last match.
