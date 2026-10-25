# MSP and Tramp VTX menus store frequency zero in user frequency mode

Betaflight 2026.12 (master as of 2026-10-25). Finding F219, `DESIGN.md` D250 and D251. Not reported upstream.

## Betaflight

On entry the MSP VTX menu copies the device's band and channel, which a ready MSP transmitter in user frequency mode reports as 0 and 0, since only a band and channel set through the table change them. Saving stores band 0, channel 0 and the table's frequency at band 0, which is 0. The user frequency is lost, and the next configuration frame carries 0 MHz. The Tramp VTX menu does the same: the Tramp driver always reports band 0 and channel 0, so the menu copies a band and channel only through the common layer's selection of a band not from the factory, which a frequency set clears. In user frequency mode a save stores zeros again; the Tramp driver refuses frequency 0, so the transmitter keeps its frequency while the stored one is lost. Read from the source; reproduced in the menu oracle.

## adaflight

Both menus store band, channel and frequency at the save only while the menu holds a band and a channel, and store the power in every case, so a save in user frequency mode keeps the configured frequency. The menu vectors were recorded from a host build of Betaflight's menus with the same condition.

## Proposed change for Betaflight

In the MSP and Tramp VTX menus' save, store band, channel and frequency only while the menu's band and channel are both non-zero, as the RTC6705 menu fix does.
