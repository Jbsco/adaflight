# Board configs name SPI receiver pins the resets never read

Betaflight 2026.12 (master as of 2026-10-25) with the board configurations of the config repository. Finding F317, `DESIGN.md` D621. Not reported upstream.

## Betaflight

The CC2500 receiver group resets its transmit enable, receive amplifier enable and antenna select pins from `RX_CC2500_SPI_TX_EN_PIN`, `RX_CC2500_SPI_LNA_EN_PIN` and `RX_CC2500_SPI_ANT_SEL_PIN`. The ExpressLRS receiver group resets its reset and busy pins from `RX_EXPRESSLRS_SPI_RESET_PIN` and `RX_EXPRESSLRS_SPI_BUSY_PIN`. Four CC2500 board configurations (ALIENFLIGHTNGF7_RX, EMAX_TINYHAWK_F411RX, IFLIGHT_BLITZ_F411RX, MATEKF411RX) name their amplifier pins `RX_SPI_CC2500_TX_EN_PIN`, `RX_SPI_CC2500_LNA_EN_PIN` and `RX_SPI_CC2500_ANT_SEL_PIN`. Two ExpressLRS boards (SPRACINGH7EVO, SPRACINGH7EF) name their radio pins only `RX_SPI_EXPRESSLRS_RESET_PIN` and `RX_SPI_EXPRESSLRS_BUSY_PIN`.

No firmware source maps these names, so on those boards each pin resets to none. A CC2500 build enables its amplifier control, and with no pin set the receiver never drives the amplifier or antenna select lines until the user assigns them with `resource`.

## adaflight

The board generator reads the reset's own name and, when a board configuration lacks it, the other name. The six boards reset these pins to the pins their configurations name.

## Proposed change for Betaflight

Rename the defines in the six board configurations to the names the resets read.
