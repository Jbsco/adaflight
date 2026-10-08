# Design decision ledger

Decisions are dated and numbered. A reversal gets a new entry, never an edit.

## D1. License: GPL-3.0-or-later (2026-10-08)

The control algorithms are ported from a code base under GPL-3.0. Keeping the same
license removes any question about derivative work and lets the project take future
algorithm changes from the same source.

## D2. One reference, named once (2026-10-08)

The project targets feature and performance parity with the reference flight controller
firmware named in the README. That is the only place the reference is named. Code,
contracts, comments, and the other documents describe behavior in their own terms.
Other firmware projects whose names label a rate curve family in the reference are not
named either. Each family takes the name of its distinctive setting: super rate, acro
plus, RC curve, actual, quick.
The differential oracle that records test vectors from a host build of the reference
lives outside this repository. The recorded vectors are data and are kept under
`tests/vectors`.

## D3. Repository layout (2026-10-08)

- `core/` is the SPARK library crate: hardware independent, proved, no platform code.
- `tests/` is a host crate that replays the recorded vectors through the core.
- `tools/` holds the repository tooling.
- Target crates and a simulator crate will sit beside these as they land.

Each crate is an Alire crate with its own manifest, so a reader can build one in
isolation.

## D4. Where SPARK applies (2026-10-08)

SPARK is used where a proved contract gives assurance that a test cannot:

- Bounded floating-point signals, so that no infinity or NaN can reach a motor output
  whatever the input history.
- Bounded decoders, so that a malformed frame cannot index outside a buffer.
- State machines for arming and failsafe, so that the transition table is the proof.
- Mixer saturation, so that every motor command is in range by type.

The core proves at Silver for every unit (no run-time error can occur) and holds Gold as
the standing target: no `pragma Assume` and no justified suppression anywhere.
`prove.do` prints both counts on every run. Driver and platform code is Ada, tested, and
proved only where that is cheap.

## D5. Bounded signals with saturation at the bound (2026-10-08)

A `Signal` is a binary32 value within +/- 2**32. The bound admits every 32-bit integer and
is far above any physical quantity the controller handles. A convex combination of two
Signals stays within the bound in exact arithmetic, but the rounding of the last operation
can cross it when both operands sit at the bound, and no automatic prover closes the
invariant without a tie-to-even argument. The core therefore saturates every recursive
filter state at the bound. The saturation absorbs that one rounding and nothing else, so
the vector checks stay bit-exact. The price is one compare-select per first-order state
and three per state-variable filter step. The cost on a flight target is to be measured
before the control loop lands. The alternative, a ghost lemma carrying the tie-to-even
argument as a single assume, is recorded here and rejected while Gold is the target.
The state-variable filter coefficients follow the same rule: the warped angle saturates at
the tangent approximation's bound inside the filter, so a caller proves nothing about the
product of cutoff and period.

## D6. Parity criterion: bit-exact on the host (2026-10-08)

A ported function keeps the operation order of the reference, so a host build of both
produces the same binary32 bit pattern for the same input. The vector checker compares
bit patterns and reports the distance in representable values for every case. A
deliberate deviation carries a declared tolerance in the checker and an entry in this
ledger. The deviations so far:

- The moving average recomputes its sum from the window on every update instead of
  keeping a running sum, which removes the rounding drift the reference accumulates. The
  measured distance from the reference is at most 256 representable values over windows
  of 1 to 32 samples; the declared tolerance is 512.
- A normalized vector saturates each component at one. The reference can return a
  component one representable value above one when rounding of the reciprocal root
  lands high. The declared tolerance is 1; the saturation did not trigger in the
  recorded vectors.
- The sliding DFT twiddle table is static. The reference computes it at first use, and
  bin 18 carries a negative zero real part there, which a static Ada constant cannot
  express. The two zeros compare at distance 0.
- The varint encoder sets the continuation bit on every byte below the last. The
  reference emits the value 128 as a single bare byte 16#80#, which its own decoder
  treats as a continuation byte and rejects. The checker expects 16#80# 16#01# for that
  value and the recorded result for every other.
- The PID runtime's low throttle TPA multiplier is zero when the low breakpoint is zero.
  The reference divides by zero there and never reads the result. The checker expects
  zero wherever the recorded value is infinite or undefined.
