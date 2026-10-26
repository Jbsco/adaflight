# VTX menus index the band, channel and power names past the table

Betaflight 2026.12 (master as of 2026-10-25). Finding F287, `DESIGN.md` D250. Not reported upstream.

## Betaflight

The VTX menus show the device's band, channel and power as tab lines whose names come from the VTX table's name arrays, one name per table slot and one for none. The tab draw reads the name at the line's value as given. The SmartAudio driver reports its band as the device's channel byte divided by the table's channel count, so a channel outside the table gives a band above the table's eight slots. The SmartAudio menu copies that band on entry, and the RTC6705, MSP and Tramp menus copy it through the common layer when opened with the SmartAudio device. Each menu keeps the copy between visits. The draw then reads past the name array. Observed in the menu contents oracle: a band of 13, 14 or 19 drew a channel's name as the band's name in the four menus, 14 draws in 240 sessions.

## adaflight

A tab line's value above the line's maximum draws a blank name. The menu vectors were recorded from a host build of Betaflight's menu system with the same bound.

## Proposed change for Betaflight

Draw a blank name in the tab line when the value is above the line's maximum, or clear the SmartAudio band and channel when the device's channel lies outside the table.
