# Bit-banged read of motors the setup stopped before

Betaflight 2026.12 (master as of 2026-10-27). Finding F312, `DESIGN.md` D535. Not reported upstream.

## Betaflight

The bit-banged DShot driver's setup gives each motor its port group in order and stops at the first motor whose
group cannot start: a fifth GPIO port, a group slot without a pacer, or a pacer stream another group took. The motors
after it keep a null group. With bidirectional DShot the reply read after every motor update still takes every motor
and reads the null group's abort flag, sample buffer and sample count. On an STM32 those reads land on the boot alias
of flash, so the read skips the motor or decodes memory from an address taken from the vector table, depending on the
table's contents. A host build faults. The arming check blocks arming in this state, while the motor updates and the
reads run on.

## adaflight

The read takes only the motors the setup gave a group.

## Proposed change for Betaflight

Skip a motor without a group in the read, as the write already does.
