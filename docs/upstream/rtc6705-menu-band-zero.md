# RTC6705 menu stores band 0 at exit

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F226, `DESIGN.md` D262. Not reported upstream.

## Betaflight

The RTC6705 reports band 0 and channel 0, and the common getter looks band and channel up from the frequency only when the selected band is not a factory band. With a factory band or no band selected, the RTC6705 menu opens with band 0 and channel 0. Leaving the menu writes band 0, channel 0 and the frequency they look up, which is 0, to the settings and saves them. Opening the menu and leaving it without a change replaces the stored band, channel and frequency with zeros.

## adaflight

The menu stores band, channel and frequency at the exit only while both band and channel are set, so a menu opened at band 0 leaves the settings as they were. The menu vectors were recorded from a host build of Betaflight's menu with the same condition.

## Proposed change for Betaflight

In the RTC6705 menu's write-back, store band, channel and frequency only while the menu's band and channel are both non-zero.
