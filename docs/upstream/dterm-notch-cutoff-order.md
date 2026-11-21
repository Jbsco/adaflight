# MSP filter write starts a D term notch whose cutoff is at or above its center

Betaflight 2026.12 (master as of 2026-10-08). Finding F368, `DESIGN.md` D864. Not reported upstream.

## Betaflight

validateAndFixConfig sets a D term notch center to zero when its cutoff is at or above it. It runs only when a configuration loads. The MSP filter config write stores the D term notch center and cutoff as sent, then calls pidInitFilters at once. pidInitFilters takes the notch's Q from filterGetNotchQ, which divides by the center's square minus the cutoff's square. That Q is infinite for a cutoff equal to the center and negative above it. svfNotchInit starts all three axes' D term notches with that Q.

The reference's state-variable notch was run on a unit step at an 8 kHz loop with a 100 Hz center (compiled from the reference's filter sources, not on a board):

- cutoff 80 Hz, Q 2.2: peak 1.16, settles at 1.
- cutoff 100 Hz, Q infinite: the first output is not a number.
- cutoff 101 Hz, Q -50: peak 10.8.
- cutoff 150 Hz, Q -1.2: the output reaches infinity after 2699 samples, 0.34 s.

The D term keeps that notch until a save reloads the configuration and the fix sets its center to zero. A board armed before that save flies with that D term.

## adaflight

The runtime PID profile turns the D term notch off while its cutoff is at or above its center, the value a load would give it. The stored center and cutoff stay as written until a save.

## Proposed change for Betaflight

In the MSP filter config write, apply validateAndFixConfig's D term notch check before pidInitFilters, as that write applies validateAndFixGyroConfig before gyroInitFilters.
