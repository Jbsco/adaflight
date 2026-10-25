# MAVLink reboot over a receiver link is acknowledged and never run

Betaflight 2026.12 (master as of 2026-10-25). Finding F116, `DESIGN.md` D111. Not reported upstream.

## Betaflight

A PREFLIGHT_REBOOT_SHUTDOWN command sets a pending reboot and is acknowledged as accepted. Only the owned port's drain runs the pending reboot, after it has read the port's waiting bytes. With a MAVLink receiver, the telemetry task dispatches the ground station's messages from the receiver's queue instead and the shared port is not owned, so the drain never runs and the reboot stays pending. The ground station sees the acknowledgement and no reboot. In the command oracle, each of the three receiver queue sequences accepts a reboot and ends with it still pending, with no motor shutdown or reset call.

## adaflight

Both drain paths end with the pending reboot step, the port's drain and the receiver's queue dispatch, so a reboot accepted over the receiver link goes out as a reboot request at the end of that pass. The command vectors were recorded from a host build of Betaflight's telemetry with the reboot step at the end of both paths.

## Proposed change for Betaflight

Move the pending reboot block of the port drain into a function of its own and call it at the end of both the port drain and the receiver queue dispatch.
