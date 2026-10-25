# MSP transmitter reads its frequency back from the table

Betaflight 2026.12 (master as of 2026-10-25). Finding F218, `DESIGN.md` D249. Not reported upstream.

## Betaflight

The MSP transmitter driver keeps the frequency it is set but answers the frequency query with the table's frequency at its band and channel. In user frequency mode, band 0, the control layer's frequency step compares the configured frequency with that table frequency, 0 at band 0, so it sets the frequency again at every pass while they differ and reports an update pending for good. The configuration frame carries the configured frequency, so the transmitter gets the right one. The MSP VTX menu's status line shows the table frequency, none at band 0. Observed in the VTX control oracle: with the settings at band 0 and 5745 MHz, a driver given 5695 MHz at band 1 channel 7 answered 5745 MHz.

## adaflight

The frequency getter answers the frequency the driver was given while no band is set, and the table's frequency of its band and channel otherwise. The MSP transmitter, VTX status and menu vectors were recorded from a host build of Betaflight's driver with the same getter.

## Proposed change for Betaflight

In the MSP transmitter's frequency getter, return the stored frequency when the configured band is 0, and the table lookup otherwise.
