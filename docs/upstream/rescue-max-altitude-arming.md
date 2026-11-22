# A rescue's maximum altitude can take the altitude from before arming

Betaflight 2026.12 (master as of 2026-10-08). Finding F371, `DESIGN.md` D876. Not reported upstream.

## Betaflight

GPS rescue keeps a running maximum altitude for its MAX_ALT return mode. While disarmed it sets that maximum to zero, and from its first armed pass it takes whichever of maximum and control altitude is larger. Control altitude keeps updating while disarmed, and position estimation zeroes it only when its own task sees an arm transition. Rescue runs on its own schedule, so a rescue pass between arming and that position task reads a disarmed altitude and keeps it as its maximum.

Such a rescue returns at home altitude plus that disarmed altitude plus its initial climb. On a board the disarmed altitude is barometer drift since boot. Under a simulator's Gazebo bridge it is the feed's absolute altitude: with 1600 m fed, MSP_ALTITUDE read 938 m while disarmed on Betaflight's SITL build and 941 m on adaflight's host image before this change. Host image lost that race on most runs and staged a rescue plan returning 951 m above home.

## adaflight

Boards give their rescue an altitude of zero until position estimation has handled the current arm state, which is what its reset gives.

## Proposed change for Betaflight

Have updateMaxAltitude skip passes before positionUpdate has seen an arm transition, for example by reading a flag that positionUpdate sets after positionEstimatorResetZ.
