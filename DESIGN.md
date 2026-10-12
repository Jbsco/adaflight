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

Amended 2026-10-11: the roadmap and the README's verification policy name Betaflight as
well. A document written for readers says Betaflight where Betaflight is the subject,
instead of sending the reader to the README for the name. This ledger keeps "the
reference" as its short name for Betaflight at the pinned commit. The sanitization gate
in `style.do` lists the documents allowed to carry the name.

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
- The runaway takeoff trigger deadline is compared through the wrapping difference as well,
  where the reference compares the counter and the deadline directly (findings F24). The
  recorded vectors stay clear of the wrap and replay bit for bit.
- The in-flight adjustments hold the feedforward gain at the configuration maximum of 1000,
  where the reference's step and dial adjustments reach 2000, and the horizon strength at or
  above the configuration minimum of 10, where the reference's selection reaches zero
  (findings F25 and F26). The recorded vectors keep both within the configuration bounds:
  the oracle starts the feedforward gains below 600, gives at most two feedforward ranges
  per sequence with low dial settings, and keeps the switch channels at or above 960
  microseconds.
- The receiver's reported RSSI is held at zero where the inverted, scaled, and offset value
  is negative. The reference converts that value to an unsigned 16-bit count, which is
  undefined; the target's conversion saturates to zero, and the oracle's host wraps. The
  checker expects zero wherever the recorded value is above 32767, which no defined value
  reaches, and the RSSI percentage of that value as zero with it.

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

## D29. Crash recovery inside the rate loop (2026-10-09)

The rate loop carries the reference's crash recovery where the reference keeps it: the
handling right after the error rate is formed, and the detection inside the D term once the
loop has run a second past the last entry into a level mode. The loop takes the arming
state, the accelerometer's presence, the gyro overflow, and the mixer's motor range as
inputs, because the arming, sensor, and mixer units own them, and it reports the recovery
state, the beeper request, and a disarm request that the arming unit consumes each loop.
While recovering, the yaw error is held to its limit, roll and pitch are levelled through
the angle gain when an accelerometer is present, the I term is dropped before it
accumulates, and the iterm relax is skipped; the recovery ends after its time limit or once
the craft is slow and, with an accelerometer, level. A gyro overflow zeroes every term, as
the reference does for an overflow or a disabled stabilisation. The GPS rescue mode's
enabling of the detection comes with the rescue port. Proof covers the setpoint the
levelling forms from the attitude and trim ranges through the angle gain, which stays inside
the rate type without a clamp, and the time comparisons through the wrapping clock
difference. No vector deviates.

## D30. The compass with its sphere fit held to bounds (2026-10-09)

`Adaflight.Compass` aligns the raw field as the accelerometer path does, through the
sensor's standard alignment or the rotation built from the negated custom angles, then the
board rotation, and keeps the reference's calibration: a wait for the gyro norm to pass
350 degrees per second within fifteen seconds, thirty seconds of the sphere fit while the
craft tumbles, the rounded bias as the new zero with a save request, and the zero
subtracted from every read. The fit is the reference's recursive least squares on the
factored covariance, in its operation order. Proof covers its floating point: every stored
quantity carries a range (the factor entries within 2 to the 24, the diagonal within 2 to
the 10, the parameters within 2 to the 16, the bias within 2 to the 20) and the projections,
gains, and weighted sums inside a step are held to theirs, so no product in the recursion
can overflow for a field within the aligned range. The bounds sit far outside the values a
magnetometer produces: over the recorded sequences the factor entries stay under twenty,
the diagonal under 110, and the parameters under one ten-thousandth. Two guards cover the
reference's own undefined cases. The bias is zero while the first parameter is within 2 to
the minus 100 of zero, where the reference divides by it and stores the result; and the
forgetting factor keeps its previous innovation gain when the weighted innovation turns
negative, where the reference's gain goes past one or through a division by zero. The
nearest whole count of the bias is held to the offset range, where the reference wraps the
rounded value into sixteen bits. The read interval the reference derives from the device's
data rate belongs to the scheduler. No recorded vector reaches a guard.

