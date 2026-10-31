# Simulator pitch from a quaternion that is not unit length

Betaflight 2026.12 (master as of 2026-10-27). Finding F314, `DESIGN.md` D543. Not reported upstream.

## Betaflight

SITL sets its attitude from each flight dynamics packet's quaternion as it arrives, without normalizing it. Its Euler
update takes pitch as `acos_approx` of a rotation entry, or in headfree mode of a quaternion product, and
`acos_approx` takes a square root of one minus that value's magnitude. A quaternion longer than unit length can give an
entry past one, so the square root is NaN and `lrintf` of NaN is undefined. On x86-64 pitch then reads 0.

## adaflight

Its attitude clamps that argument to [-1, 1], as it does for an estimated attitude, so pitch reads +-90 degrees there.

## Proposed change for Betaflight

Constrain the argument of `acos_approx` to [-1, 1], or normalize the quaternion SITL receives.
