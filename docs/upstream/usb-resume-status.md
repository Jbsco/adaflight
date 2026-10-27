# A USB resume marks the device configured

Betaflight 2026.12 (master as of 2026-10-26). Finding F292, `DESIGN.md` D408. Not reported upstream.

## Betaflight

The F4 USB device library saves the device status when the bus suspends and, on resume, restores it and then
sets the device configured. The suspend also saves the status when the device is already suspended. A device
suspended while addressed or in its default state resumes as configured without a configuration, so it
refuses a later address request and accepts class requests.

## adaflight

A suspend saves the status unless the device is already suspended, and a resume restores it.

## Proposed change for Betaflight

Save the status only when the device is not suspended and restore it on resume, as the later HAL library
does.