## D31. The compass heading in the attitude estimate (2026-10-09)

The attitude estimator takes the compass field and a flag for a calibrated compass each
update, since the compass unit owns both, and forms the reference's heading error: the
field turned into the earth frame by the current rotation and normalized, then set against
magnetic north in the ground plane, the north vector turned by the declination at
configuration. The error is the sine of the angle between them while the field points
forward, else the field's full ground-plane norm toward the shorter turn, and zero for a
field within a tenth of a count. The Mahony update adds the error, scaled by the earth-up
row of the rotation, to its error terms before the accelerometer's, in the reference's
order. The result is held to four, where a unit field against a unit north reaches one, so
the error terms keep their ranges; the ranges of the error and the integral step widened
for the added term. The GPS course over ground that shares the term, and the compass's
suppression of it, come with the GPS port. No recorded vector reaches the guard.

## D32. The position filter with bounded gains and covariances (2026-10-09)

`Adaflight.Position_Filter` is the reference's three-state Kalman filter for one axis, in
its operation order: the constant-jerk prediction through the two matrix accumulations,
the position and acceleration updates on their own diagonal entries, and the velocity and
position updates through their shared covariance in Joseph form. Proof covers the floating
point of every path: the state is held to 2 to the 24 centimeters, the covariance entries to
2 to the 40, each gain to 2 to the 16, and the two accumulations to typed intermediates, so
no product can overflow whatever the sequence of updates. The gains stay within one for a
consistent covariance and within the ratio of two variances otherwise, and the covariance
of a flight stays within a few million, so the guards sit far from the values the filter
produces; the reference's return on an innovation covariance below a nanobillionth is kept
as it is. The altitude estimator that feeds this filter from the barometer and the
accelerometer comes next. No recorded vector reaches a guard.

## D33. The altitude estimator from the barometer and the accelerometer (2026-10-09)

`Adaflight.Altitude_Estimator` is the vertical axis of the reference's position estimator
with the barometer and the accelerometer as its sources, in the reference's order per
position task: a change of arming resets the filter, the barometer's offset and gate, and
the smoothing; the vertical acceleration from the up row of the attitude rotation over the
scaled counts, zero while disarmed, corrects the filter and the prediction advances it; a
new barometer sample within its hold interval, less the offset taken from the first sample,
passes the step gate and corrects position and velocity together, or position alone after
ten rejections; and the validity, the trust, and the smoothed altitude and climb rate follow.
The GPS, rangefinder, and optical flow sources, the ground effect scaling they drive, and
the cross-calibration they anchor come with their ports; without an anchoring source the
reference leaves the barometer's offset untouched, as this unit does. The estimator takes
the sensors and the attitude as inputs because their units own them. Proof covers the
vertical acceleration through typed products and the filter's bounds; the trust is one
where the position variance is below zero, which no filter step produces, and the displayed
altitude is held to the rounding range. No recorded vector reaches a guard.

## D34. The altitude hold with the autopilot's altitude controller (2026-10-09)

`Adaflight.Altitude_Hold` keeps the reference's hold in its order per task: the engagement
from the flight mode, which resets the controller, takes the target from the current
altitude, and captures the hover throttle from the stick when no setting gives one; the
release, which resets the controller and drops the captured throttle; the target moved by
the stick outside its deadband around the hover throttle, or driven down at a rate that grows
with the altitude under a failsafe or an emergency descent, while the estimate stays within a
second of climb from the target; and the autopilot's altitude controller with the relaxed
integral, the proportional term held through the derivative gain, the boosted derivative, the
acceleration and feedforward terms, the hover offset, the tilt compensation, and the throttle
limits into a fraction of the receiver's range. The hold takes the mode, the task interval,
the stick and its low status, the failsafe, the emergency descent, the altitude estimate, and
the tilt as inputs, because their units own them; the navigation targets that can replace the
stick's come with the navigation port. One guard covers the reference's division by zero: a
stick beyond the receiver's range against a hover throttle at the range's edge leaves the
stick factor at zero. The target velocity is held to a bound a stick within the receiver's
range cannot reach. No recorded vector reaches a guard.

