# Design decision ledger

Decisions are dated and numbered. A reversal gets a new entry, never an edit.

## D1. The GPL-3.0-or-later license (2026-10-08)

The control algorithms are ported from [Betaflight](https://github.com/betaflight/betaflight),
which is under GPL-3.0. Keeping the same license removes any question about derivative work
and lets the project take future algorithm changes from the same source.

## D2. The reference firmware (2026-10-08)

The project targets feature and performance parity with Betaflight, the flight control
firmware it is ported from. The README names Betaflight in its first paragraph, and this
ledger names it where a decision needs the name. Code, contracts, comments, and the other
documents describe behavior in their own terms. The other firmware projects whose names
label a rate curve family in Betaflight are not named either. Each family takes the name of
its distinctive setting: super rate, acro plus, RC curve, actual, quick. The differential
oracle that records test vectors from a host build of Betaflight lives outside this
repository. The recorded vectors are data and are kept under `tests/vectors`.

Amended 2026-10-10: the first version of this entry allowed the name only in a README
section of its own. That section is gone. The name now stands in the README's first
paragraph and in this ledger, with the link.

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

## D6. The parity criterion (2026-10-08)

A ported function keeps the operation order of the reference, so a host build of both
produces the same binary32 bit pattern for the same input. The vector checker compares
bit patterns and reports the distance in representable values for every case. A
deliberate deviation carries a declared tolerance in the checker and an entry in this
ledger. The deviations so far:

- The moving average recomputes its sum from the window on every update instead of
  keeping a running sum, which removes the rounding drift the reference accumulates. The
  measured distance from the reference is at most 256 representable values over windows
  of 1 to 32 samples. The declared tolerance is 512.
- A normalized vector saturates each component at one. The reference can return a
  component one representable value above one when rounding of the reciprocal root
  lands high. The declared tolerance is 1. The saturation did not trigger in the recorded
  vectors.
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
  relax lowpass keeps the previous profile's cutoff until the next initialization. At boot
  it initializes twice and the second pass reads the first. The checker records the second
  pass.
- The hyperbolic TPA table is sampled through the double-precision elementary functions of
  the Ada runtime where the reference calls the C library's single-precision power. Every
  recorded sample matches. A sample the reference leaves infinite or beyond the signal
  bound, where the curve's base cancels to zero at full throttle, saturates at the bound.
- The EZ landing mixer adjustment divides by its limit factor to widen the recorded mix
  range. Where that factor is zero the reference's range is infinite. It saturates at the
  signal bound here. The motor outputs do not depend on it.
- The averaged feedforward goes through the moving average above, so it carries that
  deviation. The checker holds it within 512 representable values or a hundredth of a
  degree per second, since the reference's running sum leaves a residue near zero.
- Two settings keep a narrower domain than the configuration interface admits: the
  hyperbolic TPA curve's two PID percentages exclude zero, where the reference's table is
  infinite or undefined, and the throttle minimum check stays below 2000, where the
  reference's throttle scaling divides by zero.
- The failsafe compares its deadlines through the wrapping difference of the millisecond
  counters, where the reference compares the counters directly in three places. The two
  agree while the counter is below its wrap, which the recorded vectors stay under. Past
  the wrap the reference's deadlines invert for up to 49.7 days.
- The barometric altitude takes its power from the double-precision elementary functions
  (D15), which land within one unit in the last place of the C library's single-precision
  power. The altitude subtracts the power from one, so near sea level the last bit of the
  power becomes up to 2 ** (-21) * 4433000, about 2.2 cm. The declared tolerance is 3 cm,
  and two samples of 6900 recorded needed it.
- The battery's charge integration multiplies the latest current by the microseconds since
  the meter was last serviced in 64 bits, where the reference's 32-bit product wraps on the
  first sample after a pack is detected, which spans the time since boot (findings F20).
  The recorded vectors keep that first sample small enough for the reference to stay in
  range, so the two agree on every step.
- The automatic disarm deadline is compared through the wrapping difference. The reference
  compares the microsecond counter and the deadline directly, so a deadline set in the last
  seconds before the 71.6-minute wrap disarms at once, and one set before a wrap that the
  counter has passed does not fire for the next 71 minutes (findings F21). The recorded
  vectors stay clear of the wrap and replay bit for bit.

## D7. Contribution conventions (2026-10-08)

Branches start from and rebase onto `origin/main`. Pull requests merge one at a time, and
every pull request re-runs the gates after its last rebase. Commit messages are one
imperative line, signed.

## D8. The gates (2026-10-08)

`style.do` compiles both crates from clean and fails on any warning, renders every
markdown file through the local viewer's renderer, and scans tracked files for local
paths and for references to other projects outside the README and this ledger. `test.do`
replays the
vectors. `prove.do` runs the SPARK proof and prints the unproved count and the assume
count. `verify.do` runs all three, cheapest first. The three CI workflows run the same
scripts.

## D9. Prover settings live in the project file (2026-10-08)

Level 2, 200000 steps, a 120 second backstop, all checks reported, and the invocation
header recorded in the summary. Steps are the operative bound because they do not vary
with the machine. Raising the level needs a justification in this ledger.

Amended 2026-10-08: the backstop is 300 seconds, so a check that proves within the
steps bound is not cut short by the clock on a slower machine. The steps bound is
unchanged.

## D10. The fast exponential and logarithm (2026-10-08)

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

## D11. Tables and bit casts behind contracts (2026-10-08)

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

## D15. The accurate power outside SPARK (2026-10-08)

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
it returns. The reference seeds its motor maximum with the smallest normal float. The
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
triggers. The transient stages (loss detected, landed, recovered) are checked by the
vectors, which never leave an update in one. The event counter saturates where the
reference's 16-bit counter would overflow after 32767 failsafe events.

## D19. Mode activation lists are bounded by type (2026-10-08)

`Adaflight.Modes` keeps the two lists the reference builds when it analyzes the
activation conditions, the own-range conditions and the linked ones, as index arrays with
counts whose sum the state's predicate bounds at the condition count, so the loop that
fills them proves its indices from one invariant and the update loops read within them.
The masks are Boolean arrays over the box enumeration rather than bit words, so a box
identifier out of range cannot exist. The vector checker folds them back into the
reference's words. The boot delay before a sticky box may disarm compares the microsecond
counter directly, as the reference does, since the delay is a one-shot after boot.

## D20. Accelerometer counts and offsets are held to their ranges (2026-10-08)

`Adaflight.Accelerometer` follows the reference's path from the raw counts to the values
the attitude estimator reads. Two bounds are stated where the reference relies on its
types silently. An aligned count is held within 2 ** 18, which a standard alignment cannot
reach and a custom rotation, whose matrix entries are within two, cannot exceed on 16-bit
counts, so the saturation is inert. The calibration totals follow the reference's path,
each cycle adding the float sample to an integer total and truncating back, and saturate
at 2 ** 28, which 400 cycles of such counts cannot reach. The offsets are the rounded
means less the gravity count on the vertical axis. The reference stores each offset in a
16-bit field that wraps when the mean exceeds it. The port saturates the offset at the
field's range instead, which no sensor near one gravity reaches. The in-flight
calibration, the board alignment, and the configuration flag that records a completed
calibration are not in this unit. The magnitudes take the norms of the acceleration and
the jerk held to bounds the root of three squares within their component ranges cannot
reach, so their scaling by the reciprocal of one g proves apart from the update.

## D21. The barometric power saturates at eight (2026-10-08)

`Adaflight.Barometer` turns a pressure into an altitude through the power of its ratio to
the sea-level pressure. A pressure within the 32-bit range keeps that power below seven,
so the power is held at eight before the altitude is formed, which bounds the altitude
and the calibration sums by type. The saturation is inert. The device state machine that
schedules the temperature and pressure reads is the driver's, and the port takes each
pressure sample with the time of its read. The calibration keeps the reference's integer
mean of the temperature and float mean of the altitude, with both sums saturating at
their types' bounds, which one hundred samples cannot reach. The drift product is formed
in 64 bits where the reference's 32-bit product would wrap above a two-degree-million
difference, which no device reports.

## D22. Battery meters in the reference's integer arithmetic (2026-10-08)

`Adaflight.Battery` keeps the voltage and current meters in the reference's integer
arithmetic: the divider scaling in 32-bit unsigned steps held to the 16-bit field it stores
into, the current scaling in 32-bit signed steps, the cell thresholds in 16-bit unsigned
products, and the filtered analog counts truncated back to counts before scaling, as the
reference converts them. The stability record is the reference's shifted bit mask. Only the
analog meters are ported. The ESC, virtual, and MSP sources reset their meter as the
reference does when a source is absent. The cutoff percentage is held to its range where
the reference's byte leaves it after a clock wrap during the ramp, and the charge sum and
energy saturate at their float types' bounds, which no pack reaches.

## D23. Sensor readings are aligned before they are scaled (2026-10-08)

The gyro and the accelerometer carry their alignment as the reference orders it: the
counts, less the gyro's zero offsets, go through the sensor's standard rotation or its
custom rotation matrix, then through the board rotation when the board angles are not all
zero, and only then through the scale. The permutations of a standard rotation commute
with the scale but the matrices do not, so the order is kept for the custom and board
cases. The gyro zero offsets stay per raw axis, since the reference calibrates before it
aligns. The board rotation matrix is built from whole degrees through the same conversion
and rotation the reference uses, and the matrices sit in the state with their entries
bounded by two, which bounds the aligned counts by type.

## D24. The arming logic as the reference's flag machine (2026-10-09)

`Adaflight.Arming` holds the arming flags, the thirty disable reasons as a Boolean array in
the reference's bit order, and the flight mode flags, so the reason the warning beeps count
out is the first true element. The unit takes what the other units report (the link, the
failsafe, the attitude, the calibrations, the motor protocol) in an input record per pass
and returns what it asks of them (the beeps, the stick commands, the calibration and save
requests, the stabilisation state) in an output record, so it depends on no unit that is
not yet ported. The three passes keep the receiver task's order: the receiver pass, the
modes pass with the stick combinations, the mode update and the flight mode selection, then
the arming status. The throttle percent holds its fraction to the unit range and guards a
zero divisor; both are inert within the configuration ranges (a minimum check below 2000
microseconds, a 3D mid value and deadband that leave a span below full throttle). The
automatic disarm deadline is compared through the wrapping difference where the reference
compares the counters directly (D6). The stick hold time is the reference's 16-bit count
with its saturation, and the disarm tick counter is its wrapping byte. Not in this unit:
the DShot beacon delay, crash flip and spin direction, launch control, the GPS rescue arming
checks, the runaway takeoff detection, the in-flight accelerometer calibration, the shared
port telemetry switch, and the adjustments, which belong with their own units.

## D25. Level modes inside the rate loop (2026-10-09)

The angle and horizon modes stay where the reference keeps them, in the rate loop between
the acceleration limit and the iterm relax, so the loop's order holds: the angle target from
the stick through the angle limit and the rate at full deflection, the attitude less the
trims, the angle feedforward through its own filter, the yaw compensation while rolled or
pitched, the attitude filter, and the horizon crossfade. The attitude, the trims, the stick
deflections, and the full-deflection rates arrive as inputs of the loop, since the units
that produce them run before it. The horizon strength and the level rate carry the type
bounds their configuration ranges allow (a strength of up to six hundred, a feedforward of
up to four million degrees per second), and saturate at the signal bound and the rate bound
where the reference's floats run on; none of the saturations is reached in the recorded
vectors. The level mode start time is kept for the crash recovery guard, which is not yet
ported, and the GPS rescue, altitude hold, position hold, and launch inputs to the level
target are not in this unit.

## D26. Gyro calibration and the full-scale detections in the gyro unit (2026-10-09)

The zero offset calibration lives with the gyro filtering, where the reference keeps it:
while cycles remain, each sensor sample joins the per-axis sums and the Welford statistics
instead of becoming a rate, the rate the loop downsamples stays stale as the reference's
does, and the final cycle turns the sums into the zero offsets, less the configured yaw
offset, unless an axis's deviation exceeds the movement limit, which restarts the
calibration. The zero offsets moved from the settings into the state for this reason. The
sums are held to a bound no configured duration reaches and the statistics stop counting
at their cap, both inert. The first arming calibration starts once per boot and reports
itself to the arming logic; the tone the reference sounds on the final cycle is a request
the caller places, since it depends on the arming flags. The overflow detection compares
the filtered rates against the sensor's full scale through the configured scale, on the yaw
axis or on all three, only for a device without overflow protection, and holds the
attitude lowpass while an overflow stands; the yaw spin detection compares the filtered yaw
rate against the threshold the setting or the rates' maximum yaw rate gives, with the
reference's integer truncation reproduced as a comparison against the next whole number.
The slew limiter the reference compiles only for three gyro devices on large targets is
not in this unit.

## D27. The dynamic notch as a unit of its own behind the gyro lowpass (2026-10-09)

`Adaflight.Dyn_Notch` holds the three sliding transforms, the peak list, the notch centers,
and the four-step cycle the reference runs one step per loop, one axis per four steps. The
gyro unit pushes each filtered rate into it, filters the rate through its notches, and
runs its update once per loop, in the reference's order. The state's predicate ties the
transforms to the batch count and keeps their bins where the windowed spectrum can read
one bin to each side, which the SDFT initialization now states in its postcondition. The
spectral sums are held to a power bound no saturated transform reaches, and three guards
stand where the reference's floats run on: the parabola offset is taken only when the
numerator is within the denominator, which a peak between two lower neighbours always
satisfies; the speed-up of the center smoothing takes its limit directly when the peak is
at least ten times the floor or the floor is zero, and one when the floor is negative, as
the reference's clamp of an infinite or negative quotient gives; and the start bin stays
one short of the last readable bin, where the reference reads past its spectrum for a
range above 250 Hz at a resolution under eight. The record of the highest center takes
the reference's truncation of the center to a whole number. None of the guards changes a
recorded vector. The slew of the notch at a loop slower than 500 microseconds is the
reference's: the filter stays inactive.

## D28. The RPM notches as a bank the gyro unit runs ahead of its static notches (2026-10-09)

`Adaflight.RPM_Filter` holds one weighted notch per motor and harmonic over the three
rates, the harmonic weights, and the schedule that moves a share of the bank to the motors'
reported frequencies each loop. The gyro unit runs it on the downsampled rates before the
static notches, in the reference's order, and takes the motors' frequencies and the loop's
measured period ratio as inputs each loop, because the motor telemetry and the scheduler
are outside it; the motor count and the telemetry flag join the gyro settings for the same
reason. Proof covers the schedule's wrap over the harmonics and motors and the bounds of
every coefficient for every loop time, motor count, and harmonic count at once, which a
test can only sample. Three points differ from the reference's floats. The filter stays off
when the minimum frequency is above the notch ceiling of the loop, a configuration the
reference admits with a pid loop slower than 480000 divided by the minimum frequency, in
microseconds (a 4 millisecond loop with a 150 Hz minimum), where its fade weight turns
negative or infinite. The fade weight is formed from a margin that the clamp of the
frequency to its range holds at or above zero, so the weight stays within one. The notch's
warped frequency keeps the tangent domain of the maths unit, 1.51 radians, which a notch at
the ceiling reaches only when the loop runs more than 0.125 percent slow; the reference's
tangent there grows without bound and turns negative past a quarter turn. The share of the
bank updated per loop is the reference's rounded-up quotient, held to its type by a clamp
no loop time reaches. The recorded vectors keep the period ratio at or under one, so the
tangent guard is not exercised by a vector; the others change none.
