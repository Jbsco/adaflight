# The OSD's aux value reads past the RC channels for aux channels 15 to 18

Betaflight 2026.12 (master as of 2026-10-27). Finding F302, `DESIGN.md` D472. Not reported upstream.

## Betaflight

The OSD's aux value element shows one aux channel scaled to a configured range. The aux channel setting takes 1 to
18, and the OSD adds the four flight channels less one to it, so the setting reaches RC channel indexes 4 to 21.
The RC data holds 18 channels. Settings 15 to 18 read past the end of the RC data, and the element shows whatever
memory follows it, scaled. Nothing else limits the setting.

## adaflight

A setting past the last aux channel reads as the lowest pulse, so the element shows 0. Settings 1 to 14 read
their aux channel.

## Proposed change for Betaflight

Limit the setting to the 14 aux channels, 1 to 14, or bound the channel index before the read.
