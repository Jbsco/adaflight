# SDIO card reset leaves the card in the state that failed

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F278, `DESIGN.md` D368. Not reported upstream.

## Betaflight

The SDIO card driver's reset asks the controller to initialize the card again and counts a failure only when the controller refuses; after an accepted initialization it changes nothing. On the STM32 SDMMC ports the initialization runs once and repeats its first result on every later call, so after a working start a reset never refuses: the failure count stays, the state stays, and a card that timed out in a write or a read keeps waiting in that state. After a refused start every reset counts until the card reads absent. The SPI card driver's reset counts the failure and returns the card to the reset state every time. Read from the source; not reproduced on hardware.

## adaflight

A reset asks the controller to initialize the card again, counts the failure, and returns the card to the reset state with the time, or marks it absent after eight failures in a row or without a card, whether the controller accepted or not. The SDIO card vectors were recorded from a host build of Betaflight's driver with the same reset.

## Proposed change for Betaflight

In the SDIO driver's reset, count the failure and set the reset state and its start time after the initialization call whether it returns success or not, as the SPI driver's reset does.