- The PID filters are initialized from the configured runtime constants. The reference
  initializes them before it derives those constants, so after a profile change its iterm
  relax lowpass keeps the previous profile's cutoff until the next initialization; at boot
  it initializes twice and the second pass reads the first. The checker records the second
  pass.
- The hyperbolic TPA table is sampled through the double-precision elementary functions of
  the Ada runtime where the reference calls the C library's single-precision power; every
  recorded sample matches. A sample the reference leaves infinite or beyond the signal
  bound, where the curve's base cancels to zero at full throttle, saturates at the bound.
- The EZ landing mixer adjustment divides by its limit factor to widen the recorded mix
  range. Where that factor is zero the reference's range is infinite; it saturates at the
  signal bound here. The motor outputs do not depend on it.
- The averaged feedforward goes through the moving average above, so it carries that
  deviation; the checker holds it within 512 representable values or a hundredth of a
  degree per second, since the reference's running sum leaves a residue near zero.
- Two settings keep a narrower domain than the configuration interface admits: the
  hyperbolic TPA curve's two PID percentages exclude zero, where the reference's table is
  infinite or undefined, and the throttle minimum check stays below 2000, where the
  reference's throttle scaling divides by zero.
- The failsafe compares its deadlines through the wrapping difference of the millisecond
  counters, where the reference compares the counters directly in three places. The two
  agree while the counter is below its wrap, which the recorded vectors stay under; past
  it the reference's deadlines invert for up to 49.7 days.

## D7. Contribution conventions (2026-10-08)

Branches start from and rebase onto `origin/main`. Pull requests merge one at a time, and
every pull request re-runs the gates after its last rebase. Commit messages are one
imperative line, signed.

## D8. The gates (2026-10-08)

`style.do` compiles both crates from clean and fails on any warning, renders every
markdown file through the local viewer's renderer, and scans tracked files for local
paths and for references to other projects outside the README. `test.do` replays the
vectors. `prove.do` runs the SPARK proof and prints the unproved count and the assume
count. `verify.do` runs all three, cheapest first. The three CI workflows run the same
scripts.

## D9. Prover settings live in the project file (2026-10-08)

Level 2, 200000 steps, a 120 second backstop, all checks reported, and the invocation
header recorded in the summary. Steps are the operative bound because they do not vary
with the machine. Raising the level needs a justification in this ledger.

Amended 2026-10-08: the backstop is 300 seconds. The hosted runner is about two and a
half times slower than the development host and reported a time limit on a product
check the host closed in under a minute. The steps bound is unchanged.

## D10. Deferred: fast exponential and logarithm (2026-10-08)

The reference builds these from the bit layout of a float. SPARK does not admit an
unchecked conversion to a floating-point type, so the port needs a different
construction. The single consumer is a telemetry scaling, so the port waits for that
increment.

Outcome, recorded when the port landed: SPARK rejects an unchecked conversion into a
float and does not support the `Scaling`, `Exponent`, and `Fraction` attributes on
non-static values, but accepts an unchecked conversion from a float. The exponential
therefore takes its power of two from a static table of 254 constants and builds the
mantissa factor as `1.0 + Float (bits) * 2.0 ** (-23)`, which is exact, and the
logarithm reads the bit pattern of its argument. Both replay the recorded vectors bit
for bit, so the construction is equivalent to the reference's.

## D11. Proof context stays small: tables and bit casts live behind contracts (2026-10-08)

A large constant aggregate in a unit enters the context of every verification condition
of that unit, and the provers then time out on checks that are otherwise trivial. The
Huffman code table (257 entries) and the power of two table (254 entries) therefore live
in their own packages behind a lookup function whose postcondition states the bound the
callers need. The same holds for an unchecked conversion from a float: it sits in a small
helper with a postcondition, so the bit-level model of the float does not reach the
arithmetic that follows. A function that reparses characters it already scanned carries a
quantified invariant the provers handle badly, so the GPS coordinate parser collects its
digits once into a bounded array and consumes them by count.

## D12. Derived constant bounds carry rounding slack (2026-10-08)