## D35. Launch control inside the rate loop (2026-10-09)

The rate loop carries the reference's launch control where the reference keeps it: while
the mode is active the setpoint is twice the stick's deflection within a half, scaled to the
launch rate, on pitch alone or on every axis, and on pitch run down to the minimum rate over
the last ten degrees before the angle limit and to zero past it; the iterm relax is skipped;
the integral gain is the launch gain on every axis, with the yaw windup limit and the
anti-gravity accelerator left as they were; the D term and the feedforward are zero; and
after each axis the yaw I term is held to its launch limit and, in the pitch-only mode, the
roll P and I terms and the yaw P term to zero and the pitch I term to at or above zero, so
each axis's sum sees the holds the reference's loop applies before it. The loop takes the
mode's activity and the yaw stick as inputs; the activation from the mode switch, the throttle
trigger, and the arming delay stay with the core loop's port. The launch setpoint and the
held terms are contracted helpers, and the setpoint's scaling over the angle window is held to
the launch rate, which a stick within a half cannot exceed. No recorded vector reaches a guard.

## D36. Launch control activation and runaway takeoff prevention in the core loop (2026-10-09)

The arming unit carries the reference's two core-loop guards in their places. Launch control
activates at arming when the switch is on, arming is by switch, the motors run or airmode is
on, there is no 3D, and no flight mode is selected; it triggers when the throttle passes its
percentage, which also requests an I term reset, and it clears on disarm, or on a trigger
only when the switch is off and the trigger reset is allowed; while active it keeps the
stabilisation on and airmode from latching. Runaway takeoff prevention runs after the
controller: a sum past 600 with a rate past 15 degrees per second on roll or pitch or 50 on
yaw, held for 75 milliseconds while armed and the motors run, disarms with its own reason and
disable flag; stable flight, with the throttle above the deactivation level and the sticks
active or above twice that level, and every sum under 100, ends the check once the delay has
accumulated, halved at high throttle. The controller's sums, the gyro's whole-degree rates,
and the sticks' deflections join the inputs, because their units own them, and the arming
attempt zeroes the runaway timers. The trigger deadline uses the wrapping difference, which
D6 records. The GPS rescue's hold on the runaway check and the temporary disable other
features request come with their ports.

## D37. In-flight adjustments (2026-10-09)

The adjustments unit carries the reference's adjustment task: the ranges that are set are
listed once into the steps, whose center is zero and whose function steps, and the dials;
each pass runs the steps whose range is active, with the half-second ready timer, one step
per hold of the switch past four tenths of its deflection from the configured center, and the
switch back at the center arming the next step at once; then, while the receiver has a
signal, the dials whose switch channel moved, selecting a profile, the horizon strength, the
master multiplier, or a peripheral mode by the position of the channel over the range of the
mode steps, or setting a stepping function from the dial through its scale and center. Every
step and dial change applies to the rate profile that was active when the pass began, as the
reference's task passes that profile by pointer. The unit owns the selections the profiles
and the peripherals read, the display the on-screen element names for two seconds after a
change, and the sticky configuration-dirty flag; it reports the confirmation beeps and the
PID, RC, and battery reinitializations a pass asks for, because their units own those. The
master multiplier runs the simplified tuning of the PID gains, ported in its own unit from the
reference defaults; the simplified filter sliders come with the configuration phase, as do the
OSD profiles. Two guards cover the reference's undefined behavior: a range whose function is
None is skipped where the reference reads outside its function table (finding F27), and a
dial value is held within two to the thirtieth before its conversion to an integer. The
feedforward and horizon strength holds are declared in D6. The display and the timers compare
through the wrapping difference as the reference does. No recorded vector reaches a guard.

## D38. The cooperative scheduler as phases around the clock reads (2026-10-09)

