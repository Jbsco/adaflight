# A feature prefix takes the first feature it starts

Betaflight 2026.12 (master as of 2026-10-25). Finding F154, `DESIGN.md` D170. Not reported upstream.

## Betaflight

The feature command matches its text as a prefix of each feature name and stops at the first match, because its loop runs only while nothing is found. The count of matches never passes one, so the multiple match error the command defines cannot print, and a short prefix selects whichever feature comes first in bit order: `feature R` enables RX_PPM, and `feature -` with nothing after the minus disables RX_PPM. Observed in the command line oracle.

## adaflight

The feature command counts every feature name the text starts. One match enables or disables that feature, two or more are the multiple match error, and none is the invalid name error. The feature vectors were recorded from a host build of Betaflight's command line with the same count.

## Proposed change for Betaflight

Run the match loop over every feature name instead of stopping at the first match, so the count reaches the multiple match error.
