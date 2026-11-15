# Mass storage waits without end on an SD card that is absent or failed

Betaflight 2026.12 (master as of 2026-10-08). Finding F349, `DESIGN.md` D756. Not reported upstream.

## Betaflight

Its SD card storage for mass storage mode starts a card and polls until that card is ready. A read repeats sdcard_readBlock until a card takes it, then polls until ready, and a write does likewise. No loop has an exit for a card that is not present, and its SPI card driver's poll does nothing in that state. That driver reaches it without a card or at its limit of consecutive failures.

Its class calls that start at a set configuration, in its USB interrupt on F4 boards, while its button check runs outside that interrupt. Its msc command and MSP reboot refuse without a functional card. A start by button, or a card that leaves or fails during that mode, reaches these loops.

Reproduced on a host build of that storage code over a stand-in card. A start without a card, a read after a card left and a write after a card left did not return. That a board then leaves this mode only by power or its reset pin is read from source, not measured.

## adaflight

Each wait ends once its card is absent or failed, and its command fails. An absent card shows as a disk without a medium. Host smoke runs that mode with its card absent.

## Proposed change for Betaflight

In STORAGE_Init, STORAGE_Read and STORAGE_Write, leave each wait when sdcard_isFunctional() is false, and return -1 from a read or a write then.