The scheduler unit carries the reference's task scheduler: the task table with each task's
period, static priority, and check function; the queue of enabled tasks ordered by static
priority with equal priorities in order of arrival; the gyro cycle the realtime gyro,
filter, and PID tasks lock to, with the recovery from a gross overrun, the start wait tuned
up when the loop arrives late and down when it polls, the gyro rate measured over 25000
interrupts, and the skew to the interrupts removed every 50; the dynamic priorities that
grow with the periods a task has waited, the check functions that signal the event-driven
tasks, and the fit of the highest-priority task into the time left before the next gyro
cycle, with the measured check time and the guard margin tuned on each run's overrun, the
deferral that lets an unfit task run every eighth pass, and the tenth cut from the estimate
of a task skipped often enough; and the execution statistics in the reference's units. One
pass of the reference runs the tasks and reads the clocks inline, so the unit splits it into
phases at those points: the pass begins with the first cycle reading, the caller polls up to
the target and runs the realtime tasks between the execution prologue and epilogue, the
realtime block ends with the gyro lock, the selection begins with the second reading and
takes each queued task in turn with its check's result, ends with the third, the fourth
confirms the fit, and the fifth follows the run. The caller reads the cycle counter at the
same points the reference does, so the replay of the recorded passes, with a cycle per read
and the recorded durations, matches cycle for cycle. Every count keeps the reference's
32-bit wrapping arithmetic through the two casts between the signed and unsigned counts.
Two guards cover the reference's divisions by zero: the overrun recovery and the skew run
only while the gyro period in cycles is positive, where the reference divides by it as it
stands. No recorded vector reaches a guard.

## D39. The beeper (2026-10-09)

The beeper unit carries the reference's beeper: the sound table in priority order, a
request that starts its sound only when it outranks the one playing and that silences the
beeper for the silence mode, the mute switch, or the bench suppression of the USB flag with no
battery and a USB or configurator link; the sequences of on and off durations in tens of
milliseconds, a leading zero for a pause first, ended by a stop or a repeat; the multi-beep
buffer the confirmation beeps, the warning beeps, and the satellite count fill and play through
the multi-beep entry, with room kept for the stop; and the periodic update, which requests the
beep switch's sound or the satellite count, raises the DShot beacon when the motors are stopped
and the link is lost without a configurator or the beep switch is on with a link, past the
guard after a disarm, not while arming, and at most every 450 milliseconds, clamps the beacon
time to a minute's age, and then plays the next step of the sequence once its toggle time has
passed, recording the first on step of an arming sound as the arming beep's time. The unit
owns the beeper's on state, the warning LED's enable, and the visual beep's edge; it reports
the beacon command, the visual beep, and the scheduler's exec-time waiver as the update's
outputs, because their units own those. The conditions the beeper reads from the battery, the
links, the mode boxes, the GPS, the motors, the failsafe, and the arming state come in as a
record. The arming beep's time is the update's time, where the reference reads the clock
again. One guard covers the reference's read past its buffer: a sequence that reaches the end
of the buffer without a stop ends as an error and silences the beeper, where the reference
walks into adjacent memory (finding F29). No recorded vector reaches a guard.

## D40. The receiver (2026-10-09)

The receiver unit carries the reference's channel processing: the raw channels of the active
provider read through the map into flight order, the four flight channels scaled through
their calibration ranges, which invert a channel whose low end is above its high end and
which the type keeps from equal ends, where the reference's scale divides by zero (finding
F31); the frame check that marks the signal and the data to process on a received frame,
drops the signal 150 milliseconds after the last frame and asks for the loss to be processed
and then rechecks every 50 milliseconds; the signal loss behaviour that resets a good
channel's hold timer, holds a bad channel at its last value for 300 milliseconds and then at
its failsafe setting, declares the flight channels invalid on a bad flight channel past that,
applies the failsafe switch's settings at once, and in stage two keeps the valid flight
channels and sets the failsafe throttle and the center on the others and the settings on the
aux channels; the three-sample moving average of the pulse receivers with their suspension and
their two skipped samples; the link quality from the last sixteen frames; and the RSSI from an
aux channel, the frame errors over each 100 milliseconds, the analog input every 20
milliseconds, the protocol, or the configurator with its 1.5-second timeout, smoothed toward
its raw value with the dBm and the SNR. The frame's flags, the raw channels, the failsafe
switch, the 3D switch, the stage, and the task's state come in; the data to process, the
auxiliary frame to process, and the validity the failsafe hears go out, because their units
own them. The frame error sum keeps the reference's 16-bit wrap (finding F30). Every
conversion of a channel value to a 16-bit count holds a value outside the count at the
bound, where the reference's conversion is undefined; the negative RSSI case is declared in
D6, and the recorded vectors keep the pulses and the ranges where the scaled values stay
within the count. No recorded vector reaches a guard.

