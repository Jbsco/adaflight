# OSD warnings reset by a default comparison

Betaflight 2026.12 (master as of 2026-10-27). Finding F309, `DESIGN.md` D521. Not reported upstream.

## Betaflight

The OSD group's reset function sets the default warning bits through the function that writes the live
configuration's warnings, not the instance it was given. A reset of a copy of the group, which the command line
does to print a setting against its default in the serial command and in the setting information reply,
therefore rewrites the live warnings to their defaults. After `set osd_warn_bitmask = 3153447724`, a `serial`
command leaves the warnings at the defaults. A reset of the live group itself, as the dump's backup and reset
does, is unaffected.

## adaflight

Group defaults are values, and printing a setting against its default changes nothing.

## Proposed change for Betaflight

Set the warning bits of the instance in the reset function.
