# OSD maximum distance statistic wraps past 32767 metres

Betaflight 2026.12 (master as of 2026-10-25). Finding F105, `DESIGN.md` D100. Not reported upstream.

## Betaflight

The OSD statistics keep the greatest home distance of a flight in a signed sixteen-bit field, filled from an unsigned sixteen-bit distance. A home distance from 32768 metres on stores negative, the comparison against it then accepts every later distance, and the statistics page prints the distance with a minus sign. Observed in the OSD statistics oracle under random distances.

## adaflight

The statistics keep the maximum distance unsigned, so a distance to 65535 metres records and prints as it is. The OSD statistics, task and page vectors were recorded from a host build of Betaflight's OSD with the field unsigned.

## Proposed change for Betaflight

Declare the maximum distance statistic as uint16_t, the type of the distance it is filled from.
