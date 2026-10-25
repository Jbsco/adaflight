# One NMEA custom command goes out per connection

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F63, `DESIGN.md` D80. Not reported upstream.

## Betaflight

An NMEA module's configuration sends the custom commands from the `gps_nmea_custom_commands` setting, one per step of the baud change state. After sending the command at the stored offset and moving the offset to the next command, the step advances and the link turns to receiving data whether or not commands remain. The next command goes out only after a data timeout restarts the connection, so a setting with several commands configures the module one command per connection. Read from the source; reproduced with a host build of the GPS unit, where a three-command setting sends its second command after the first timeout.

## adaflight

The baud change state keeps its step while commands remain, so the commands go out one every half second and the link turns to receiving after the last. The GPS link vectors were recorded from a host build of Betaflight's unit with the same step.

## Proposed change for Betaflight

In the baud change state, advance the step and set the receiving state only in the branch where no command remains.
