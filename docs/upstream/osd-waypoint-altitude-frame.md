# The waypoint altitude element shows the craft's altitude in its sea-level variants

Betaflight 2026.12 (master as of 2026-10-26). Finding F206, `DESIGN.md` D231. Not reported upstream.

## Betaflight

A stored waypoint's altitude is in centimetres above mean sea level. The waypoint altitude element hands it to the altitude formatter, whose third and fourth variants replace the altitude they are given with the craft's altitude above sea level, so those variants show the craft's altitude, not the waypoint's. The first and second variants show the stored sea-level value in the place where the craft's altitude element shows an altitude above the launch point. Observed in the waypoint oracle: in metric, third variant, with the executor at a waypoint stored at 1496.83 m, the element shows 746.7 m, the craft's altitude above sea level.

## adaflight

The altitude formatter takes the frame of the altitude it is given. The waypoint element's sea-level variants show the stored altitude, and its launch point variants show the stored altitude less the launch point's altitude above sea level, the craft's altitude above sea level less its estimated altitude. The craft's altitude element is unchanged. The waypoint vectors were recorded from a host build of Betaflight's elements with the same formatter, and their generator scripts the craft's estimated altitude.

## Proposed change for Betaflight

Give the altitude formatter the frame of its argument and convert between the launch point and sea-level frames through the craft's altitude above sea level less its estimated altitude, instead of replacing the argument.
