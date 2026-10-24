# SD card forward seek moves to twice the position

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F238, `DESIGN.md` D299. Not reported upstream.

## Betaflight

The file system's seek from the current position adds the offset to the cursor to form the target position, bounded by the file size, and passes that target to the internal seek. The internal seek moves the cursor forward by the amount it is given, so the cursor lands at the current position plus the target: a seek of 10 bytes from offset 1000 leaves the cursor at 2010, and a seek of 3000 from there at 7020. A seek from the start first rewinds the cursor, so it is unaffected. In a host build of Betaflight's file system the doubled positions were observed as described. The flight log never seeks from the current position, so the path is reached by other file system users only. This was found in the source and a host build.

## adaflight

The seek from the current position moves by the offset, bounded by the bytes left to the end of the file. The FAT vectors were recorded from a host build of Betaflight's file system with the same bound.

## Proposed change for Betaflight

In the seek's current-position case, pass the offset bounded by the remaining file size to the internal seek instead of the target position.
