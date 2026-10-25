# A failed BMP388 detection leaves the end of conversion interrupt enabled

Betaflight 2026.12 (master as of 2026-10-25). Finding F254, `DESIGN.md` D321. Not reported upstream.

## Betaflight

With an end of conversion pin configured, the BMP388 detection enables the pin's interrupt and handler before it reads the chip identity. When the identity does not match, it releases the select pin and clears a default address, but leaves the interrupt. The BMP085 detection releases its pin and interrupt on the same failure. The automatic search tries the BMP388 before the BMP280 and the chips after it, so a chip found later runs with the BMP388 handler attached to the pin, which reads register 0x11 of that chip at each rising edge. No board configuration in the configuration repository defines the pin. Read from the source. The BMP388 oracle shows the two missing release calls in every case with the pin and another identity.

## adaflight

A detection that finds another identity releases the end of conversion pin and its interrupt before it releases the bus, as the BMP085 detection does. The BMP388 vectors were recorded from a host build of Betaflight's driver with the same release.

## Proposed change for Betaflight

Release the pin and its interrupt in the identity failure path of the BMP388 detection, before the bus deinit.
