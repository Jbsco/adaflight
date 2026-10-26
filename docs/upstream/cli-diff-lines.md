# A diff never resets the mixes, formats a failsafe default by the wrong mode and compares a VTX band without its flag

Betaflight 2026.12 (master as of 2026-10-26). Findings F169, F173 and F174, `DESIGN.md` D181. Not reported upstream.

## Betaflight

The diff resets the live configuration to its defaults before it prints, then decides the `mmix reset` line from the live first motor's throttle and the `smix reset` line from the live first servo rule's rate. Both hold the defaults, which are empty, so a diff never prints either reset line, and replaying it onto a board with a longer custom mix or more servo rules keeps the board's entries past the diff's last line. The channel failsafe printer picks the line format from the channel's current mode and uses it for the default line too, so a channel set to `s` shows its default as `#rxfail 3 a 875`, a line the `rxfail` command refuses. The VTX table band comparison takes the name, the letter and the frequencies but not the factory flag, so a diff leaves out a band whose only change is the flag, and the default lines of the power values and labels print all eight entries whatever the default power level count. Observed in the command line oracle for the reset lines, the failsafe format and the eight entries; the flag case is read from the source.

## adaflight

A diff decides the reset lines from the stored mix and rules, a channel failsafe default line takes the format of the default's mode, the band comparison includes the factory flag, and the default power lines print the default power level count. The command line vectors with diffs were recorded from a host build of Betaflight's command line with the same decisions.

## Proposed change for Betaflight

Decide the reset lines from the stored copies, pick the failsafe default line's format from the default's mode, compare the factory flag, and format the default power lines with the default power level count.
