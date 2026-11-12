# Mission protocol does not start on a MAVLink receiver's shared port

Betaflight 2026.12 (master as of 2026-10-08). Finding F325, `DESIGN.md` D730. Not reported upstream.

## Betaflight

configureMAVLinkTelemetryPort calls mavMissionInit when telemetry opens its own port. That call marks no reached waypoint as pending and registers a reached listener with its flight plan executor. checkMAVLinkTelemetryState starts telemetry on a MAVLink receiver's shared port without that call.

On that path mission state is a zeroed static, so its pending reached index reads 0 where mavMissionInit sets -1. A first mavMissionUpdate then sends MISSION_ITEM_REACHED for waypoint 0, though no waypoint was reached. Its listener is never registered there, so no waypoint an executor reaches is reported afterwards.

Reproduced on a host build of mavlink.c and mavlink_mission.c: a first pass over its receiver's queue writes MISSION_ITEM_REACHED with sequence 0 ahead of MISSION_CURRENT.

## adaflight

A mission session starts when telemetry starts on either port. MAVLink port vectors were recorded from a host build that calls mavMissionInit on both paths.

## Proposed change for Betaflight

Call mavMissionInit from checkMAVLinkTelemetryState's shared port branch too, where it sets mavlinkTelemetryEnabled.