## D41. The SBUS protocol (2026-10-10)

The SBUS unit carries the reference's SBUS receiver. Each serial byte arrives with its time.
A gap of more than five byte times restarts the frame. A frame starts only on the begin byte,
and the twenty-fifth byte completes it. The status poll decodes a complete frame once: the
sixteen eleven-bit channels from the little-endian bit stream of the twenty-two channel bytes,
and the two digital channels from their flags. The poll reports failsafe when the receiver flags
it and dropped when it flags a signal loss. Otherwise it keeps the frame's start as the frame
time. The raw value the receiver reads is the channel's fit to the X4R, five eighths of the
count plus 880. Every channel starts at the count that reads as the configured center. The
serial port and the telemetry sharing stay with the port layer. The reference's packed bit
fields are unpacked by position, so the decoded channels agree bit for bit. No guard was
needed.
## D42. The CRSF protocol (2026-10-10)

The CRSF unit carries the reference's CRSF receiver. Each serial byte arrives with its time into
a frame. The frame restarts after the time a frame needs at the current rate, and a restart with
a frame under way counts an error. The declared length is checked as it arrives, and an invalid
one drops the frame without an error. The CRC runs over the type and the payload with the
DVB-S2 polynomial. A good frame clears the error count and asks for a telemetry response. The RC
channel frames for the flight controller are copied for the status poll. The poll unpacks the
sixteen eleven-bit channels of the packed frame, or the subset frame's channels at its ten to
thirteen-bit resolution from its start channel. A subset with no channels or a start past the
last is dropped. The link statistics for the flight controller go into the receiver: the active
antenna's RSSI in dBm scaled onto the RSSI range when the protocol owns the RSSI, the dBm, the
antenna, the SNR, the link quality and RF mode when the protocol owns the quality, and the
uplink power from its table. The transmitter statistics of the third version go the same way.
The 250-millisecond statistics timeout at each poll zeroes the owned values. A command frame for
the flight controller is checked by the command CRC and reported for the port layer to process.
The error count asks for the default speed at three, unless a baud negotiation or an EEPROM
write is under way. The raw channel value goes through the frame type's scale. A negotiated
rate recomputes the frame time, and above the default rate the inbound frames drive the
telemetry. The serial port, the telemetry, and the configurator frames stay with their layers.
The frame time and the frame's start are kept in the unit, as the SBUS unit keeps them. Two
guards cover values the reference's conversions leave undefined: a scaled RSSI below zero is
held at zero, and a frame whose declared length escaped the check is held to the frame size. The
receiver takes the protocol's claims of the RSSI and the link quality at its own init. No
recorded vector reaches a guard.
## D43. The SUMD and SUMH protocols (2026-10-10)

The SUMD unit carries the reference's SUMD receiver. Each byte arrives with its time, and a gap
over four milliseconds restarts the frame. The sync byte starts the frame and clears the CRC.
The third byte gives the channel count. The bytes are kept while the buffer has room. The CRC
runs over the header and the channels, and the frame completes two bytes after the channels.
The status poll takes a complete frame only when its CRC matches the two bytes after the
channels. The state byte makes the frame failsafe or complete, and up to eighteen channels are
copied. The raw value is the channel's eighth. A frame that declares more than thirty-two
channels is dropped at the poll, where the reference reads its CRC bytes past the buffer
(finding F32). The caller takes the unit's frame time for a frame that is not failsafe, as the
reference publishes it. The SUMH unit carries the simpler SUMH receiver: twenty-one bytes, with
a restart after a gap over five milliseconds. The poll takes the eight channels when the sync
byte and the zero before the last byte check. Each goes through the reference's scale, a sixth
and four tenths less 375, and is held at zero where the reference's conversion of a negative
value is undefined. The raw value reads zero past the eighth channel. The recorded vectors keep
the channel words where that conversion is defined. The serial ports stay with the port layer.
No recorded vector reaches a guard.
## D44. The IBUS protocol (2026-10-10)

