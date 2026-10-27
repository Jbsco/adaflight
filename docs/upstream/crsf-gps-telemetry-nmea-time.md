# CRSF GPS telemetry stays silent with an NMEA module

Betaflight 2026.12 (master as of 2026-10-26). Finding F297, `DESIGN.md` D412. Not reported upstream.

## Betaflight

The CRSF telemetry sends its GPS, GPS time and extended GPS frames when the solution's time differs
from the time of the last frame sent, in every build with the version 3 protocol. The u-blox parsers
set the solution's time from the receiver's time of week. The NMEA parser never sets it, so it stays
at zero, the frames never come due, and a Crossfire or ExpressLRS link with an NMEA module carries no
GPS telemetry. The DroneCAN and virtual providers stamp their solutions with the clock.

## adaflight

The board stamps each solution with the clock as it arrives and gives the telemetry that stamp as the
solution's time, so NMEA and u-blox modules both send their frames. The flight log keeps the module's
own time for its GPS frames.

## Proposed change for Betaflight

Set the solution's time to the clock when an NMEA frame completes a solution, as the DroneCAN and
virtual providers do.
