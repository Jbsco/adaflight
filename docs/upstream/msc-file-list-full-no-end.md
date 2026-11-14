# A mass storage file list of 100 logs has no end entry

Betaflight 2026.12 (master as of 2026-10-08). Finding F347, `DESIGN.md` D751. Not reported upstream.

## Betaflight

emfat_file.c sizes its entry table for its predefined entries, 100 logs and two appended files. emfat_init_entries finds that table's end by a null name. A flash with 100 or more logs and under 128 MB in use fills every slot, so no slot is left for a null name and that scan reads a name past its table.

Reproduced on a host build of emfat.c and emfat_file.c over a drawn flash of 100 logs. An address sanitizer reported a read past that table in emfat_init_entries. Without it, one build found zero bytes there and stopped. Another build, with other variables after that table, ran on and crashed in a later sector read. On a board, what follows that table in memory decides.

## adaflight

A volume has a count of its entries and no end entry. Oracle builds give Betaflight's table one more slot.

## Proposed change for Betaflight

Declare entries with EMFAT_MAX_ENTRY + 1 slots.
