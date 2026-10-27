# The USB device address is ORed into its register

Betaflight 2026.12 (master as of 2026-10-26). Finding F295, `DESIGN.md` D409. Not reported upstream.

## Betaflight

The OTG driver of the F4 targets sets the device address by ORing it into the controller's device
configuration register without clearing the field first. A bus reset clears the field, so the first address
request after a reset takes effect. A second address request in the addressed state, which USB 2.0 allows,
leaves the bits of both addresses in the field, and the device then answers at an address the host never
assigned.

## adaflight

The driver clears the address field and writes the new address into it.

## Proposed change for Betaflight

Clear the device address field before setting it, as the later HAL driver does.
