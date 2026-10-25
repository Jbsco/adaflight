# AK8975 and AK8963 use the fuse ROM sensitivity whether or not its read went through

Betaflight 2026.12 (master as of 2026-10-25). Finding F266, `DESIGN.md` D344 and D347. Not reported upstream.

## Betaflight

The AK8975 initialization declares its sensitivity buffer without a value, reads the fuse ROM into it without checking the read's answer, and sets each axis gain to the byte plus 128. The AK8963 does the same. Both initializations return true. A fuse ROM read the bus refuses leaves the buffer's prior stack contents as the gains, anywhere from 128 to 383, so each axis is scaled by an arbitrary factor from 0.5 to 1.5 for the rest of the flight with nothing reported. The read comes right after a detection that read the chip's identity over the same bus, so a refusal at that point is unlikely but not excluded. Read from the source. Both oracles answered every fuse ROM read until this change.

## adaflight

Both initializations report failure when the fuse ROM read is refused, so the caller can leave the compass out of the active sensors. The AK8975 and AK8963 vectors were recorded from host builds of Betaflight's drivers with the same check, with the fuse ROM read refused in a drawn share of the cases.

## Proposed change for Betaflight

Check the fuse ROM read's return in both initializations and return false when it fails. The compass initialization already clears the sensor on a false return.
