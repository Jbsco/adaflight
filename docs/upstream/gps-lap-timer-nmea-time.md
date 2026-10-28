# The GPS lap timer never times a lap with an NMEA module

Betaflight 2026.12 (master as of 2026-10-27). Finding F300, `DESIGN.md` D467. Not reported upstream.

## Betaflight

The GPS lap timer measures laps on the GPS solution's time. A gate pass counts once the solution's time is past
the last lap by the minimum lap time, and a lap is the time between the closest points of two passes. The
u-blox parsers set the solution's time from the receiver's time of week. The NMEA parser never sets it, so with
an NMEA module it stays at zero. The first pass through the gate starts the timer with its last lap at zero,
the minimum lap test never passes again, and no lap is recorded. The current lap element shows 0.00
throughout. The same zero time keeps the CRSF GPS telemetry silent with an NMEA module
([CRSF GPS telemetry stays silent with an NMEA module](crsf-gps-telemetry-nmea-time.md)).

## adaflight

The lap timer and the current lap element take the clock at each solution as the solution's time for an NMEA
module, and the module's time of week otherwise. The flight log keeps the module's own time.

## Proposed change for Betaflight

Set the solution's time to the clock when an NMEA frame completes a solution, as the DroneCAN and virtual
providers do. This one change serves both the lap timer and the CRSF GPS telemetry.
