# Flash deadline check mixes two clocks

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-16). Finding F358, `DESIGN.md` D780. Not reported upstream.

## Betaflight

`flashIsReadyOrFail` compares a chip's deadline with `microsISR() / 1000`. `microsISR` returns a 32-bit microsecond count, so that quotient restarts at 0 every 71.58 minutes. W25N and MT29F drivers set their deadline from `millis()`, which does not restart. After 71.58 minutes of uptime such a deadline is always ahead of that quotient, and a chip that stays busy is never reported. A W25Q128FV driver sets its deadline from that same quotient, so its check fails only for a deadline set just before a restart.

Today `flashIsReadyOrFail` runs only during a chip erase, which a filesystem starts on a NOR chip with one partition. No W25N or MT29F chip reaches it, so this is latent for them.

## adaflight

Deadlines and that check read one millisecond clock.

## Proposed change for Betaflight

Compare with `millis()` in `flashIsReadyOrFail`, and set a W25Q128FV deadline from `millis()` too.
