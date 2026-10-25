# VTX stick commands step the band and channel past the table

Betaflight 2026.12 (master as of 2026-10-25). Finding F69, `DESIGN.md` D85. Not reported upstream.

## Betaflight

The stick commands that step the video transmitter's band or channel add the step to the configured byte with no check against the table, so a band of eight steps to nine and a channel of eight to nine, and a decrement from zero wraps to 255. The table lookups then find no frequency and the device keeps its setting until the sticks step back. The CLI bounds the same settings to the table maxima. Read from the source; reproduced in the VTX control oracle.

## adaflight

A stick step holds the band and channel within the table's counts, zero to the band or channel count, so a step past either end stays there. The VTX control vectors were recorded from a host build of Betaflight's control with the same bounds.

## Proposed change for Betaflight

In the stick step, constrain the stepped band to 0 .. vtxTableBandCount and the stepped channel to 0 .. vtxTableChannelCount, with the step taken as a signed value.
