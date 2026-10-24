# Headfree mode deflects the sticks past full scale

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F284, `DESIGN.md` D375. Not reported upstream.

## Betaflight

Headfree mode turns the roll and pitch commands, and yaw outside the level and hold modes, by the headfree attitude. The turn keeps the length of the command vector, so full roll and full pitch turned by 45 degrees put about 707 on one axis, a stick deflection of 1.41 where the deflection is meant to stay within -1 to 1. Nothing rescales it. With Actual rates at their defaults (center 70, max 670, expo 0) the rate reaches about 1290 deg/s against the configured 670 deg/s maximum. With Betaflight rates at an RC rate of 1.0 and a super rate of 0.70 it runs to the rate limit, 1998 deg/s by default. Runaway takeoff detection, the mixer, feedforward, EZ landing and the position hold deadband also read the deflection. This was found in the source, not on hardware.

## adaflight

When the largest ratio of a turned command to its divider passes one, the turned commands are divided by that ratio together and each is held to its divider. The stick direction is kept and no deflection passes one. The RC vectors were recorded from a host build of Betaflight's RC module with the same scaling.

## Proposed change for Betaflight

After the headfree turn, divide the turned commands by their largest ratio to their dividers when that ratio passes one, then hold each command to its divider.
