# Simulator packet conversions outside C's defined range

Betaflight 2026.12 (master as of 2026-10-27). Finding F313, `DESIGN.md` D542. Not reported upstream.

## Betaflight

SITL's state update turns each flight dynamics packet's doubles into integers with plain C conversions, and some
inputs fall outside the range those conversions define:

- a packet field that is NaN or infinite reaches the accelerometer, gyro and pressure conversions as it is
- with Gazebo's bridge, an altitude above about 44.3 km makes the pressure formula's base negative, so `pow` returns
  NaN, and an altitude far below sea level gives a pressure past `int32_t`
- the virtual GPS stores ground speed and 3D speed past 655.35 m/s and velocities past 327.67 m/s in 16-bit fields
- Gazebo's mirrored position can leave the `int32_t` range of a coordinate in 1e-7 degrees
- a monotonic time span of zero between two packets gives an infinite sim rate

A compiler is free to give any result there. On x86-64 a NaN or out-of-range double becomes `INT_MIN`, so a positive
overflow reads as a large negative value, and 16-bit fields wrap.

## adaflight

A packet with a NaN, infinite or larger than 1e6 field, or an attitude component past 2, is dropped. Pressure is 0 above Gazebo's 44.3 km and saturates
at `int32_t`'s limits, coordinates saturate at the `int32_t` limits, speeds at 65535 and velocities at +-32767 cm/s,
and a span of less than 1 ns leaves the sim rate as it was.

## Proposed change for Betaflight

Constrain each double before its conversion, and skip a packet whose fields are not finite.
