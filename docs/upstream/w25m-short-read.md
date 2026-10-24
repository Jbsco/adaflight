# W25M read reports bytes a die did not read

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F268, `DESIGN.md` D349. Not reported upstream.

## Betaflight

The W25M driver splits a read that spans both dies and asks each die for the bytes up to the die's end. It gives up only when a die read brings no bytes, moves on by the bytes it asked for, and returns the full length. The W25M02G's dies are W25N01GV NAND dies, whose read stops at the end of a 2048-byte page and returns the bytes it read. A read that crosses a page boundary reports every byte asked for while the bytes past the boundary were never read. The uncompressed MSP data flash read sends as many bytes as the read reports from the buffer it read into, so such a reply contains whatever that buffer held past the page boundary. The compressed read asks for at most 256 bytes at a time from 256-aligned starts and never crosses a page. A single W25N01GV without the W25M reports the short read, and the MSP reply is shorter. This was found in the source, not on hardware.

## adaflight

The read stops at the first die read that brings fewer bytes than asked and reports the bytes brought. The W25M vectors were recorded from a host build of Betaflight's driver with the same count.

## Proposed change for Betaflight

In the W25M read loop, return the bytes read so far plus the die's count when a die read brings fewer bytes than asked, in place of returning 0 only when it brings none.
