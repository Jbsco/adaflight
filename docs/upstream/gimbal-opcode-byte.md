# Gimbal passthrough writes 1 for the held-back opcode byte

Betaflight 2026.12 (master as of 2026-10-25). Finding F135, `DESIGN.md` D128. Not reported upstream.

## Betaflight

The gimbal control holds back the head tracker's first opcode byte 16#A5# until the next byte arrives. When that byte is not the second opcode byte 16#5A#, the control forwards the held-back byte and the new one to the gimbal, but the held-back byte is written as a logical AND of the opcode and 16#FF#, whose value is 1. Every 16#A5# in the passthrough stream outside a command frame reaches the gimbal as 16#01#. Observed in the gimbal oracle: 2548 of these bytes went out as 16#01# across five sequences.

## adaflight

The control forwards the held-back 16#A5# itself before the new byte. The gimbal vectors were recorded from a host build of Betaflight's control with the same write.

## Proposed change for Betaflight

Write the low byte of the opcode, a bitwise AND with 16#FF#, in place of the logical AND.
