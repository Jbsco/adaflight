# F4 mass storage class reads and writes wrong blocks past 4 GB

Betaflight 2026.12 (master as of 2026-10-08). Finding F339, `DESIGN.md` D750. Not reported upstream.

## Betaflight

F4's copy of ST's mass storage class keeps a read's or write's address in bytes in a 32 bit variable, SCSI_blk_addr, and divides by its block size for each storage call. Block 8388608 times 512 is 2^32, so that address wraps. F7's copy keeps a block address.

Reproduced on a host build of F4's usbd_msc_bot.c and usbd_msc_scsi.c over a stand-in storage of 61865984 blocks. READ(10) of block 8388608 read storage block 0. WRITE(10) to block 8388608 wrote block 0, and WRITE(10) to block 16777232 wrote from block 16. An SD card over 4 GB on an F4 board returns wrong data past 4 GB, and a host's write there lands where its partition table and file system start are.

## adaflight

Mass storage engine keeps a block address and a block count. Vectors were recorded from a host build of F4's copy with a 64 bit byte address.

## Proposed change for Betaflight

Declare SCSI_blk_addr as uint64_t in F4's usbd_msc_scsi.c and cast each command block byte to uint32_t before its shift.
