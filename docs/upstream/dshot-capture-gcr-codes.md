# DShot capture decode of codes outside GCR alphabet

Betaflight 2026.12 (master as of 2026-10-27). Finding F310, `DESIGN.md` D523. Not reported upstream.

## Betaflight

Timer DShot decodes a motor's telemetry reply through a table of all 32 five-bit codes that maps sixteen codes outside
GCR alphabet to zero, and its nibble checksum alone judges a word. A damaged reply whose group lands on such a code
decodes with a zero nibble there and passes whenever its nibble checksum still holds. Bit-banged DShot's decoder marks
those sixteen codes invalid and rejects such a word. In 2000 replies drawn by a capture oracle, timer DShot's table
kept 12 damaged or random words as values.

## adaflight

Capture decode uses bit-banged DShot's table and check, and rejects a word with a code outside GCR alphabet.

## Proposed change for Betaflight

Mark those sixteen codes invalid in timer DShot's table and reject a word holding one, as bit-banged DShot does.
