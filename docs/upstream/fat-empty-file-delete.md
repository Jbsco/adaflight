# Deleting an empty file corrupts the FAT

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F239, `DESIGN.md` D299. Not reported upstream.

## Betaflight

A file truncate or delete walks the file's FAT chain from its first cluster and frees each cluster until it reaches an end-of-chain mark. An empty file's first cluster is 0, so the walk frees FAT entry 0, which holds the media mark. The next such walk reads 0 from entry 0, frees it again and stays on cluster 0, and once that FAT sector is cached it never returns. In a host build of Betaflight's file system on a FAT16 volume, deleting one empty file changed FAT entry 0 from 0xFFF8 to 0, and deleting a second empty file did not return within 5 s.

The flight log can trigger it. A log that ends within its first 100 ms has written no frames, and ending it deletes its empty file. The walk runs in the main task, so the second such log stops the scheduler. This was found in the source and a host build, not on hardware.

## adaflight

The chain walk stops at the reserved clusters 0 and 1, so deleting an empty file frees nothing and a chain that runs into a free entry stops without touching entry 0. The file system vectors were recorded from a host build of Betaflight's file system with the same stop.

## Proposed change for Betaflight

End the chain walk of the truncate and delete operations at a cluster number below the smallest legal cluster, as well as at an end-of-chain mark.
