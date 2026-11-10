# MSP passthrough runs while armed and from a telemetry link

Betaflight 2026.12 (master as of 2026-10-08). Findings F322 and F323, `DESIGN.md` D699. Not reported upstream.

## Betaflight

MSP_SET_PASSTHROUGH starts serial forwarding, the BLHeli 4-way interface or an ESC serial link once its reply went out. None of these returns to normal processing, and a 4-way request stops all motors before its reply. MSP_REBOOT is refused while armed. MSP_SET_PASSTHROUGH has no such test, so a request from any MSP client in flight stops flight control.

A request through a telemetry link's MSP tunnel is processed as a serial one. After its reply, that link calls what the request left to run with no serial port. Serial forwarding returns at once. A 4-way request has already stopped all motors, and its loop and an ESC serial link's loop then read a port that does not exist.

Read from source; not reproduced on hardware.

## adaflight

A passthrough request while armed, or from a telemetry link, is answered with 0 and starts nothing. Motors and their pins stay as they were. Passthrough vectors were recorded from a host build of Betaflight's MSP processing with that refusal added.

## Proposed change for Betaflight

Before mspFcSetPassthroughCommand runs, write a reply of 0 and return when ARMING_FLAG(ARMED) is set or the request's descriptor is getMspTelemetryDescriptor().
