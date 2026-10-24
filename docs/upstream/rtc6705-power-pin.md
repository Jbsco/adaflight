# RTC6705 with a power pin stays off until a pit mode cycle

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F224, `DESIGN.md` D261. Not reported upstream.

## Betaflight

On a board with an RTC6705 power pin, the board's start drives the pin to the level that powers the transmitter off, while the device layer starts with its pit mode flag clear and reports no pit mode. Only leaving pit mode drives the pin to the powered level, and the VTX settings update leaves pit mode only when the pit mode switch turns off after turning on while disarmed. Without a pit mode switch, or with a pit mode frequency configured, the transmitter stays off from power-up until the pilot cycles pit mode, and the power and frequency writes go to an unpowered chip. Read from the source and the VTX control oracle; not reproduced on hardware.

## adaflight

The device's process powers the transmitter on, waits the boot delay and writes the stored power and frequency when the pit mode is off and the transmitter has not been powered since the start. The VTX control vectors were recorded from a host build of Betaflight's VTX layer with the same process.

## Proposed change for Betaflight

Keep a powered flag in the RTC6705 device layer, set where the transmitter is enabled, and make the device's process take the enable-and-configure path while the flag is clear and pit mode is off.