The IBUS unit carries the reference's IBUS receiver for its two receiver families. Each byte
arrives with its time. A gap over 500 microseconds starts a new frame and ends any echo skip. A
byte of a telemetry reply's echo is skipped. A frame starts on an IA6B length byte (four for a
telemetry request, thirty-two for channels), on the IA6 sync byte before any family is known,
or on the known sync byte. The last byte of the frame's length completes it. The status poll
takes a complete frame once its checksum matches: the IA6B subtraction from all ones over the
bytes before the two checksum bytes, or the IA6 sum of the fourteen slots onto the seed. The
poll decodes the eighteen channels, fourteen from the slots' twelve bits and four from the
spare high bits, or reports a telemetry request from a short IA6B frame. The reference checks
that the frame has room for each of the four high-bit channels, which holds for both families'
offsets, so the unit reads them without the check. The telemetry layer hands back the length of
its reply so its echo is skipped. The raw value is the channel count itself. The state's
predicate ties the family to its sync byte, frame length, and slot offset and keeps the frame's
first byte equal to the sync byte. The checksum and channel reads are therefore proved within
the frame without clamps, and a frame start writes those fields as one aggregate to keep the
predicate. A byte is kept only while the frame has room. The reference writes past its buffer
when a zero byte before any sync is known is followed by more than thirty-one bytes without a
gap (finding F33). The telemetry reply itself is Phase 6, and the serial port stays with the
port layer. No recorded vector reaches the guard.
## D45. The Spektrum protocols (2026-10-10)

The Spektrum unit carries the reference's DSM receiver for its two resolutions and the SRXL
variant. Each byte arrives with its time. A gap over five milliseconds starts a new frame, and
the sixteenth byte completes the frame at its own time. The status poll takes a complete frame
once and fills the RSSI channel first. For SRXL the RSSI channel comes from the dBm report in
the first byte, held through four fades and dropped to the minimum at the fifth, through the
range table onto the resolution. For a satellite receiver it comes from the fade count: one
byte with the system type while the receiver reads as bound by the flight controller, and two
bytes once a frame says otherwise. The count is differenced over the half second and mapped
from the fade limit down to zero, with the reference's sixteen-bit conversion wrapping it. The
poll then takes the VTX control word from the last four bytes of a first-phase frame for the
VTX layer and leaves those bytes out of the channels. The channel pairs that remain are decoded
by the resolution's shift and mask into the channels below the count, and the RSSI channel is
skipped. A first-phase frame opens the SRXL telemetry request. Once a queued reply has waited
a millisecond after the request, the poll asks for processing, which sends the reply and clears
it. The raw value is zero past the channel count, half the count plus 988 at the high
resolution, and the count plus 988 otherwise. The settings give the provider, whether the
telemetry feature is on with the port unshared, and the one-based RSSI channel. A channel past
the count is dropped, as the reference's byte wrap drops zero. The range table's interpolation
runs on typed intermediates sized from the table, so it proves without clamps. The fade
mapping's wrap is the reference's own. The VTX control handling, the telemetry content, the
bind pulses, and the serial port stay with their layers. The reference assembles the VTX
control word with a shift that overflows a signed integer on every control frame (finding
F34). The unit shifts the unsigned word. No guard was needed.
## D46. The XBUS protocol (2026-10-10)

