# Wing SPA modes and yaw type reach PID profile 0 only

Betaflight 2026.12 (master as of 2026-11-02). Finding F316, `DESIGN.md` D613. Not reported upstream.

## Betaflight

In a wing build the settings table declares the three SPA mode settings and yaw type as master values, while their
fields live in the PID profile. The command line adds a profile's offset only to profile values, so get, set, dump and
diff of these four settings always reach profile 0, and a dump lists them once under master. Flight code reads them
from the active profile.

With any other profile active, a pilot's setting changes a profile the controller does not read, and a profile's own
value stays out of reach. Read from the source; reproduced in a wing build of the settings oracle.

## adaflight

These four settings are profile values in the wing build's table, so the command line and MSP setting messages reach
the selected profile and dumps list them in each profile section. The wing vectors were recorded from a wing build of
Betaflight's settings table with that change.

## Proposed change for Betaflight

Declare `spa_roll_mode`, `spa_pitch_mode`, `spa_yaw_mode` and `yaw_type` as profile values in the wing build's
settings table.
