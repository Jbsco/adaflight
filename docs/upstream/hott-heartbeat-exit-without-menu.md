# HoTT display heartbeat exits a menu that a key already closed

Betaflight 2026.12 (master as of 2026-10-08). Finding F356, `DESIGN.md` D770. Not reported upstream.

## Betaflight

cmsUpdate scans keys, draws, then calls its current display's heartbeat every 500 ms. It does so even when a key closed its menu earlier in that pass. hottHeartbeat calls cmsMenuExit with a save whenever HoTT's text mode is stopped. cmsMenuExit then reads `currentCtx.menu->onExit`, and an exit has set that menu pointer to null.

This needs a menu on a HoTT display, a text mode that stopped since its last heartbeat, and a key exit in a pass where a heartbeat is due. A next button on an exit line, followed at once by a transmitter leaving text mode, gives that order.

Found by reading. Not run, so what a board does with that read at address zero is not known.

## adaflight

A heartbeat's exit takes place only while a menu is open.

## Proposed change for Betaflight

Test cmsInMenu in hottHeartbeat before its cmsMenuExit call.
