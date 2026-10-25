# SDIO card write cache loses blocks at a run's end

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F278, `DESIGN.md` D368. Not reported upstream.

## Betaflight

With the SDIO card driver's write cache on, the blocks of a multi-block run collect in a cache of 16 and go to the card in one transfer when the cache fills or the run's last block arrives, and each cached block is answered as written. Three paths mishandle the cache. A run's end, reached by a read, by a write out of sequence or by a new run begun from the writing state, clears the cache without writing it, so blocks the caller was told were written are lost. A write in the ready state during a run joins the cache without a check of its index, and the flush places the cached blocks from the last index back, so a block out of sequence puts every block of the flush at the wrong index. A run begun from the ready state keeps the blocks an earlier run left in the cache, and the next flush writes them with the new run's blocks at the new run's indexes. Read from the source; not reproduced on hardware.

## adaflight

A run's end writes the blocks still cached as one transfer without a completion and reports the run busy while the transfer runs. A write or a run begun at a block out of sequence in the ready state ends the run first, as in the writing state. The SDIO card vectors were recorded from a host build of Betaflight's driver with the same handling.

## Proposed change for Betaflight

In the run's end, start a write of the cached blocks at the next block less their count, with no completion, and return in progress; in the write and the run begin, treat the ready state with a run still open like the writing state, ending the run when the block is out of sequence.
