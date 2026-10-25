# Longitude differences overflow across the antimeridian

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F58, `DESIGN.md` D80, D81, D88, D230. Not reported upstream.

## Betaflight

The distance and bearing between two positions and the ENU distance vector both take the longitude difference as a 32-bit subtraction of ten-millionths of a degree. The distance vector then corrects a difference past 180 degrees by two steps of 180 degrees, since 360 degrees in ten-millionths overflows a 32-bit integer; the distance and bearing have no correction. The subtraction itself overflows for any two longitudes more than 214.7 degrees apart, which every crossing of the antimeridian is, so the correction never sees the true difference. The east distance comes out thousands of kilometres off, and with it the distance to home, the rescue's heading, the position estimate and the navigation map. Read from the source; not reproduced on hardware.

## adaflight

The longitude difference is taken in 64 bits and folded to half a turn either way before it is scaled, in the GPS link, the GPS lap timer, the position estimator and the OSD navigation map. The GPS link, position estimator, lap timer, navigation map and flight plan vectors were recorded from a host build of Betaflight's distance functions with the same fold, and some of the GPS link, position estimator and lap timer runs start within 60 m of the antimeridian and cross it.

## Proposed change for Betaflight

Take the longitude difference as a 64-bit integer, fold it by 360 degrees when it passes 180 degrees either way, and narrow it to 32 bits, in both the distance and bearing and the distance vector.
