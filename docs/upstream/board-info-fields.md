# The signature command takes spaces and signs, and a stored board name refuses the name that set it

Betaflight 2026.12 (master as of 2026-10-25). Findings F175 and F176, `DESIGN.md` D183. Not reported upstream.

## Betaflight

The signature command copies each two-character pair into a buffer and reads it as a base 16 number, accepting the pair when the reading ends after both characters. The number reader skips a leading space and takes a sign, so the pairs ` a`, `+f` and `-1` pass, and `-1` stores 0xff. Observed in the command line oracle: `signature 7fb9743a-10e564...` sets the signature `7fb9743aff0e564...`. The board name store keeps the first 20 characters of a name, and the board name command refuses a name for stored information when its length or characters differ from the stored name. After a long name is stored, the same full name is the `BOARD_NAME CANNOT BE CHANGED` error. The manufacturer id behaves the same at 4 characters.

## adaflight

A signature pair is two hexadecimal digits, and any other character is the invalid character error. A board name or manufacturer id for stored information is compared cut to the length the store keeps, so the name that set it is accepted again. The board information vectors were recorded from a host build of Betaflight's command line with the same reading and comparison.

## Proposed change for Betaflight

Accept a signature pair only when both characters are hexadecimal digits, and compare a stored board name or manufacturer id with the new one cut to the stored length.
