# DShot capture decode of codes outside the GCR alphabet

Betaflight 2026.12 (master as of 2026-10-27). Finding F310, `DESIGN.md` D523. Not reported upstream.

## Betaflight

The timer DShot driver decodes a motor's telemetry reply through a table of the 32 five-bit codes that maps the
sixteen codes outside the GCR alphabet to zero, and the nibble checksum alone judges the word. A damaged reply whose
group lands on such a code decodes with a zero nibble there and passes whenever the checksum of the nibbles still
holds. The bitbang driver's decoder marks the same sixteen codes invalid and rejects the word. In the capture oracle's
2000 drawn replies, the timer driver's table kept 12 damaged or random words as values.

## adaflight

The capture decode uses the bitbang decoder's table and check, and rejects a word with a code outside the alphabet.

## Proposed change for Betaflight

Mark the sixteen codes invalid in the timer driver's table and reject a word with one, as the bitbang decoder does.
