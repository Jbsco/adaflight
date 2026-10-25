# OSD craft name messages keep the old name's last character

Betaflight 2026.12 (master as of 2026-10-25). Finding F111, `DESIGN.md` D106. Not reported upstream.

## Betaflight

With craft name messages on, the warnings element copies its text into the craft name with a bounded copy of fifteen characters into a seventeen-byte name. A text of fifteen or more characters gets no terminator within those fifteen and leaves the sixteenth byte as it was, so a configured sixteen-character name shows the message's first fifteen characters followed by the name's last one. Observed in the OSD warnings element oracle: the message CHIRP Y 2/3 DONE over a sixteen-character name ending in w left CHIRP Y 2/3 DONw.

## adaflight

The element copies its first sixteen characters into the craft name, zero filled after a shorter text, and ends the name with a zero. The warnings element vectors were recorded from a host build of Betaflight's elements with the same copy.

## Proposed change for Betaflight

Copy up to MAX_NAME_LENGTH characters and write the terminator at index MAX_NAME_LENGTH, the last byte of the name.
