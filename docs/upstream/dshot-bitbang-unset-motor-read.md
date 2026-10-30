# Bit-banged read of motors setup stopped before

Betaflight 2026.12 (master as of 2026-10-27). Finding F312, `DESIGN.md` D535. Not reported upstream.

## Betaflight

Bit-banged DShot's setup gives each motor its port group in order and stops at a first motor whose group cannot start:
a fifth GPIO port, a group slot without a pacer, or a pacer stream another group took. Motors after it keep a null
group. With bidirectional DShot, a reply read after every motor update still takes every motor and reads a null group's
abort flag, sample buffer and sample count. On an STM32 those reads land on flash's boot alias, so a read skips such a
motor or decodes memory from an address taken from its vector table, depending on that table's contents. A host build
faults. Arming stays blocked in this state, while motor updates and reads run on.

## adaflight

Reply reads take only motors setup gave a group.

## Proposed change for Betaflight

Skip a motor without a group in reply reads, as motor writes already do.