The XBUS unit carries the reference's XBUS receiver for the Mode B and RJ01 providers. Each
byte arrives with its time, and a gap over eight milliseconds drops the frame in progress. A
frame starts on the twelve-channel start byte, or on the sixteen-channel one in Mode B, with
the length the provider and the start byte give it. The last byte of that length unpacks the
frame where the reference does, in the receive path rather than at the status poll. A Mode B
frame yields its twelve channels through the pulse conversion, 800 plus the word's 1400
fraction of 4096, once the CRC-16 over all but its last two bytes matches them. An RJ01 outer
frame yields the Mode B frame three bytes in once its length byte reads 30 and the Dallas CRC-8
over all but its last byte matches that byte. The status poll reports complete once per
unpacked frame. The raw value is the channel value itself. The reference's Mode B case falls
through into the RJ01 check after its own unpack (finding F35). The unit keeps that order so
the recorded vectors match, stale buffer bytes included. The state's predicate keeps the
position below the frame length while a frame comes in and at zero otherwise, and ties the
length to the provider. The frame writes and the unpackers' reads are therefore proved within
the buffer without clamps. The completion check moves ahead of the position increment to keep
the predicate. The serial port stays with the port layer. No guard was needed.
## D47. The Jeti EX Bus protocol (2026-10-10)

The Jeti EX Bus unit carries the reference's EX Bus receiver. Each byte arrives with its time,
and a gap over a millisecond drops the frame in progress. A frame starts on the channel or the
request sync byte into its own buffer. The second byte says whether the receiver may transmit.
The sixth byte's message length takes the frame when it is within its buffer's range and drops
it otherwise. A byte at the buffer's end drops the frame. The last byte of the length completes
the frame with its time: the channel frame for the status poll, the request frame for the
telemetry. The status poll takes a received channel frame once. When the CRC over the frame
reads zero, the poll decodes the channels and keeps the frame's time. It decodes as many words
as the data length holds, up to sixteen, each word's eighth, when the header names channel data
with or without a request. The raw value is the channel value itself. The unit keeps the
received frame's length beside the buffer, where the reference reads the buffer's length byte
again at the poll. The byte cannot change between the completion and the poll, since a new
frame into that buffer takes the state out of received first, so the two reads agree. The
state's predicate keeps the position within the size of the buffer the bytes go to, so the
buffer writes are proved without clamps. The CRC runs on eight- and sixteen-bit modular words as
the reference's nibble-wise form does. The decode trusts the header's data length over the
message length as the reference does (finding F36). The request frame, its state and time, the
transmit permission, and the serial port stay with the telemetry and port layers. No guard was
needed.
## D48. The Ghost protocol (2026-10-10)

The GHST unit carries the reference's Ghost receiver. Each byte arrives with its time, and a
byte after the frame time of 500 microseconds starts a new frame. The frame is five bytes long
until its length byte is in, and that byte plus two after. A byte is kept while the frame has
room. The last byte of a frame addressed to the flight controller swaps the two buffers, marks
the frame available, and stamps its end. The status poll takes an available frame once. The
frame is complete with processing to do when the CRC over its type and payload matches its last
byte, and dropped otherwise. With no frame available, the poll asks for processing alone when a
telemetry reply waits and the bus has been quiet for more than one and less than two
milliseconds since the last frame. The processing sends the reply in that window and then
decodes the validated frame. A statistics frame sets the RF protocol with the telemetry it
allows and gives the receiver its RSSI, dBm, and link quality. The aux frames name the four
channels they carry in turn. Once the protocol is known, the four primary channels come from
their packed twelve bits, the aux four widened from eight, and a legacy frame is rescaled to
the twelve-bit range. The MSP frames go to the MSP layer with their payload length. The raw
value is a quarter of a primary count or an aux count as it is, plus 988. The unit keeps the
completed frame's length beside the buffers, where the reference reads the length byte again
at the poll and the processing. The validated buffer is not written until the next swap, so
the two agree. The swap itself is kept so the stale bytes of a short frame come from the same
buffer as the reference's. The RSSI scaling and the legacy rescaling keep the reference's
sixteen-bit wraps of their negative results (findings F37, F38), so the recorded vectors match.
The telemetry content, the MSP handling, the idle callback's source, and the serial port stay
with their layers. No guard was needed.
## D49. The MSP receiver (2026-10-10)