A runtime constant derived from bounded settings gets a range a little wider than the
exact product or quotient of the setting bounds: 1001 where the arithmetic gives 1000,
101 where it gives 100. A bound at the exact rounded result costs the provers minutes per
check and sometimes fails, as the throttle PID attenuation multiplier did at 100.000001.
The slack changes nothing downstream, where the bounds only exclude overflow and
undefined values. A helper whose callers need different bounds states them as conditions
on its input, so the postcondition carries what each caller needs.

## D13. The rate loop takes bounded rates and saturates its terms (2026-10-08)

The controller's inputs are rates in degrees per second bounded at 2 to the power 13, and
the loop time is at least 100 microseconds, so the D term's difference quotient stays
within the signal bound. Each term saturates at the signal bound where a product of
bounds would exceed it, and the I term's own bound leaves room for the rotation between
loops. On the recorded sequences none of these saturations engages, so the replay stays
bit-exact. The classic TPA factor keeps the range its two multipliers admit, since the
cancellation between a quotient and the product that undoes it is not provable in float.

## D14. The profile carries the configuration validation rules (2026-10-08)

The reference repairs two settings whenever it loads a configuration: a dynamic D-term
lowpass minimum above its maximum becomes zero, and a notch center at or below its cutoff
becomes zero. In flight no profile violates either rule, so the profile type states them
as a predicate and the units that read the profile prove against them. The oracle applies
the same rules after it draws its random settings, so the recorded vectors describe
validated profiles only.
The gyro filter settings carry the same two rules for their own lowpass range and their
two notches.

## D15. One body outside SPARK: the power behind the TPA table (2026-10-08)

The hyperbolic TPA table needs a power accurate to the single-precision rounding of the
reference's C library, which the fast approximation of the core cannot give. The Ada
runtime's double-precision exponential and logarithm give it, but their bodies are
analyzed at the call with a conversion check the provers cannot close. The call therefore
lives in `Adaflight.Accurate_Power`, whose spec carries the bound the callers prove
against and whose body is outside SPARK and saturates to honor it. The proof gate counts
such bodies on every run, next to the assumes.

## D16. Motor outputs are in range by type (2026-10-08)

The mixer's postcondition states that every motor output lies between the disarm value or
the low endpoint, whichever is lower, and the high endpoint, so the promise of the README
is a proved property of `Adaflight.Mixer.Update` rather than a test. The per-motor mix is
bounded at 16 in magnitude, which the scaled sums and the unit weights cannot reach, and
the clamp the reference applies with a lower bound that rounding can place above the
upper one is kept as written, with a postcondition that names which of the three values
it returns. The reference seeds its motor maximum with the smallest normal float; the
port keeps the seed to stay bit-exact.

## D17. Quaternion components saturate at two (2026-10-08)

The attitude estimator keeps the quaternion of the body frame in `Adaflight.Attitude`. A
normalized component lies within one plus the rounding of the normalization, which the
prover cannot see through the square root, so the estimator saturates each component at
two after it normalizes, and the rotation matrix entries follow at seventeen by type. The
saturation is inert: no normalized component reaches it. The Euler angles and the throttle
correction are held to their decidegree and correction ranges after rounding, which the
rounding of a bounded argument cannot leave. Two guards keep the reference's
infinities and NaNs out of the state. A quaternion whose norm vanishes resets to identity
where the reference divides by zero, and the arc cosines of the rotation matrix take their
argument clamped to the cosine range where the reference takes the root of a negative
number. Neither case occurs in the recorded vectors, which replay bit for bit. The
accelerometer path, the magnetometer and course-over-ground heading errors, and the
headfree frame are not in this unit.

## D18. The failsafe reprocess loop is bounded (2026-10-08)

The reference re-evaluates the failsafe stage within one update until a stage holds. The
stages form a chain of at most five within one update, because the link state is fixed
for the update and no stage returns to a stage it left under the same link state, so
`Adaflight.Failsafe.Update` runs the stage dispatch in a loop bounded at eight passes and
exits when a stage holds. The bound keeps the termination proof trivial and never
triggers; the transient stages (loss detected, landed, recovered) are checked by the
vectors, which never leave an update in one. The event counter saturates where the
reference's 16-bit counter would overflow after 32767 failsafe events.
