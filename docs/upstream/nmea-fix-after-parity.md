# NMEA fix state changes before the sentence is checked

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F53, `DESIGN.md` D79. Not reported upstream.

## Betaflight

The NMEA decoder parses each field of a sentence as its separator arrives and compares the parity only when the sentence ends. The GGA sentence's quality field sets or clears the GPS fix state at once, as the field arrives, while the position, satellite count and altitude of the same sentence are written only after the parity matches. A corrupted GGA sentence, or a stray quality field in line noise, therefore changes the fix state although its values are discarded, and the fix can flap with no change at the module. This was found in the source and reproduced in a host build of the GPS task.

## adaflight

The decoder keeps the quality field with the sentence's other values and sets the fix state from it once the parity matches, before the values are written. The GPS link vectors were recorded from a host build of Betaflight's GPS task with the same order.

## Proposed change for Betaflight

Store the GGA quality field in the sentence's data structure during field parsing, and set the fix state from it in the GGA case of the sentence-end handler, before the values are copied.