The MSP receiver unit carries the reference's receiver fed over MSP. A frame from the command
handler sets the channels it carries and resets the ones it leaves out to zero. It marks the
frame done for the receiver and for the override path, and keeps its time and channel count. A
channel is fresh while a frame has ever arrived, the last frame carried it, and the frame
arrived within the last 300 milliseconds. The status poll reports complete once per frame and
stamps the frame at the poll. The override poll reports complete once per frame. The raw value
is the channel value itself. The command handler bounds the count at eighteen, so the count is
a subtype. The millisecond difference is the reference's unsigned one. No guard was needed.
## D50. The SRXL2 protocol (2026-10-10)

The SRXL2 unit carries the reference's SRXL2 receiver. Each byte arrives with its time and goes
into the read buffer while it is free and has room. Otherwise the packet is dropped. The port's
idle ends a transmission, frees the read buffer when nothing came in, or hands the packet over
by swapping the two buffers with the idle time kept. The status poll processes the handed-over
packet. The packet is dropped unless its id, its length byte, and its CRC over the whole packet
check, and then it is valid at the poll's time. A broadcast handshake names the bus master,
takes the fast rate when the master supports it, and runs the link. A handshake to this unit
gets the reply with the ids swapped, the priority, and the rate offered. Control data requests
telemetry when its reply id is this unit's. Its channel data gives the RSSI percent onto the
receiver's range when it is not negative, a dropped frame when the mask is empty, and each
channel under the mask from the next word. Its failsafe sets the RSSI to zero. Its VTX data is
packed into the Spektrum control word for the VTX layer. The link state machine then runs. It
listens for activity and toggles the rate while bytes come without a valid packet. At its
timeout it moves to sending or listening for a handshake. When a handshake or the frames time
out, it falls back to listening at the default rate with a failsafe result. Processing is asked
for when the write buffer holds a reply, and the processing sends it once the bus has been idle
for the reply quiescence. The bind request and the telemetry frame the telemetry layer fills go
out through the same write buffer with the CRC in their last two bytes. The raw value is the
count's quarter over sixteen plus 988. The reference reads a handshake's or a control packet's
fields without checking the packet's length against them, so a short packet yields stale buffer
bytes. The unit reads the same bytes from the same buffer so the recorded vectors match
(finding F39). The sending state asks for processing without a reply to send (finding F40),
kept as the reference has it. The baud rate the unit asks of the port is kept as its own field,
where the reference asks the port back. The telemetry content, the MSP and VTX handling, the
serial port, and the idle callback's source stay with their layers. No guard was needed.

## D51. The FPORT protocol (2026-10-10)

The FPORT unit carries the FrSky FPORT receiver. Each serial byte arrives with its time. A
marker byte closes the frame in progress when it holds two bytes or more. The frame goes into
a ring of three buffers when the ring has room, a telemetry request opens the reply window and
stamps its time, and the marker starts the next frame. A byte after the escape has its fifth
bit flipped, the byte in the type position marks a telemetry request, and a byte is kept
while the frame has room. A frame older than the frame time plus half a millisecond is
dropped, and so is one that outgrows its buffer. The status poll takes one frame from the
ring. The frame counts when its length byte agrees with the frame and the FrSky checksum
folds to all ones. A control frame decodes its channels and flags through the SBUS channel
block, which the SBUS unit now exposes for both protocols, scales its RSSI from a percentage
onto the receiver's range, stamps the control time, and keeps its start as the frame time
unless the receiver flags failsafe or a signal loss. A telemetry request counts only while
the telemetry layer is on. A data frame hands the frame rate to the receiver and asks for a
reply. A null frame asks for a reply until two have gone unanswered while the receiver does
not drive the rate, unless an MSP payload waits. A read or write frame keeps its payload for
the telemetry layer. The poll asks for processing when a reply or a payload waits and half a
millisecond has passed since the window opened, and it drops the RSSI to zero half a second
after the last control frame. The processing closes the window two milliseconds after it
opened, consults the telemetry layer while it is open, sends the empty reply when the layer
left the window unused, and consumes the payload. The reply's bytes, the telemetry content,
the MSP handling, and the serial port stay with their layers. A reply the telemetry layer
writes drops the frame in progress through Begin_Reply. The raw value is the SBUS fit of the
channel count. The ring indices, the frame position, and the escape and request flags keep
the state the recorded vectors see. No guard was needed.
