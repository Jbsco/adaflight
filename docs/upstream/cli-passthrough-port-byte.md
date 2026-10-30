# Passthrough port number as a byte

Betaflight 2026.12 (master as of 2026-10-27). Finding F308, `DESIGN.md` D521. Not reported upstream.

## Betaflight

The serialpassthrough command assigns the number it parses for a port to a port identifier, an enumeration the
board compiler stores in a signed byte since it holds a value for none, and tests the stored value for a sign. A
port of 2147483647 fails the parse as port -1, and a port of 256 reads as the first UART and opens it. A host
build with four-byte enumerations keeps the full number and reports an invalid port.

## adaflight

The command keeps the number at its full width and reports a number outside the identifiers as an invalid port.

## Proposed change for Betaflight

Parse into an int and check the range before storing the identifier.
