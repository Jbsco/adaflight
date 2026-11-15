# HoTT text mode opens the menu while armed

Betaflight 2026.12 (master as of 2026-10-08). Finding F355, `DESIGN.md` D770. Not reported upstream.

## Betaflight

A HoTT text mode request calls hottCmsOpen, which opens a menu whenever none is open. It does not read the arming flag. crsfDisplayPortMenuOpen, its CRSF counterpart, returns at once when armed, with a comment that an open menu would leave no way to disarm.

Three things follow for a craft that gets a text mode request in flight. cmsScanKeys reads pitch, roll and yaw positions past its thresholds as menu keys, and only its menu key tests for arming. Neither an arm switch nor a stick command disarms, since processRcStickPositions handles both and is skipped while a menu is open. A set button, or a transmitter that leaves its text mode, exits that menu with a save, and saveConfigAndNotify writes flash with no arming test.

Found by reading. Not run on a HoTT receiver. adaflight's host build with its arming test removed gave an armed image a menu, and that image stayed armed after its arm switch went off.

## adaflight

A text mode request opens a menu only while disarmed. Its screen stays as it was, and button keys wait as before.

## Proposed change for Betaflight

Return from hottCmsOpen when ARMING_FLAG(ARMED) is set, as crsfDisplayPortMenuOpen does. Give the cmsMenuOpen call for a previous button in hottSetCmsKey that same test.
