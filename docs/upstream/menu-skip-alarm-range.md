# Dynamic numeric menu rows are never skipped, and the alarms menu overshoots the RSSI dBm range

Betaflight 2026.12 (master as of 2026-10-25). Findings F182 and F213, `DESIGN.md` D193 and D244. Not reported upstream.

## Betaflight

The menu cursor skips labels, strings and the narrow numbers that are dynamic or slider overridden. The dynamic test compares the whole flags word with the dynamic flag, and the element code in the low five bits makes the word unequal for every numeric row, so the test never holds and the read-only dynamic rows of the misc, lap timer and MSP transmitter menus stay in the cursor's path. Observed in the menu oracle's skip vectors: no numeric row was skipped by the dynamic flag alone. The alarms menu's RSSI dBm line runs from the CRSF RSSI minimum to the CRSF signal to noise maximum, -130 to 20, where the command line's range for the same setting ends at the RSSI maximum, 0, so the menu can store 5 to 20 dBm, which the command line refuses.

## adaflight

The skip test checks the dynamic flag bit, so a dynamic numeric row is skipped like a label. The alarms menu's RSSI dBm line ends at 0. The menu vectors were recorded from host builds of Betaflight's menu system and OSD menu with the same test and range.

## Proposed change for Betaflight

Test the dynamic flag with a bitwise AND in the skip test, and give the RSSI dBm alarm line the RSSI maximum as its upper bound.
