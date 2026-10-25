# MAVLink remote RSSI below the range minimum wraps

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F42, `DESIGN.md` D52. Not reported upstream.

## Betaflight

The MAVLink receiver takes the radio status message's remote RSSI byte, sign-inverted, as a dBm value and scales it from the range -130 to 0 dBm onto the receiver's 0 to 1023 range in an unsigned 16-bit variable, without a clamp. The byte runs from 0 to 254, with 255 for an unknown value. A byte above 130 gives a negative scaled value, which wraps to above 64000 before the receiver takes it as the RSSI. Read from the source; not reproduced on hardware.

## adaflight

The dBm value is held at the range minimum before the scale, so a report below -130 dBm gives an RSSI of 0. The dBm value the receiver reports stays as received. The MAVLink receiver vectors were recorded from a host build of Betaflight's receiver with the same hold.

## Proposed change for Betaflight

In mavlinkParseRxStats, scale `constrain(rssiDbm, RSSI_DBM_MIN, RSSI_DBM_MAX)` in place of `rssiDbm`.
