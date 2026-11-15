# After a HoTT text mode session the stick command cannot reach the OSD menu

Betaflight 2026.12 (master as of 2026-10-08). Finding F357, `DESIGN.md` D770. Not reported upstream.

## Betaflight

hottCmsOpen selects its HoTT display as current, and that selection stays after an exit. A later menu stick command then opens its menu on that HoTT display. hottHeartbeat exits with a save whenever text mode is stopped, so that menu closes at its first heartbeat and writes flash. A held stick command opens it again, and each heartbeat closes it before its key delay ends, so it never moves to a next display.

After one text mode session, a pilot without that transmitter screen cannot open an OSD menu by sticks until a restart, and each try writes flash.

Read from source, then seen in adaflight's host build with its heartbeat rule changed to Betaflight's: a held stick command never showed a menu on its OSD, and its configuration file was written again and again.

## adaflight

A menu on a HoTT display leaves at its text mode's end only when that mode ran while it showed there. A menu that sticks open on a silent HoTT display stays, and a held stick command moves it to an OSD.

## Proposed change for Betaflight

Note in hottGrab whether text mode is alive, set that note in hottHeartbeat while it is alive, and exit only when that note is set and text mode has stopped.
