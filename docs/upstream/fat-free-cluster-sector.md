# SD card free-cluster search reads the wrong FAT sectors past the free-space file

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F237, `DESIGN.md` D299. Not reported upstream.

## Betaflight

The SD card file system searches for a free cluster by walking FAT entries from a start cluster, with the FAT sector and the entry within it computed once before the loop. When the search reaches the free-space file's first cluster, it jumps the cluster number past the file and continues, but keeps the FAT sector and entry index it had. The entries it then examines belong to the sector before the free-space file, while the cluster numbers it reports lie after it, so a cluster can be reported free from the wrong entry. The search runs when the free-space file is exhausted or absent. This was found in the source, not on hardware.

## adaflight

After the jump the search recomputes the FAT sector and the entry index for the new cluster number. The FAT vectors were recorded from a host build of Betaflight's file system with the same recomputation.

## Proposed change for Betaflight

After the free-space file skip in the cluster search, call the FAT position function for the new cluster number to reset the FAT sector index and entry index.
