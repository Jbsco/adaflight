# Coded MSP flash read does not end on empty reads

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-16). Finding F359, `DESIGN.md` D781. Not reported upstream.

## Betaflight

`serializeDataflashReadReply` codes a Huffman reply in a loop that reads up to 256 bytes each pass. That loop ends when its output is full or its read position reaches a volume's end. A read that returns 0 changes neither, so that loop asks again from one address for as long as reads return 0. A W25N read returns 0 when its wait for a chip times out, so a NAND chip that stays busy keeps an MSP handler in that loop, and no other task runs.

A plain reply makes one read and reports its count, so it ends.

## adaflight

A read that brings no bytes ends a coded reply with what it has.

## Proposed change for Betaflight

Leave that loop when a read returns 0.
