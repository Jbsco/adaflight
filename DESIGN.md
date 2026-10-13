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
- The GPS rescue takes the bearing home from the double-precision arctangent of the Ada
  runtime rounded to single (D83), where the reference calls the C library's
  single-precision one. That function's last bit differs between glibc 2.39 and 2.44, and
  the recorded vectors carry the values of the host that recorded them, which the double
  route reproduces. The declared tolerance is 1 on the target heading and 256 on the error
  angle, the difference of two headings.
- The ExpressLRS receiver's signal to noise mean holds its sample count at 2 ** 24 - 1 and
  adds nothing past it, where the reference's 32-bit sum of 8-bit readings overflows after
  that many packets without a telemetry response (findings F100). The recorded vectors stay
  far below the count and replay bit for bit.
- The position navigation target holds its commanded velocities within 2 ** 60 metres per
  second, walks a target flown at a stated velocity within 262 kilometres of the origin,
  takes the vertical ramp's slew deceleration as 2 ** 100 metres per second squared where the
  remaining altitude error is below half a micrometre, starts a leg picked up with a chase
  velocity below a ten-billionth of a metre per second from rest, and holds the settle time at
  2 ** 30 seconds, where the reference's floats run on to infinity or carry a vanishing
  velocity. The recorded vectors stay far inside every one of these and replay bit for bit.

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

`Adaflight.Modes` keeps the two lists of activation conditions, the own-range conditions and the
linked ones, as index arrays with counts whose sum the state's predicate bounds at the condition
count, so the loop that fills them proves its indices from one invariant and the update loops
read within them. The masks are Boolean arrays over the box enumeration rather than bit words,
so a box identifier out of range cannot exist. The vector checker folds them back into the
reference's words. The boot delay before a sticky box may disarm compares the microsecond
counter directly, since the delay is a one-shot after boot.

## D20. Accelerometer counts and offsets are held to their ranges (2026-10-08)

`Adaflight.Accelerometer` carries the path from the raw counts to the values the attitude
estimator reads. Two bounds are stated where the reference relies on its types silently. An
aligned count is held within 2 ** 18, which a standard alignment cannot reach and a custom
rotation, whose matrix entries are within two, cannot exceed on 16-bit counts, so the saturation
is inert. The calibration totals add each cycle's float sample to an integer total and truncate
back, and saturate at 2 ** 28, which 400 cycles of such counts cannot reach. The offsets are the
rounded means less the gravity count on the vertical axis. The reference stores each offset in a
16-bit field that wraps when the mean exceeds it. The port saturates the offset at the field's
range instead, which no sensor near one gravity reaches. The in-flight calibration, the board
alignment, and the configuration flag that records a completed calibration are not in this unit.
The magnitudes take the norms of the acceleration and the jerk held to bounds the root of three
squares within their component ranges cannot reach, so their scaling by the reciprocal of one g
proves apart from the update.

## D21. The barometric power saturates at eight (2026-10-08)

`Adaflight.Barometer` turns a pressure into an altitude through the power of its ratio to the
sea-level pressure. A pressure within the 32-bit range keeps that power below seven, so the
power is held at eight before the altitude is formed, which bounds the altitude and the
calibration sums by type. The saturation is inert. The device state machine that schedules the
temperature and pressure reads is the driver's, and the port takes each pressure sample with the
time of its read. The calibration keeps an integer mean of the temperature and a float mean of
the altitude, with both sums saturating at their types' bounds, which one hundred samples cannot
reach. The drift product is formed in 64 bits where the reference's 32-bit product would wrap
above a two-degree-million difference, which no device reports.

## D22. Battery meters in integer arithmetic (2026-10-08)

`Adaflight.Battery` keeps the voltage and current meters in integer arithmetic: the divider
scaling in 32-bit unsigned steps held to the 16-bit field it stores into, the current scaling in
32-bit signed steps, the cell thresholds in 16-bit unsigned products, and the filtered analog
counts truncated back to counts before scaling. The stability record is a shifted bit mask. Only
the analog meters are ported. The ESC, virtual, and MSP sources reset their meter when a source
is absent. The cutoff percentage is held to its range where the reference's byte leaves it after
a clock wrap during the ramp, and the charge sum and energy saturate at their float types'
bounds, which no pack reaches.

## D23. Sensor readings are aligned before they are scaled (2026-10-08)

The gyro and the accelerometer carry their alignment in one order: the counts, less the gyro's
zero offsets, go through the sensor's standard rotation or its custom rotation matrix, then
through the board rotation when the board angles are not all zero, and only then through the
scale. The permutations of a standard rotation commute with the scale but the matrices do not,
so the order is kept for the custom and board cases. The gyro zero offsets stay per raw axis,
since the calibration runs before the alignment. The board rotation matrix is built from whole
degrees through the same conversion and rotation as the sensor's, and the matrices sit in the
state with their entries bounded by two, which bounds the aligned counts by type.

## D24. The arming logic as a flag machine (2026-10-09)

`Adaflight.Arming` holds the arming flags, the thirty disable reasons as a Boolean array in
their bit order, and the flight mode flags, so the reason the warning beeps count out is the
first true element. The unit takes what the other units report (the link, the failsafe, the
attitude, the calibrations, the motor protocol) in an input record per pass and returns what it
asks of them (the beeps, the stick commands, the calibration and save requests, the
stabilisation state) in an output record, so it depends on no unit that is not yet ported. The
three passes keep the receiver task's order: the receiver pass, the modes pass with the stick
combinations, the mode update and the flight mode selection, then the arming status. The
throttle percent holds its fraction to the unit range and guards a zero divisor. Both are inert
within the configuration ranges (a minimum check below 2000 microseconds, a 3D mid value and
deadband that leave a span below full throttle). The automatic disarm deadline is compared
through the wrapping difference where the reference compares the counters directly (D6). The
stick hold time is a 16-bit count with its saturation, and the disarm tick counter a wrapping
byte. Not in this unit: the DShot beacon delay, crash flip and spin direction, launch control,
the GPS rescue arming checks, the runaway takeoff detection, the in-flight accelerometer
calibration, the shared port telemetry switch, and the adjustments, which belong with their own
units.

## D25. Level modes inside the rate loop (2026-10-09)

The angle and horizon modes stay in the rate loop between the acceleration limit and the iterm
relax, so the loop's order holds: the angle target from the stick through the angle limit and
the rate at full deflection, the attitude less the trims, the angle feedforward through its own
filter, the yaw compensation while rolled or pitched, the attitude filter, and the horizon
crossfade. The attitude, the trims, the stick deflections, and the full-deflection rates arrive
as inputs of the loop, since the units that produce them run before it. The horizon strength and
the level rate carry the type bounds their configuration ranges allow (a strength of up to six
hundred, a feedforward of up to four million degrees per second), and saturate at the signal
bound and the rate bound where the reference's floats run on. None of the saturations is reached
in the recorded vectors. The level mode start time is kept for the crash recovery guard, which
is not yet ported, and the GPS rescue, altitude hold, position hold, and launch inputs to the
level target are not in this unit.

## D26. Gyro calibration and the full-scale detections in the gyro unit (2026-10-09)

The zero offset calibration lives with the gyro filtering. While cycles remain, each sensor
sample joins the per-axis sums and the Welford statistics instead of becoming a rate, the rate
the loop downsamples stays stale, and the final cycle turns the sums into the zero offsets, less
the configured yaw offset, unless an axis's deviation exceeds the movement limit, which restarts
the calibration. The zero offsets moved from the settings into the state for this reason. The
sums are held to a bound no configured duration reaches and the statistics stop counting at
their cap, both inert. The first arming calibration starts once per boot and reports itself to
the arming logic. The tone the reference sounds on the final cycle is a request the caller
places, since it depends on the arming flags. The overflow detection compares the filtered rates
against the sensor's full scale through the configured scale, on the yaw axis or on all three,
only for a device without overflow protection, and holds the attitude lowpass while an overflow
stands. The yaw spin detection compares the filtered yaw rate against the threshold the setting
or the rates' maximum yaw rate gives, with the integer truncation of the rate reproduced as a
comparison against the next whole number. The slew limiter the reference compiles only for three
gyro devices on large targets is not in this unit.

## D27. The dynamic notch as a unit of its own behind the gyro lowpass (2026-10-09)

`Adaflight.Dyn_Notch` holds the three sliding transforms, the peak list, the notch centers, and
the four-step cycle that runs one step per loop, one axis per four steps. The gyro unit pushes
each filtered rate into it, filters the rate through its notches, and runs its update once per
loop. The state's predicate ties the transforms to the batch count and keeps their bins where
the windowed spectrum can read one bin to each side, which the SDFT initialization now states in
its postcondition. The spectral sums are held to a power bound no saturated transform reaches,
and three guards stand where the reference's floats run on: the parabola offset is taken only
when the numerator is within the denominator, which a peak between two lower neighbours always
satisfies. The speed-up of the center smoothing takes its limit directly when the peak is at
least ten times the floor or the floor is zero, and one when the floor is negative, as the
reference's clamp of an infinite or negative quotient gives. The start bin stays one short of
the last readable bin, where the reference reads past its spectrum for a range above 250 Hz at a
resolution under eight. The record of the highest center truncates the center to a whole number.
None of the guards changes a recorded vector. At a loop slower than 500 microseconds the filter
stays inactive.

## D28. The RPM notches as a bank the gyro unit runs ahead of its static notches (2026-10-09)

`Adaflight.RPM_Filter` holds one weighted notch per motor and harmonic over the three rates, the
harmonic weights, and the schedule that moves a share of the bank to the motors' reported
frequencies each loop. The gyro unit runs it on the downsampled rates before the static notches,
and takes the motors' frequencies and the loop's measured period ratio as inputs each loop,
because the motor telemetry and the scheduler are outside it. The motor count and the telemetry
flag join the gyro settings for the same reason. Proof covers the schedule's wrap over the
harmonics and motors and the bounds of every coefficient for every loop time, motor count, and
harmonic count at once, which a test can only sample. Three points differ from the reference's
floats. The filter stays off when the minimum frequency is above the notch ceiling of the loop,
a configuration the reference admits with a pid loop slower than 480000 divided by the minimum
frequency, in microseconds (a 4 millisecond loop with a 150 Hz minimum), where its fade weight
turns negative or infinite. The fade weight is formed from a margin that the clamp of the
frequency to its range holds at or above zero, so the weight stays within one. The notch's
warped frequency keeps the tangent domain of the maths unit, 1.51 radians, which a notch at the
ceiling reaches only when the loop runs more than 0.125 percent slow. The reference's tangent
there grows without bound and turns negative past a quarter turn. The share of the bank updated
per loop is the rounded-up quotient, held to its type by a clamp no loop time reaches. The
recorded vectors keep the period ratio at or under one, so the tangent guard is not exercised by
a vector. The others change none.

## D29. Crash recovery inside the rate loop (2026-10-09)

The rate loop carries the crash recovery at two points: the handling right after the error rate
is formed, and the detection inside the D term once the loop has run a second past the last
entry into a level mode. The loop takes the arming state, the accelerometer's presence, the gyro
overflow, and the mixer's motor range as inputs, because the arming, sensor, and mixer units own
them, and it reports the recovery state, the beeper request, and a disarm request that the
arming unit consumes each loop. While recovering, the yaw error is held to its limit, roll and
pitch are levelled through the angle gain when an accelerometer is present, the I term is
dropped before it accumulates, and the iterm relax is skipped. The recovery ends after its time
limit or once the craft is slow and, with an accelerometer, level. A gyro overflow zeroes every
term, as a disabled stabilisation does. The GPS rescue mode's enabling of the detection comes
with the rescue port. Proof covers the setpoint the levelling forms from the attitude and trim
ranges through the angle gain, which stays inside the rate type without a clamp, and the time
comparisons through the wrapping clock difference. No vector deviates.

## D30. The compass with its sphere fit held to bounds (2026-10-09)

`Adaflight.Compass` aligns the raw field as the accelerometer path does, through the sensor's
standard alignment or the rotation built from the negated custom angles, then the board
rotation, and keeps the calibration: a wait for the gyro norm to pass 350 degrees per second
within fifteen seconds, thirty seconds of the sphere fit while the craft tumbles, the rounded
bias as the new zero with a save request, and the zero subtracted from every read. The fit is a
recursive least squares on the factored covariance. Proof covers its floating point: every
stored quantity carries a range (the factor entries within 2 to the 24, the diagonal within 2 to
the 10, the parameters within 2 to the 16, the bias within 2 to the 20) and the projections,
gains, and weighted sums inside a step are held to theirs, so no product in the recursion can
overflow for a field within the aligned range. The bounds sit far outside the values a
magnetometer produces: over the recorded sequences the factor entries stay under twenty, the
diagonal under 110, and the parameters under one ten-thousandth. Two guards cover the
reference's own undefined cases. The bias is zero while the first parameter is within 2 to the
minus 100 of zero, where the reference divides by it and stores the result. The forgetting
factor keeps its previous innovation gain when the weighted innovation turns negative, where the
reference's gain goes past one or through a division by zero. The nearest whole count of the
bias is held to the offset range, where the reference wraps the rounded value into sixteen bits.
The read interval derived from the device's data rate belongs to the scheduler. No recorded
vector reaches a guard.

## D31. The compass heading in the attitude estimate (2026-10-09)

The attitude estimator takes the compass field and a flag for a calibrated compass each update,
since the compass unit owns both, and forms the heading error: the field turned into the earth
frame by the current rotation and normalized, then set against magnetic north in the ground
plane, the north vector turned by the declination at configuration. The error is the sine of the
angle between them while the field points forward, else the field's full ground-plane norm
toward the shorter turn, and zero for a field within a tenth of a count. The Mahony update adds
the error, scaled by the earth-up row of the rotation, to its error terms before the
accelerometer's. The result is held to four, where a unit field against a unit north reaches
one, so the error terms keep their ranges. The ranges of the error and the integral step widened
for the added term. The GPS course over ground that shares the term, and the compass's
suppression of it, come with the GPS port. No recorded vector reaches the guard.

## D32. The position filter with bounded gains and covariances (2026-10-09)

`Adaflight.Position_Filter` is a three-state Kalman filter for one axis: the constant-jerk
prediction through the two matrix accumulations, the position and acceleration updates on their
own diagonal entries, and the velocity and position updates through their shared covariance in
Joseph form. Proof covers the floating point of every path: the state is held to 2 to the 24
centimeters, the covariance entries to 2 to the 40, each gain to 2 to the 16, and the two
accumulations to typed intermediates, so no product can overflow whatever the sequence of
updates. The gains stay within one for a consistent covariance and within the ratio of two
variances otherwise, and the covariance of a flight stays within a few million, so the guards
sit far from the values the filter produces. The early return on an innovation covariance below
a nanobillionth is kept. The altitude estimator that feeds this filter from the barometer and
the accelerometer comes next. No recorded vector reaches a guard.

## D33. The altitude estimator from the barometer and the accelerometer (2026-10-09)

`Adaflight.Altitude_Estimator` is the vertical axis of the position estimator with the barometer
and the accelerometer as its sources, per position task. A change of arming resets the filter,
the barometer's offset and gate, and the smoothing. The vertical acceleration from the up row of
the attitude rotation over the scaled counts, zero while disarmed, corrects the filter and the
prediction advances it. A new barometer sample within its hold interval, less the offset taken
from the first sample, passes the step gate and corrects position and velocity together, or
position alone after ten rejections. The validity, the trust, and the smoothed altitude and
climb rate follow. The GPS, rangefinder, and optical flow sources, the ground effect scaling
they drive, and the cross-calibration they anchor come with their ports. Without an anchoring
source the barometer's offset stays untouched. The estimator takes the sensors and the attitude
as inputs because their units own them. Proof covers the vertical acceleration through typed
products and the filter's bounds. The trust is one where the position variance is below zero,
which no filter step produces, and the displayed altitude is held to the rounding range. No
recorded vector reaches a guard.

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
## D52. The MAVLink receiver (2026-10-10)

The MAVLink unit carries the MAVLink receiver with the library's frame parser, and the
MAVLink_Entries unit carries the library's message table behind the same bisection. Each
serial byte goes through the parser's states in the library's order. A start byte of either
framing version opens a frame and resets the checksum. The version one header has no flag
bytes and a one-byte id, the version two header carries two flag bytes and a three-byte id,
and an incompatibility flag other than the signing bit drops the frame. The payload bytes
fold into the X.25 checksum as they arrive, and the message's CRC extra folds in last when
the table knows the id. An unknown id, or a checksum byte that disagrees, marks the frame bad
but the parser still reads it to the end. A signed frame waits for its thirteen signature
bytes and passes without a signing key, as the receiver holds none. A complete frame is
copied out of the parser, with the wire's checksum in place of the computed one when the
two disagree, and the copy's length follows the parser's length on every byte. A bad
checksum returns the parser to idle, or to the start state when the byte itself is a version
two start byte. A good RC channels override message takes its
eighteen channels as consecutive words from its first channel, so the ninth word is the two
target ids and the following words are each one channel early, and channel eighteen is never
read (finding F41). A word of zero or all ones leaves the channel as it was. The byte's time
is the frame time. A good radio status message keeps the transmitter's free buffer, scales
the remote RSSI from the negative dBm range onto the receiver's range, where a report below
the range minimum wraps (finding F42), and gives the receiver the dBm, the noise as the SNR,
and the local RSSI as the link quality. Every other good message goes into a queue of sixteen
for the telemetry task. The status poll is complete once after each override message. The
telemetry may send when the last radio status left more free buffer than the configured
minimum. The raw value is the channel as it is. The payload index is held below the payload
size and the signature count above zero by guards the recorded vectors never reach. The
signature bytes, the parse error count, and the parser's status copy are not kept, since
nothing reads them. The
serial port and the telemetry task stay with their layers.
## D53. The MSP serial port with its frame decoder and reply encoder (2026-10-11)

`Adaflight.MSP_Port` is the serial port of the configurator protocol. The decoder takes one byte
at a time through the three framings (version 1, version 2 carried in a version 1 frame, and
version 2 native) with the exclusive-or checksum of version 1 and the CRC-8 of version 2, and
rejects a header whose size passes the 192-byte receive buffer. Between frames a frame start
cancels a pending request, the reboot character and the hash mark set one, a start of text
enters the command line, and any other byte cancels a pending reboot. A pending request fires
once the port has been quiet for a hundred milliseconds. One call of `Process` is one scheduler
pass: it completes at most one frame and leaves the bytes after it for the next call. The caller
answers a command frame itself and hands the reply to `Encode`, which lays out the header for
the request's framing with the jumbo size past 254 payload bytes and closes the frame with its
checksums. The send rule (an empty transmit buffer, or room for the frame) and the five-second
configurator activity window are functions beside it. The caller supplies per call whether the
bytes between frames are read as requests, whether a device streams on the port, the reboot
character, and whether the command line kept the port, since the serial layer and the command
line own that state. Proof covers the receive buffer index through a predicate on the port
record: the position is zero before a header, at most the header size while a header fills, and
below the data size while a payload fills, with the data size held to the buffer by the header
checks, so no byte can land past the buffer. The encoder's frame buffer is sized for the longest
header, the largest reply, and both checksums. The reference writes the jumbo size of a
combined-framing reply after the version 2 header instead of after the version 1 header, and the
encoder keeps that order so the recorded vectors match (finding F43).
## D54. The ExpressLRS hopping tables and link counters (2026-10-11)

`Adaflight.ExpressLRS` holds the common part of the ExpressLRS link ahead of its receiver: the
air rate and performance tables of the 900 MHz and 2.4 GHz bands as constants, the eight
frequency domains with their first and last channel as register values and their channel count,
the hopping sequence, the 14-bit CRC of the over-the-air packet, the link quality counter, and
the conversions of switches, telemetry ratios, rates, power indices, and the air rate index of a
sync packet. The sequence generator fills whole blocks of the channel count with the sync
channel first (the channel count halved plus one, where the version 3 protocol places it), the
channel that would repeat the sync channel as channel zero, and the others in order, then swaps
every entry but the first of each block with an entry drawn by the seeded linear congruential
generator from the same block, in the draw order of a single pass. Proof covers the sequence
indices through the block structure (an entry and its swap partner stay within the block, and
the blocks within the 256 entries), the frequency arithmetic in modular 32-bit words as the
radio registers hold it, and the link quality window through a predicate on its record (the bit
position stays below four in the last word, so the window wraps where the hundred periods end
and the word index never passes the fourth word). The current index stays below the sequence
count by the record's predicate, and a regeneration reduces the index into the new count before
the count changes. The telemetry ratio value is a byte, so the standard marker reads zero and
the disarmed marker one, as the sync packet carries them. The CRC table entry is computed per
byte instead of held in a table of 256 words, the same function of the byte. The receiver's
packet handling, the connection states, and the telemetry link follow in their own units.
## D55. The ExpressLRS telemetry link (2026-10-11)

`Adaflight.ExpressLRS_Telemetry` carries a telemetry frame to the transmitter and assembles the
transmitter's MSP frames, five bytes per packet each way, with the stubborn confirm scheme of
the link. The sender keeps the frame under way (copied in, up to the 64 bytes of a CRSF frame),
the chunk position, the size of the last chunk handed out, the package number, the confirm bit
it awaits, and the count of wrong bits against a limit. A telemetry slot takes the next chunk
with its package number: the resync marker (63) while resyncing, zero for the last chunk of a
frame of more than one, else the package number. The transmitter's bit comes back in every
packet: the awaited value advances the frame, flips the awaited bit, and ends the frame or,
after a first package, waits for one more confirm so the transmitter can tell a new frame from a
resend. A wrong bit counts, and past the limit the sender resyncs. A frame set while another is
under way resyncs first. The limit is the packets between telemetry slots (the ratio times one
plus the burst, over the burst) times twenty missed packets, eighty at reset. The receiver takes
the transmitter's chunks by package number: the marker restarts the frame and flips its bit, the
expected package or a final package is taken and flips the bit, a first package in mid frame
restarts the frame, and a package after the last is ignored until the caller unlocks it. Proof
covers both buffers through predicates on the records: the position never passes the length, so
a chunk copied in or out stays within the frame. The sender's advance by the last chunk is held
at the length, which a frame replaced between the chunk and its confirm could pass; the protocol
never does, since the transmitter flips its bit only for a chunk it received. The CRSF frames
the sender carries, the device info reply, and the MSP frame handling behind the receiver come
with the CRSF telemetry port.
## D56. The flight log field encodings (2026-10-11)

`Adaflight.Blackbox_Encoding` writes the field encodings of the flight log into a stream over a
caller owned array: unsigned variable byte integers (seven bits per byte, low bits first, the
high bit set while more follow), signed values through the zigzag mapping, the 16-bit and 32-bit
words low byte first, the float as its bit pattern, and the packed groups. The group of three
takes a two-bit selector for 2, 4, or 6 bits per field, or 32-bit fields of 1 to 4 bytes each
behind a second selector of byte counts, the first field in the low bits; the variable group
uses the 5-5-4 and 8-7-7 bit splits instead and returns its selector. The group of four takes a
one-byte selector of field widths (none, 4, 8, or 16 bits) and packs the fields by nibbles, the
high nibble first, with a closing nibble when one is left open. The group of up to eight writes
one field bare and more behind a header byte that marks the fields that are not zero, the first
field in the low bit, then those fields as signed variable bytes. The bytes come from the two's
complement bits of each value, so a field wider than its selected width is cut to it. Every
encoder asks for the room its longest form needs (five bytes per variable byte integer, thirteen
for a group of three, ten for the group of four, one plus five per field for the group of eight)
and proof covers every write through the stream's contract, so no encoder can run past the
array. The header lines in text and the frame logic that chooses the encodings come with the log
itself.
## D57. The text conversions (2026-10-11)

`Adaflight.Text` holds the conversions the command line, the display, and the log headers need:
the digits of a number in a base from two to thirty-six with lower or upper case letters past
nine, a signed number in decimal or in a base with uppercase letters where a base outside the
range reads as ten, the fixed form of a float with three decimals behind a leading space or
minus sign and rounded half away from zero, a float read from its text, the character classes
and case folds over the basic letters alone, the comparison and the search that ignore case,
and the formatter. Every writer takes the caller's buffer and reports the length it used, and
each contract asks for the room of the longest form, so no writer can run past its buffer: the
fixed form accepts magnitudes to two million and asks for twelve characters, where the
reference's declared buffer of eleven overflows from a magnitude of one hundred thousand
(finding F45). The float reader keeps the operation order of the reference and adds three
rules: a mantissa or a divisor past 3.0E37 takes no further digit, the scale of an exponent
comes from a table of the thirty-nine values that the repeated products of 1.0E8 and 10.0
produce, and the product of mantissa and scale is formed in double precision and saturates at
Float'Last where the reference overflows to infinity, so every finite result matches and no
float operation can overflow. The formatter takes its arguments as a list of 32-bit values and
slices of a caller's text pool, fills the d, u, x, X, c, s, and %% conversions behind an
optional zero flag and width, treats the l modifier as nothing since every number is 32 bits,
stops at a template that ends inside a conversion, writes nothing for a conversion with no
argument left, and holds the output to the buffer's length. Its width parser takes a letter a
or A after a width digit as a digit of ten, the comparison of the reference kept so the vectors
match (finding F44). The search returns no match for an empty text, where the reference reads
past it (finding F46). Proof covers every buffer index and the float bounds of the reader. No
recorded vector reaches the saturation or the empty-text guard.
## D58. The DShot protocol (2026-10-11)

`Adaflight.DShot` holds the protocol pieces that need no output hardware. The frame puts
eleven value bits over the telemetry request bit and the checksum of the three nibbles
above it, inverted when the reply shares the signal line. The command conversions map the
1000 to 2000 range onto 48 to 2047 and back, each linear map as one factor and one offset
written as nine-digit literals of the single-precision constants a compiled reference
folds, so every product and sum rounds once as the compiled form does. The reverse map
rounds to the nearest command with a tie going to the even one, through a helper that
takes the exact fraction above the truncated value, because the hosted rounding attribute
is outside the proof tool's support and the maths unit's rounding has no postcondition
that ties its result to its argument, which the command range needs. The endpoints take
the idle setting in hundredths of a percent and the output limit as a fraction and write
the low and high outputs and the stop. The two deadband edges of the two direction mode
are written only in that mode.

The sampled reply decoder keeps the preamble skip, the smallest margin and the next check
time in a record the caller owns. It finds the first low sample, then reads the samples
one at a time within the count, closing a run at every level change that is not the last
position in reach. The reference's unrolled scan reads up to three samples past the count
when the preamble ends within sixty-nine samples of it. Those reads never change the
result, so the single reads are the same decoder without the over-read (finding F48). The
groups decode through the table of sixteen five-bit codes with the invalid marker, and the
nibble checksum gates the twelve bit value. The period decode shifts nine mantissa bits by
the three exponent bits and divides sixty million hundredths by the period, with the all
ones value as a stopped motor and a zero period as invalid, and proof bounds the result at
six hundred thousand.

The telemetry record carries the raw value, the last value per kind, the received set as a
byte and the highest temperature per motor, the processing state, the motor count, the
rate factor from the pole count, the forced extended decode, the rate filters, and the
rates. Update decodes every motor once per marked frame, keeps the kind's value as a
16-bit word, folds the rate, then runs the rate filters over the stored words and takes
their minimum. A rate above 65535 hundredths wraps in the stored word while the per-motor
rate uses the full value, as the reference does (finding F50). The sensor record gives the
period word as a signed 16-bit value. The pole count is one to 255, so the rate factor
stays below four. The reference accepts a zero pole count from the ground link and divides
by it (finding F49).

The quality record counts replies per hundred millisecond bucket over ten buckets with the
two running sums. The invalid share is the rounded ratio in hundredths of a percent. A
share at or above 9999.5 is returned as the whole without the rounding helper, which is
the value the rounding gives there, and this keeps the result in its range when the sums
disagree, a state no counting sequence produces. The output order check resets an order
that is not a permutation of its indices to the identity, and the postcondition bounds
every entry by the length. Proof covers the sample indices against the count, the shifts,
the margin narrowing to a byte, the bounded period, the rate bounds, and the order bounds.
Every recorded vector replays exactly.
## D59. The CRSF telemetry frames (2026-10-11)

`Adaflight.CRSF_Telemetry` writes every telemetry frame of the link from readings the caller
supplies, so the sensors, the battery meter, the attitude estimate and the flight state stay
with their units. A frame is the sync byte, the length, the type, the payload and the
checksum over type and payload. The position frame scales speed and course and holds the
altitude to zero to five thousand meters, the extended position frame derives the fix type
from the fix flag and the satellite count, the battery frame carries the drawn charge in three
bytes, the attitude frame reduces each decidegree angle into a half turn and scales it by the
single precision product of pi over 180 and a thousand, and the compass frame truncates three
times the field. The flight mode frame picks its name by priority and adds one character
while disarmed outside a failsafe. The device info frame takes its name from the caller.

The packed altitude of the barometer frame keeps the reference's wrap above 32767 meters
(finding F51), and the packed climb rate goes through the logarithm approximation and the
ties-to-even rounding of the maths unit. The inertial frame scales rates and accelerations to
sixteen bits through a clamp that proof needs and the values never reach.

The schedule has one slot per enabled kind, heartbeats fill it to five slots unless inertial
frames run, and the position and barometer frames are timed rather than slotted. The slots
keep stale entries past the count and the slot index survives a new schedule, so a shorter
schedule reads them until the index wraps, which the vectors cover. The speed negotiation
answers a proposal with the command frame and its second checksum, applies the rate after
four milliseconds and marks the third version running. The reference drains its one-frame
receiver buffer before every pass, so its check before the schedule is always true and the
port has no such gate. The MSP buffer and the display port chunks stay with their units.
Proof covers every frame against the room of the longest, the sixteen bit conversions, the
angle reduction, and the slot and baud table indices. Every recorded vector replays exactly.
## D60. The ESC telemetry over the serial line (2026-10-11)

`Adaflight.ESC_Sensor` polls each motor in turn for the ten byte telemetry frame: a boot
delay of five seconds, then a request for the motor in turn, then the reply decoded once
complete and checked with the eight bit checksum over its first nine bytes, or the reading
aged on a bad checksum or after a hundred milliseconds without a complete frame. The
request itself is the caller's, so the unit reports it and the motor it is for. The byte
receiver keeps bytes only while a frame is in flight. The readings hold the temperature,
voltage, current, consumption and electrical rate of each motor with the age of the
reading, and the combined reading takes the oldest age, the highest temperature, the
average voltage and rate, and the summed current and consumption, cached until a reading
changes. The reference counts timeouts and checksum errors only inside its debug mode
(finding F52), so the port carries no such counters. An outside source may replace a
motor's reading or age it. Current and consumption from such a source are bounded by a
predicate so the sums over every motor fit, which the serial frames' sixteen bit values
always do. The frame fill never passes the frame size by the same predicate. Every recorded
vector replays exactly.
## D61. The SmartPort telemetry stream (2026-10-11)

`Adaflight.SmartPort_Telemetry` answers the receiver's polls on the half-duplex line. The value
table is built once from the sensors enabled in the configuration and the sensors present: the
mode words, the core temperature, the battery and cell voltages, the current with the fuel and
the charge used, the heading, the attitude and the accelerations, the altitude and the climb
rate, and with the GPS feature the ground speed, the two coordinate words, the home distance and
the GPS altitude; the ESC table holds the voltage, current, rate and temperature ids that the
configuration leaves to the ESCs. Received bytes are reassembled through the start byte, the
sensor id and the escaped payload with its checksum, and a poll of this sensor's id as the last
byte waiting clears the stream to send; the bytes are read up to the first complete payload and
the count taken is returned, so the caller offers the rest again. Once cleared, the next value
goes out within the attempts the caller allows, which stand for the reference's time budget of
one millisecond: the table position moves on each attempt, every seventh value comes from the
ESC table over each motor and the combined reading in turn, and a value with nothing to report
(a GPS value without a fix, an ESC value without a reading, the mode word without a source)
passes its turn. The frame is the frame id, the value id, the value and the FrSky checksum,
each byte escaped when it is one of the two reserved bytes. The table positions count in a byte
as the reference does, and a read past the table gives no value (finding F75); the table holds
all twenty-one ids a configuration can enable (finding F76). The MSP tunnel over the stream waits
for the MSP serial port. Every recorded vector replays exactly.
## D62. RunCam device protocol (2026-10-11)

The RunCam device unit carries the reference's device protocol and camera control: the packet of
header, command, data and a checksum over all of them, and the five byte command of the older
cameras with its high-first checksum computed with the tail in the checksum's place; at the start
the device information request with the configured retries and interval, and after its last
failure the older command sent once; one request at a time waiting for its reply, the reply taken
from its header byte to the expected length, checked, parsed, and dropped on success, sent again
at the timeout while retries remain, else parsed as timed out; the camera's own requests parsed
from the bytes a waiting request leaves, the attitude request answered with roll, pitch and the
yaw in whole degrees as little-endian words; the three camera buttons once per switch activation,
the wifi and mode buttons held while armed or while arming is blocked by a runaway takeoff or a
crash; and the five key cable from the sticks: the connection opened with yaw high and closed with
yaw low at centred throttle, roll and pitch, the keys from roll and pitch while in the menu, the
set key from yaw high, the release when the three sticks return to centre, each with the beep the
connection result asks for. The bytes a call does not take are offered again, as the reference's
port keeps them, and a request flushes them all before it is sent, whether or not the one slot is
free. Three reference behaviours are kept: an unsupported request parks the parser in an invalid
state and the 200 ms reset returns it to the command state (finding F77); the older-protocol
request after a failed device information request never waits for its reply (finding F78); and a
reply failing its checksum leaves the request waiting with its count full, where the unit stops
storing at the buffer's end and the reference writes past it (finding F79). With the port closed
a call does nothing, as the task never runs then. The unit is SPARK for the reply and request
buffers, whose indexes the reference does not bound.
## D63. FrSky hub telemetry (2026-10-11)

The FrSky hub unit carries the reference's hub encoder: every 125 ms by the signed difference of
the microsecond clock, a cycle counted one to forty, and in it the frames of a header, an id and
a sixteen-bit value low byte first with its two bytes stuffed, then the tail. Every cycle sends
the three accelerations in thousandths of a g, truncated to whole g first, and the climb rate;
every fourth the altitude in metres and centimetres, zero for the first five seconds after boot,
and the heading in whole degrees with a zero fraction; every eighth the ESC temperature and rate
in tens of revolutions per minute, the cell voltage with its cell number in two-millivolt steps
and the pack voltage in tenths or in fifths, the current and the fuel as the percentage left or
the charge used, the ground speed in knots with a fix, the GPS altitude, the satellite count or
the dilution while it is poor on the first half of every sixteen cycles in the configured unit,
and the position in degrees and minutes with the hemisphere letters, the configured position
until the first fix and the last known one after it, or one degree each with a compass and no
GPS; every fortieth the minutes and the seconds of the uptime. Each value narrows to sixteen
bits as the reference's frame parameter does, and the configured no-fix coordinates are bounded
to eighteen thousand hundredths so their conversion stays within the reference's defined range.
The sensors present and the configuration are settings of the stream; the cell voltage's cell
counter and the fix memory are its state. The ESC branches of the temperature and the rate are
the ones the default build compiles. The unit is SPARK for the output buffer and the narrowing
arithmetic.
## D64. iBus telemetry sensors (2026-10-11)

The iBus telemetry unit carries the reference's sensor protocol and its port handler: the
receiver polls the half-duplex line with four byte requests of a length, a command with the
address in its low nibble and a two byte checksum, and the link answers from a table of fifteen
sensor ids, the first nonzero address polled becoming the base of the table, an address below
the base, past the table or at an empty entry getting no answer. The three commands answer the
discovery with the address, the type with the id and its length, and the measurement with the
value: two bytes for most sensors, four for the pressure, the positions and the altitudes, and
the parts in turn for the three combined sensors. The values follow the reference's conversions
and narrowing: the temperature in tenths offset by forty degrees from the barometer when present,
else from the gyro; the throttle, zero with the motors stopped, or the capacity as the rate; the
mode code with the last matching flag deciding; the accelerations in thousandths of a g; the
attitude in hundredths of a degree wrapping past the sixteen bits; the GPS values zero without
the sensor or a fix, the status always carrying the fix type and the satellites; the pressure
with the temperature in its high bits. The bytes received pass a four byte window, the echo of
each answer skipped by its length, and a request is seen when the window's length byte is two
to four and the checksum over that many bytes less two matches its last two bytes; the
reference sums past the window for other length bytes (finding F80), so those never match here.
Every byte offered is taken, and an answer that would not fit the output is dropped, which no
recorded vector reaches. The unit is SPARK for the window, the frame and the output indexes.
## D65. HoTT telemetry link (2026-10-11)

The HoTT unit carries the reference's binary mode: the receiver asks on the single wire with two
bytes, a request id and a sensor address, and the link answers the electric air module address
with its message and the GPS module address with its message when a GPS is present, a byte per
call with three milliseconds between bytes and the running sum after the last, the line turned
to send on the call after the request and back to receive, with every byte waiting flushed, on
the call after the sum. A request is seen when exactly two bytes wait on two checks four
milliseconds apart; more than two are flushed; the count is read as a byte, so a receive buffer
of exactly 256 bytes reads as empty and stays until more bytes arrive (finding F81). The two
messages are prepared
from the sensors five times a second, while one may be on its way out, so the bytes after a
preparation carry the new values: the voltage into the main and first battery fields, the alarm
and its inverse flag once per configured interval from the voltage or the charge state, the
current and the charge used in tenths, the altitude offset by five hundred metres, the climb rate
offset by thirty thousand and the three-second rate by one hundred and twenty; the satellites and
the fix character always, and with a fix the position in degrees and minutes with hundredths of a
second, the speed in kilometres per hour, the home distance, the altitude bounded to the field,
and the home direction in two-degree steps. Each field narrows as the reference's byte stores do.
The text mode waits for the menu system. The unit is SPARK for the message indexes and the send
position.
## D66. Ghost telemetry frames (2026-10-11)

The Ghost telemetry unit carries the reference's frame scheduler and encoders: a schedule of up to
four frame types built once from the configuration and the sensors present, the battery frame
when a voltage or current meter is configured and reported, the two GPS frames with the GPS
feature and their sensors reported, and the heading and altitude frame with a compass or a
barometer reported; then one frame per cycle of a tenth of a second divided by the schedule
length, in order, each frame the receiver address, the length, the type, ten payload bytes and
the checksum over the type and payload, handed to the receiver driver to send. The battery frame
carries the pack or cell voltage, the current and the charge used in tens, and the disarmed flag;
the first GPS frame the position and the altitude in metres, zero without a fix; the second the
speed, course, satellites, the home distance and direction in tens, and the fix flags; the last
the heading and the altitude in metres bounded to the field with their flags. Each value narrows
as the reference's writers do. The climb rate of the last frame stays zero and its flag clear,
as the reference tests a sensor bit no sensor sets (finding F82), and an empty schedule sends
nothing, where the reference divides by its length (finding F83). The unit is SPARK for the frame
and schedule indexes.
## D67. Race transponder codings (2026-10-11)

The transponder unit carries the reference's three infrared codings and its repeat schedule. Each
coding turns the configured code into the toggles a timer plays out on the carrier: ILAP sends
six bytes, each a pulsed start bit, its eight bits low first and a silent stop bit, eleven toggles
and a gap per bit, 720 toggles in all; Arcitimer sends nine bytes, each bit low first as four
toggles, in a buffer of 620 with silence after the 288 of the bits; ERLT sends the inverted code's
six low bits high first between two start bits and a parity bit, a one as twenty-five cycles and a
zero as ten, pulsed on the odd bits, with a silent cycle after the parity, so its length follows
the code. The pulse value of the ERLT coding passes through a byte, as the reference's helper
narrows it (finding F84). The schedule starts a transmission when the hardware is ready and the
signed difference to the next time is not negative, and sets the next time from the coding's delay
and a tenth of its jitter times the next step of a fixed table of fifteen; no coding means no
transmission. The timer period and the hardware are the target's. The unit is SPARK for the toggle
buffer indexes, which the reference drives through a static offset.
## D68. SRXL telemetry frames (2026-10-11)

The SRXL telemetry unit carries the reference's frame schedule and encoders for the Spektrum
receivers: three slots in turn, the link quality frame and the rate frame always, then one user
frame cycling over the flight pack current, the GPS status, the GPS location and the text generator
line, the text line taking the slot whatever the cycle while the menu is on this display; each
frame two address bytes, a length, sixteen payload bytes and the CRC-16 over the payload, handed
to the receiver driver when its buffer is empty, a slot whose frame has nothing to say passing in
silence. The rate frame carries the period between pulses from the ESC rate, or the DShot average
when the ESC gives none, bounded to the shown range, the pack or cell voltage and the core
temperature in Fahrenheit, big-endian; the flight pack frame goes when the current or the charge
changed or two seconds passed; the GPS frames go with the GPS feature, a fix and four satellites,
their values in binary coded decimals narrowed as the reference's conversions narrow them, the low
altitude field through a sixteen-bit integer before its digits (finding F85); the text frame sends
the next line not yet sent, or the next in turn when all were, and the menu system's characters
mark their line through `Put_Char`. The video transmitter frame follows the VTX control branch,
where the schedule grows by one user frame. The unit is SPARK for the frame and text indexes and
the narrowing arithmetic.
## D69. FrSky OSD device link (2026-10-11)

The FrSky OSD unit carries the reference's device link: the drawing, transform, context, grid and
font commands queued into a buffer of 192 bytes, the queue flushed when a command would not fit,
on a commit, on a request that waits and on the information request, each flush one frame of the
preamble, the length as a varint, the commands and the checksum over the length and commands; a
commit of a transaction with nothing drawn dropped with its beginning; the coordinates packed two
to three bytes of twelve bits each; the transform values as the bits of the floats. The bytes
received pass the frame states with the varint length, a complete response handled once per call
and the bytes after it dropped until then; the information response sets the version and the grid,
the first one clearing the screen and resetting the drawing; the font read fills the character
being read. The information request goes out once a second for the life of the link, as the field
meant to pace it after the device answered is never set (finding F86). The two font exchanges wait
for their reply in the reference; the unit takes the bytes waiting before the request, handling a
complete response among them and dropping a partial one, then the request goes out with whatever
was queued, then the bytes arriving during the wait are all taken, the first complete response
deciding the outcome, and the caller carries the time the wait took. The strings are bounded to
the payload the reference writes them into, which a longer string would overrun (finding F87). The
unit is SPARK for the queue, frame and payload indexes.
## D70. LED strip (2026-10-11)

The LED strip unit carries the reference's strip: the layout derived once from the configuration
(the LEDs in use up to the first empty one, the ring and scanner counts, the ring sequence length,
the grid halves for the indicator, the overlay timers nothing uses, the bar lengths); the status
profile, which paints every LED from its function (a palette color blended toward its neighbours by
the auxiliary channel, the mode color of its first direction, the arm state, the battery, signal,
GPS and altitude hues offset by the value, the bars) and then runs the overlay layers on their own
timers in the reference's order (rainbow, blink, scanner, ring, indicator, GPS, battery, signal,
warning), each layer repainting its LEDs every call and stepping its state when its time came, a
timer more than five seconds behind restarted; the race and beacon profiles painting the whole
strip one color, the race color flashing for the beeper switch or failsafe, the beacon on its
period, the strip repainted on a change or every second; and the driver update scaling each LED by
the brightness and converting it to red, green and blue, every LED after a change of count and the
LEDs in use otherwise. The configuration text of a LED and of a color parse as the reference reads
them, a chunk of more than ten characters failing and a color component over its limit or below
zero failing. Two reference behaviours are kept: a function mask also matches the functions whose
numbers hold its bits, so the battery, signal and GPS layers repaint the bar and ring LEDs too
(finding F88), and the ring timer's rate reaches zero for a throttle of 861 to 880 while armed,
where the reference divides by it and the unit adds nothing (finding F89). The video transmitter
layer and the race color that follows the transmitter frequency wait for the VTX branches, the
layer leaving its timer alone. The unit is SPARK for the LED, palette and timer indexes and the
hue arithmetic.
## D71. Rangefinder readings (2026-10-11)

The rangefinder unit carries the reference's processing of the distance a driver reports: the
reading's time and the interval between readings, a median of the last five readings in range
with the reading itself until five were seen, the pseudo signal ratio as the sum of the last five
squared changes over ten each bounded, the dynamic ceiling on the usable distance raised to three
quarters of the reading while the ratio stays quiet and frozen once the ratio crosses six hundred,
and the altitude from the reading and the cosine of the craft's tilt, out of range past the
sensor's extended cone. The surface altitude is usable with positive readings, a quiet ratio and,
once the ceiling froze, a reading under it; the sensor is healthy within half a second of a valid
reading. The detection, the drivers and the legacy bounds the altitude estimator reads come with
the target, the bounds computed here from the range and the tilt limit. The unit is SPARK for the
sample windows and the integer bounds.
## D72. Optical flow readings (2026-10-11)

The optical flow unit carries the reference's sensor processing without its drivers: each read
of the driver sets the quality, and a sample whose time stamp moved is turned into the craft
frame by the cosine and sine of the mounting rotation, with the x axis flipped when configured.
One filtered gyro reading is kept per sample in a ring of sixteen with its time stamp, and the
slot whose age is nearest the driver's gyro delay supplies the roll and pitch rates that are
subtracted from the flow after their conversion to radians per second. An axis whose matched
gyro rate exceeds two hundred degrees per second keeps its previous processed rate and loses
its validity, so a consumer can skip the axis instead of reading a zero as rest. A slot still
at time zero is passed over, as is a sample stamped zero, in the reference's order. The health
check compares the clock with the last sample through the wrapping difference. The cosine and
sine of the configured rotation come from the platform's trigonometry at init, because the
reference computes them once with the C library and the unit keeps no transcendental code. One
guard covers the reference's undefined behavior: the age error of a slot is computed in 64
bits where the reference subtracts the delay from a 32-bit age that can be near its minimum
after a long silence (finding F90). No recorded vector reaches the guard.
## D73. Pitot airspeed (2026-10-11)

The pitot unit carries the reference's airspeed task without its drivers: the platform reads
the I2C sensor and the latest DroneCAN frame each pass, and the unit picks the source in the
reference's order, the configured one alone or, for the default, the I2C sensor first and the
DroneCAN frame when it is less than half a second old. The pressure of the source that answered
goes through a first-order low-pass at five hertz over the twenty hertz task period; a source
that takes over resets the filter and, while disarmed and not yet zeroed, starts its
calibration, twenty filtered samples averaged into the source's zero, abandoned by arming. The
zero-corrected pressure gives the indicated airspeed as the square root of twice the pressure
over the sea-level air density, signed by the flow direction and in centimetres per second. A
pass without a sample keeps the last values for one second, then drops the source and zeroes
the pressure and the airspeed. Two bounds hold the proof without touching a value in range: the
accumulation of the calibration is held within twenty signal bounds, the most twenty samples
can sum to, and the root of the pressure is capped at one million before the multiplication to
centimetres, a bound no pressure within the signal bound reaches. The time comparisons use the
wrapping difference. No recorded vector reaches a guard.
## D74. Real-time clock calendar (2026-10-11)

The clock unit carries the reference's calendar without its time source: the platform supplies the
millisecond uptime, and the clock keeps the set time less that uptime, zero while nothing was
set. A date becomes milliseconds since 1970 through the reference's four-year leap cycle, the year
from 2000, a table of days to the start of each month, and the hours, minutes and seconds, in
32-bit unsigned arithmetic that wraps as the reference's does and lands in a signed second count;
the reverse conversion divides the seconds out and walks the table from the end. A time zone in
minutes moves a date through the time and back. The text of a date is the reference's ISO 8601
form with the zone, or the short form, each field padded with zeros to its width; a date outside
the valid ranges shows as the first of January of the year zero. A split finds the letter T that
separates the date from the time. The time with the zone applied is stored as two 32-bit words
across a reset and read back when either word is set. The conversions reproduce the reference's
wraps: a date past January 2038 lands before 1970 (finding F91), a negative zone under an hour
prints as positive (F93), and a set time equal to the uptime reads as no time (F95). Two guards
cover the reference's undefined behavior and its one buffer: the zone offset is applied only to a
month that indexes the day table, the default date showing otherwise (F92), and a stored time
outside the settable span of two to the sixty-second milliseconds is rejected on read. The
five-digit year the text can carry fits the 30-character result (F94). No recorded vector reaches
a guard.
## D75. Internal ADC channels (2026-10-11)

The internal ADC unit carries the reference's averaging and compensation without the conversions:
the platform reads the band gap reference and the temperature sensor and hands the two 12-bit
values to each pass, which runs each through a moving average of eight with the sum kept as the
sum of the window by a record predicate, computes the analog supply in millivolts as the chip's
calibration word times 3300 over the averaged reference, and the core temperature as the
averaged sensor reading scaled by the supply over 3300, less the calibration point at thirty
degrees, times the slope in thousandths of a degree, rounded to degrees and offset by thirty,
with the reference's narrowing to sixteen bits. The nine conversions of the reference's init are
nine passes driven by the platform. The calibration word, the point and the slope are bounded to
the values the chips carry, so the products stay in 32 bits where the reference would overflow
(finding F96). One guard covers the reference's division: an averaged reference reading of zero
gives a supply of zero, the quotient the target's core produces (F97). No recorded vector reaches
the guard.
## D76. Flight statistics (2026-10-11)

The flight statistics unit carries the reference's counters without the configuration store, the
beeper and the scheduler: an arm records the millisecond clock and the distance flown so far, and
a disarm, when the minimum armed time is not off, adds a flight, the armed seconds and the metres
flown since the arm to the totals and records the battery draw, once the armed time reaches the
minimum, then asks for the save after half a second while a save is owed. The save, when the
platform runs it, does nothing while armed; while disarmed it writes the configuration and repeats
the disarm beep when the craft lies still under the movement limit, or when the limit is zero,
asks for another pass otherwise, and in either case clears the owed save; a configuration change
waiting for its own save leaves the statistics to it. The seconds and the metres wrap as the
reference's unsigned arithmetic, and a negative battery draw lands in the unsigned total as the
reference stores it. No guard was needed.
## D77. Wing launch (2026-10-12)

The wing launch unit carries the reference's launch state machine without its sensors, receiver
and modes, which the platform hands to each pass as inputs. An arm latches the launch when the
switch is on, the airframe is a fixed wing with an accelerometer and it lies at rest: specific
force within 0.15 g of one g, every gyro rate under 25 degrees per second, a vertical speed under
a metre per second when an altitude exists, and a ground speed under half a metre per second when
the fix has five satellites. The pass then walks the reference's states in its order: the throttle
wait, which restarts its clock while the throttle is low and leaves after the idle delay; the idle
ramp of a second and a half for the throttle and the climb angle; the detection wait, which holds
the idle throttle and the climb angle and needs a bungee pull, a swing or a run to hold for the
detection time, a frame without one seeding the clock again; the motor delay; the spin-up ramp
from the idle to the launch throttle; the climb-out until the altitude, the timeout or the sticks;
and the finish, a cross-fade of the handover factor to the pilot that any stick input ends early.
A bungee pull is the forward specific force past the threshold while level within the tilt gate;
a swing is the tangential speed about the thrower's shoulder, the sideways force times gravity
over the yaw rate in radians, past the velocity threshold with a forward force; a run is the
ground speed past the same threshold with a forward force and a fix of five satellites. From the
motor delay on, a bank past the abort angle either way or a dive past it, held for a tenth of a
second, aborts; the sticks abort past the deadband once the minimum time from detection has run;
the mode going off or the failsafe aborts at once, as does the switch. Every exit hands the
aircraft straight back with a handover of one. While the launch owns the aircraft the pass writes
the angle targets the level controller reads, zero roll and the climb angle as a nose-down pitch;
the targets live with the caller and keep their values otherwise, as the reference's globals do.
The times compare through the wrapping difference. No guard was needed.
## D78. Navigation trail (2026-10-12)

The navigation trail unit carries the reference's breadcrumb recorder for the OSD map without
its GPS: the platform hands each poll the position east and north of home in centimetres, which
the reference computes from the home and current coordinates. The poll runs at ten hertz on the
wrapping clock, starts the line over on the arm edge before the cycle's position can land, and
takes a position only while armed with a fix and a home. A position becomes whole metres east
and north, rounded to the nearest and held in sixteen bits before the distance gate, so a glitch
past the range leaves the stored point and the gate's arithmetic agreeing; the first point is
stored, a later one when its distance from the last reaches the spacing, compared as squares in
64 bits. A full store of 240 points keeps every second point and doubles the spacing, up to five
kilometres, before the point goes in. The stored points live in the record and the harness
checks their count, the spacing, the last point and a hash over every point. No guard was
needed.
## D79. The GPS frame decoders (2026-10-11)

`Adaflight.GPS_Frames` decodes the two serial protocols of a GPS module into one solution
record: the position, altitude, dilution, accuracy, velocity, speeds, satellite count, time of
week and calendar time, with the fix flags, the satellite list, and the request to set the
clock while it has no time. The NMEA decoder gathers a sentence field by field into a fifteen
character buffer, identifies GGA, RMC, GSV and GSA sentences from the three letters after the
talker id, parses each field as it ends, and writes the gathered values to the solution once
the parity after the star matches. The fix state follows the GGA quality field as the field
arrives, before the parity check (finding F53). The UBX decoder walks the preamble, class,
id, length, payload and the two Fletcher checksums, keeps up to 392 payload bytes, restarts
on a declared length past 776 or on a bad checksum, and interprets a complete message by
class and id: NAV-PVT, NAV-POSLLH, NAV-STATUS, NAV-DOP, NAV-SOL, NAV-VELNED, NAV-SAT,
NAV-SVINFO, MON-VER and the acknowledgements. A message is read from the payload buffer at
its field offsets whatever length arrived, so a short message takes the stale bytes of
earlier ones from the shared buffer, the same bytes Betaflight reads. The configuration reply that
makes the module transmit (CFG-GNSS) belongs with the autoconfiguration and is passed over.
The narrowing conversions are kept: the speed in knots times 5144 over 1000 in thirty-two
bits, the millisecond field of the clock request computed from the time with a bitwise and
(finding F54), and the saturating hexadecimal read of the hardware version. The port departs
from Betaflight only where its behaviour is undefined: the field cut that would land outside
the buffer is dropped (F55), a satellite number of zero skips the list (F56), and a month
outside the calendar counts thirty-one days (F57). The oracle feeds bursts of sentences and
messages with cut frames, bad checksums, stale buffers and runs of garbage, built with
unsigned characters as the targets are, and every recorded vector replays exactly.

## D80. The GPS link (2026-10-11)

`Adaflight.UBX_Config` builds the configuration messages for a u-blox module: the frame around
a class, an id and a payload with the two running checksum bytes, the polls, the message rates,
the navigation rate, the dynamic model with the fixed defaults of the other navigation settings,
the autonomous assistance, the full power mode, the SBAS selection with the scan mask of the
selected system and the NMEA output disable, each in the legacy form and, from the ninth
generation, the keyed value form, and the GNSS configuration sent back from the module's own
reply with SBAS and Galileo set as selected. A frame carries the id its acknowledgement names
and whether the sender counts it acknowledged at once: the legacy navigation rate and every
keyed message but the navigation rate are. The GNSS message holds at most seven blocks
(finding F61).

`Adaflight.GPS_Link` runs the connection over a serial port the caller owns. The caller hands
over the bytes received since the last call and carries out what the call asks for: the bytes
to send, the port rate to set, the indicator toggle, the ready beep, the clock to set and the
task rate, fast while bytes arrive and normal one call after the last. The detection polls
the version three times, 330 ms apart, at each rate of a sweep that starts at the configured
rate, moves through the faster rates and wraps to 9600 upward; after two passes a step waits
30 s. A version reply sends the module's own rate change sentence, the port follows a second
later, and the configuration starts after another second: one step every 110 ms while no
acknowledgement is awaited, each step moving on at the acknowledgement or 150 ms after the
message, a negative acknowledgement of the first step restarting the configuration. The
steps slow the navigation rate, turn the six NMEA sentences off, set the acquisition model,
the assistance, the SBAS selection and the power mode where the generation has them, pick the
solution messages of the generation (PVT from the seventh, the five legacy messages below),
ask for the satellite information at a fifth of the rate, set the configured rate and poll
the GNSS configuration when SBAS is off or Galileo is on; the reply is answered as it is
received. Receiving, a fix switches the module to the flight model once, and 2.5 s without a
solution counts a timeout, drops the fix and the satellite count and restarts the detection.
An NMEA module keeps its own rate: the port is set to the configured rate and one custom
command goes out, half a second apart; the next command waits for the next connection
(finding F63). The ground link source takes offered solutions and starts initialized; after
a loss it stays in the detection state (finding F62). Every solution with a fix counts the
stamp, sets the interval and the frequency of the solutions, the distance and the direction
home and, armed, the distance flown above 15 cm/s. The home position is set on request from
a fix with at least the minimum satellites, unless it is kept once set; the request also
turns the satellite information off on a u-blox module. Disarmed, the home fix clears each
call unless kept, and the ready beep sounds once at a fix with enough satellites. The link's
clock starts at zero, so the first version poll is counted against zero (finding F64). The
distance over the local flat earth and the bearing use the maths approximations and the
wrapped coordinate difference (finding F58); the ENU distance vector stays with the position
estimate. The task time budget that stops the byte loop belongs to the caller, which decides
how many bytes a call takes. Every recorded vector replays exactly.
## D81. The horizontal position estimate from the GPS (2026-10-11)

`Adaflight.Position_Estimator` takes over the altitude estimator of D33 and adds the east
and north filters of the earth frame. The horizontal axes run while armed and asked for, by
the position hold or rescue mode or by a GPS fix under a horizontal source setting that
allows the GPS; starting them resets the two filters and takes the origin from the fix at
hand, or from the first fix after. The linear acceleration comes from the north, west and up
rows of the attitude rotation over the scaled counts, east being the negated west row, and
corrects and predicts the horizontal filters while a measurement is less than two seconds
old, else discards their state and keeps the origin. A fix is fused when its solution count
has advanced or within the hold interval its rate gives, the velocity before the position,
each with a noise scaled by the reported accuracy between one and ten times its base. The
east and north distances from the origin follow the longitude difference, wrapped in
thirty-two bits (finding F58) and corrected across the antimeridian, scaled by the cosine of
the home latitude and by the centimetres per unit, that constant rounded at each step as the
C forms it. Under an altitude source that allows the GPS, the fix also corrects the vertical
filter, velocity then position against the first GPS altitude, and the barometer then
corrects position alone, since the GPS measures the vertical velocity; below the default
barometer preference the fix anchors a slow calibration of the barometer offset toward the
offset the estimate implies, at a time constant of two hundred seconds times the accuracy
scale, while armed and both fed in the task. The validity of each plane needs a measurement
within two seconds, the trust falls with the mean position variance, and each task raises
the update events the altitude and position hold tasks take once. A heading is required
while the GPS is the horizontal source. The altitude hold now takes its centimetre type from
the position filter. Distances and altitudes beyond the filter's state bound of 167 km are
held at it; the oracle keeps the fixes within range and short of the antimeridian. Every
recorded vector replays exactly, the earlier altitude vectors unchanged.
## D82. Position hold with the autopilot's horizontal control (2026-10-11)

`Adaflight.Position_Control` is the autopilot's horizontal controller and
`Adaflight.Position_Hold` the mode around it. The hold engages from its flight mode or a
rescue: the controller resets, captures the hold point, enters braking against the speed
carried in, and asks the estimator for the horizontal axes; it releases with the sticks
cleared and the yaw controller stood down. Each task reads the sticks against the deadband,
unless a failsafe or a rescue holds them, and checks the sensors for a valid horizontal
estimate and, where the estimator requires one, a heading, with a heading recovery standing
in; sensors returning after a dropout re-anchor the hold where the craft is. The controller
measures its interval between a quarter and four times the nominal and retunes the
feedforward filters when it moves by a twentieth. A missing estimate, an abort or a forced
level park fail the hold with the errors dropped; a heading recovery levels the roll and
pitches forward instead. The ground speed and its half-second trend feed the braking stop
and the fence. The mode follows the rescue, the sticks and the braking. A rescue flies the
velocity the rescue sets, the target walking at it with the fence on the target and the
integral accumulating. The sticks fly their velocity,
turned from the body frame by the heading, with the distance error integrated from the
velocity error while the integral freezes. Braking drags the target to the craft with the
integral frozen until the speed falls under the configured fraction of the entry speed, the
velocity reverses along the entry direction, or 1.2 seconds pass, then captures the point.
The settled hold anchors to the point and integrates against the wind, with the target
velocity zero outside a rescue. The fence is the greater of twenty metres and twice the
ground speed: a settled hold beyond it keeps the previous lean until a second has passed,
then spends the one re-anchor a clean ten seconds earns back, or levels out and fails; a
brake beyond it moves the fence ahead of a craft still slowing and runs the same clock
otherwise. The law per axis takes the error and its integral, each within twenty metres,
the proportional and integral terms, damping on the velocity with a boost of a half per
thousand centimetres a second less the drag, the acceleration term, and the feedforward
from the target velocity through the same boosted gain and from its rate of change through
its own, smoothed by a third order filter; the sum turns into the body frame by the heading
and is held to the lean limit, and a saturated lean stops the virtual error from winding
up. The yaw controller steers to the rescue's heading or holds the heading captured at
engagement or where the pilot last left the yaw stick, ramped in over a second, held to the
configured and any external rate limit, and reversed with the yaw setting; it stands down
while disarmed, without a mode that wants it, or without a trusted heading, and the heading
hold task drives it alone outside a hold or a rescue. The navigation modes, their yaw
modes and the velocity buildup clamp come with the navigation port; there is no optical
flow. A feedforward term beyond the signal bound and a target velocity beyond 2 to the 26
centimetres per second are held at those bounds. Every recorded vector replays exactly.

## D83. The GPS rescue over the autopilot's controllers (2026-10-11)

`Adaflight.GPS_Rescue` is the rescue of the default target build, where the flight plan is off
and the rescue flies its own phases. Each task reads the sensors (the fix count, the heading
and its validity, the GPS health, the altitude, the estimate while valid, the distance and
speed from home, the bearing home from the C library's arctangent past the twenty centimetre
acceptance radius, and the heading error), decides availability, runs the sanity checks, then
the phase. The initialization fixes the return altitude from the mode, or a climb above the
current altitude close to home, holds the heading and resets the ramps and the altitude
controller. The climb runs at the ascend or descend rate until the return altitude is crossed,
then the turn toward home with the yaw target ramped in over a second, or a forward pitch while
the heading is unknown, until the error is within thirty degrees; the flight home at the
ground speed, slowed within twice the descent distance and ramped in at the start, hands the
horizontal controller a velocity toward home and the yaw target; the descent sets a rate from
three times the setting at fifty metres to six tenths at ten, then the landing holds the
velocity at zero and the emergency descent aborts the horizontal control. The sanity checks
disarm on a start within the acceptance radius below the landing altitude or on a crash flip,
answer a failure by the setting with an emergency descent when an altitude is available, and
once a second record the GPS health, the satellite count over fifteen seconds, and the phase's
own progress: the altitude change against the target change, the velocity home against a fifth
of the target speed, and the seconds spent turning, pitching forward, descending or landing.
The do-nothing phase is kept though the sanity check disarms first under its condition
(finding F59). Headings in decidegrees reach the rescue through an integer division, so the
rescue works in whole degrees (finding F60). The autopilot's altitude controller moves from
the altitude hold into `Adaflight.Altitude_Control`, which the hold and the rescue drive with
their own targets; the caller owns the controller state and the horizontal controller state,
as the autopilot shares them, and passes both in. A target altitude change below a
sixteen-millionth of a centimetre counts as none for the progress ratio, which the reference
divides by. Every recorded vector replays exactly, the earlier altitude hold vectors unchanged.
## D84. The video transmitter table and the SmartAudio driver (2026-10-11)

`Adaflight.VTX_Table` holds up to eight bands of eight channels with their frequencies, names
and letters, the factory band flags, and up to eight power levels with their values and
labels, cleared to numbered defaults. It answers the lookups: the frequency of a band and
channel, the band and channel of a frequency searched from the last band down so a frequency
in two bands names the later one, and the value of a power index.

`Adaflight.SmartAudio` drives a SmartAudio transmitter over one half-duplex serial line the
caller owns: the caller hands in the bytes received and carries out the bytes and the line
rate a call asks for. A request builds its frame (the two preamble bytes, the command code,
the length, the payload and the checksum over the whole frame) into the buffer of its kind and
queues the kind, five deep; a later request of the same kind replaces the bytes before they go
out (finding F65). A call sends one frame: the outstanding command again 120 ms after its
last transmission, else the next queued frame, else a settings poll while a command went out
within the last second and 150 ms have passed since the last transmission. A disabled control
drops the frame and clears the outstanding command. Received bytes are reassembled through
the preamble, the code, a length up to nineteen, the payload and the checksum over the code,
the length and the payload; the echo of a command fails that check and is passed over by its
odd code. A response clears the outstanding command by its code, or by a settings code of a
later version, and counts an out-of-order reply otherwise. The settings response gives the
version from its code, the channel, the mode, the frequency, the boot flag while in pit mode,
the power as the table index of the reported value, and the dBm levels of a 2.1 device. The
line rate moves one step of 50 between 4800 and 4950 when fewer than seven frames in ten are
answered. The start polls the settings, then asks a version 2 device for its pit mode
frequency. Band and channel are set through the table as the device numbers them, the power
by the table value with the dBm flag on a 2.1 device, the pit mode by the mode flags or, on a
2.1 device not booting into pit mode, by a zero dBm power or a clearing mode, and the
frequency within 5000 to 5999 MHz, through a neighbouring frequency when the device already
holds it in channel mode. The getters give band and channel from the device's channel number
split by the table's channel count (a zero count divides as the hardware does, finding F66),
the power index, the frequency from the table in channel mode, the pit mode status, the power
levels in dBm and in milliwatts through the C library's power function, and the status bytes
for the ground link. The table value sent as the power is its low byte (finding F67). The menu
hooks and the debug print of the reference are not ported. Every recorded vector replays
exactly.

## D85. The video transmitter settings update and control (2026-10-11)

`Adaflight.VTX` keeps the configured band, channel, power, frequency, pit mode frequency and
low power disarm policy as settings the caller holds, since the sticks, the switches and the
receiver change them at run time. The start makes the settings whole: the frequency of a
configured band and channel, and a pit mode frequency raised to the user range, each asking
for the settings to be stored. Each task call outside the menu brings one parameter to the
device, moving through the power, the band and channel (or the frequency when no band is
configured), the pit mode and a confirmation of the device state, and stopping at the first
parameter that needed a change; the device is then driven while disarmed or while a change is
pending. The settings in force put the pit mode frequency and the default power in place at
the pit mode switch, and the default power while disarmed outside failsafe under the low
power policy. The pit mode follows the switch's edges while disarmed and the device reports
its status, except when a pit mode frequency is configured. The common layer over the one
device selects a band and channel through the table, sends the device the band and channel of
a factory band or the frequency of another, and reads band and channel back from the device
or, while a non-factory band is selected, from the device's frequency through the table; the
outputs keep their values when the device has none. A control word from the Spektrum
receiver, once per change, sets band and channel through the table, the power through the
device's steps and the pit mode at once, and stores the settings when they moved. The stick
commands step the band or channel bytes without bounds (finding F69) and lock from the first
arm on; the switch conditions apply in order, the later one winning a field, band and channel
only until the first arm, the power always; the cycle commands step from the device's band,
channel and power and wrap within the table, the power below the level count (finding F71). A
Spektrum band past the five known ones is not a table band (finding F70). Every recorded
vector replays exactly.

## D86. The Tramp driver and the device dispatch (2026-10-11)

`Adaflight.Tramp` drives a Tramp transmitter over one half-duplex serial line the caller owns,
in sixteen-byte frames: a start byte, a command, twelve payload bytes, a checksum over the
command and the payload, and a zero. The driver queries the device's limits every 200 ms until
it answers, then its settings, then watches the frequency, the power and the pit mode against
the configuration: one change goes out per 200 ms while retries remain, twenty from each
configuration change, the frequency and the power held back under the device's race lock; a
settings query follows each change, every second otherwise, and a temperature query follows
each settings reply. The received bytes are read up to the first complete and valid reply and
the count taken is returned, so the caller offers the rest again. A reply whose first word is
zero is the echo of a request and is passed over, so a device reporting zero limits never comes
online (finding F73). After a temperature reply the driver stays in the temperature state until
the request period passes (finding F74). The frequency is accepted within the device's limits,
or the user range while they are unknown; the power index is looked up in the table from the
configured power, unknown for a value outside it; the status carries the configured pit mode and
the race lock. `Adaflight.VTX` now drives either device: the device of the kind in use takes the
frequency, the power, the pit mode and the queries, a factory band goes to a SmartAudio device
as band and channel and to a Tramp device not at all, and the Spektrum power steps map to each
device's indices. The protocol library beside the Tramp driver is not ported (finding F72).
Every recorded vector replays exactly, the control vectors now over both devices.
## D87. The LTM telemetry stream (2026-10-11)

`Adaflight.LTM_Telemetry` writes the light telemetry stream: every 100 ms while enabled, an
attitude frame with the pitch, roll and yaw in whole degrees, then on alternate cycles a status
frame (the battery in millivolts, the charge drawn held to sixteen bits, the signal scaled from
its 1023 range to a byte, no airspeed, and the mode code with the armed and failsafe bits) or a
GPS frame (the position, the ground speed in metres per second, the altitude and the satellite
count with the fix type, left out while no GPS is present), and on every tenth cycle an origin
frame with the home position, no home altitude, the display flag and the home fix. Each frame
is the two start bytes, the frame letter, the little-endian fields and the exclusive-or of the
fields. The mode code follows the precedence of the flags: passthrough, headfree, angle,
horizon, rescue, position hold, altitude hold, then rate. The port handling that enables the
stream belongs to the caller, which passes the enable. Every recorded vector replays exactly.

## D88. The GPS lap timer (2026-10-12)

The GPS lap timer unit carries the reference's gate timer over the fixes the platform hands
it: the position, the fix time in milliseconds, the cosine of the latitude the GPS link keeps
for the local flat earth, and the reset switch's state. Every fix first takes the distance and
bearing to the gate through the GPS link's flat-earth arithmetic (D80), the bearing through
the fast arctangent in hundredths of a degree. While the gate is being set the fix joins a
running average of up to a thousand readings whose sums live in the timer in 64 bits, bounded
by the readings counted so the averages fit the gate; the count moves before the sums so the
bound holds at every step, which the reference's order leaves unobservable, and the quotient
is held at the coordinate bound it never reaches. Ending the set writes the averaged gate into
the settings. The reset switch clears the gate from the settings and every lap figure but
keeps the circle tracking, as the reference's file statics do. A lap is looked for while the
timer is stopped or the shortest lap has passed since the last one: inside the gate's circle
the closest approach and its time are tracked, and leaving the circle records a lap from that
time, moves the three previous laps along, keeps the best lap and the best sum of three in a
row, and restarts the timer from the closest approach. The lap count and the sums wrap in
sixteen and thirty-two bits as the reference's do. The harness replays 20000 steps over ten
courses that loop through the gate, hover at it while it is set, pulse the reset, cap the
readings and wrap the millisecond clock, and checks every figure, the file-level state and the
settings' gate.

## D89. The MSP box table (2026-10-12)

The MSP box unit carries the reference's box table and its MSP services. The table names each
flight and switch mode box and gives it the permanent id that identifies it to the configurator
for life, with lookups by box and by permanent id. The box name serializer writes a user box's
custom name of up to sixteen characters when its first character is set and the table's name
otherwise, each with the semicolon separator, or nothing when they would not fit; the permanent
id serializer writes the one byte or nothing. The box reply walks the active boxes in their
order and serializes the thirty-two of the requested page, stopping at the first that does not
fit. A box's state is the arming flag for the arm box, the flight mode flag for the flight mode
boxes, the launch flight mode for the launch box on a wing build, and the switch state
otherwise. The status packing sets one bit per active box in the order they are counted, in two
32-bit words as the reference's bit array, and returns the count. The active set from the
build's features, sensors and settings stays with the target, which hands it in as a mask. The
harness replays 20000 steps of random active sets, flags, switches, user names, pages and buffer
sizes, half from a host build and half from a wing build, and checks the packed words and count,
every serialized byte of both replies and the lookup by permanent id. No guard was needed.

## D90. The dispatch queue (2026-10-12)

The dispatch unit carries the reference's delayed-call queue over target numbers up to a
capacity of eight, with the handlers left to the caller: the reference links entries that
carry a function pointer, and SPARK keeps the entry table and the order while the caller
numbers its targets and runs each one the queue hands back. An added target takes its due time from the clock plus the delay,
which wraps as the reference's unsigned sum does for a negative delay, and goes before the
first entry not due earlier on the wrapping clock difference; a target already queued stays
where it is. A processing pass takes the head while it is due, unlinks it first and hands it
back, so the handler can queue it again as the reference's can; the caller loops until nothing
is due. The queue keeps its entries in an array by position rather than through pointers, with
one slot per target; the one guard refuses an addition at full capacity, which one entry per
target never reaches. Adaflight.Dispatch_Targets numbers the three calls the reference
queues: the statistics save, the MSP reboot, and the settings write and read. The harness
replays 20000 operations over the eight targets of adds with
positive and negative delays, clock advances that wrap, enabling, and processing passes whose
handlers requeue themselves at random, checking the fired order with every requeue, the
queue's order, and each entry's due time and flag.

## D91. The ExpressLRS receiver (2026-10-12)

The ExpressLRS receiver unit contains the reference's SPI receiver over the hopping tables
and link quality counter (D54) and the telemetry link (D55). A packet from the radio is
checked against its 14-bit CRC seeded from the unique id, with the CRC's upper bits cleared
from its first byte in place as the reference clears them before the check, so the payload
copy contains the cleared byte. It is then decoded by type: a channel packet is copied to
the payload for the channel decode, a sync packet contains the rate, the switch mode, the
telemetry ratio and the model match that drive the connection, an MSP packet with the bind
command writes the unique id while binding, and any other MSP packet feeds the MSP receiver
on a connection, whose finished frame sets the model id or is handed to the target. The
telemetry slot builds the response from the link statistics or from the sender's next
chunk, counting the burst the rate and telemetry ratio allow, and the next frame the target
offers starts in the sender when it is idle. The timer's tick advances the nonce and the
link quality window after the phase lock update, the tock records its time for the lock,
and each programs the next half-period with the lock's frequency offset and phase shift.
The receiver task runs the delayed start, a pending initialization, a bind request, the
connection states with the rate cycling while disconnected, the configuration write-back
and the link statistics reports. The radio, the timer hardware, the bind button and the
LEDs stay with the target, which reads the radio configuration, the timer period, the
start, power and save requests and the reports the unit records.

The receiver record keeps the reference's receiver structure and its file-level state side
by side under one predicate that holds every rate within its band's table, so the 900 MHz
bands' four rates and the 2.4 GHz band's six are never mixed. Initialization takes the
time, which the reference reads from the clock for the rate cycle. The telemetry frame
comes in through the telemetry slot's parameters where the reference calls out for it, and
the sender keeps its own copy, as the reference's static frame buffer is rewritten only
while the sender is idle. The signal to noise mean holds its sample count at 2 ** 24 - 1
(D6). The burst limit keeps the reference's 8-bit wrap at 1000 Hz with a 1:2 telemetry
ratio (findings F99).

The harness replays ten sequences of 2000 operations recorded from the reference compiled
with its driver and telemetry sources: the transmitter's packets at the rate's cadence
(sync packets with rate, switch mode and telemetry ratio changes, channel packets in the
wide and hybrid switch modes, bind packets, MSP chunks with model id commands, and
corrupted, lost and off-rate packets), timer overflows at the programmed period, task
passes with the system ready flag and bind requests, and channel decodes of fresh
payloads, over both bands, a bound or unbound unique id and every telemetry ratio,
checking the decoded payload and channels, the telemetry response, the hop and status
results and ninety-two state fields after every operation.

## D92. The flight log header (2026-10-12)

The flight log header unit contains the reference's log header: the field definition tables of
the main, GPS, GPS home and slow frames with each field's name, index, sign, predictors,
encodings and condition, the condition cache built once at the log start, and the chunked
writers that send the fixed header text, the field definition lines and the system information
lines under the device's byte budget. The budget is replenished each iteration from the
device's free space, grown by the per-iteration allowance and held at the accumulated limit,
and a reservation the budget cannot cover fails for the iteration, permanently when the
device's buffer could never hold the bytes. The writer appends to a caller owned array, lowers
the device's free space by one per byte, and drops a byte a serial port with no room cannot
take. A wing's main table has the three stabilization terms after the feedforward terms and
its sysinfo lists the stabilization settings in place of the autopilot and rescue settings, so
one unit serves both crafts through a flag.

The device, the settings and the clock stay with the target: it reports the device kind, the
per-iteration allowance, the buffer size and the free space, fills the sysinfo's values and
texts (the firmware identity, the board, the craft name and the debug mode name are texts the
target provides, and the motor outputs and receiver rate arrive already rounded), and reads
the writer's budget and counts. The P ratio line divides the intervals in the reference's
16-bit width.

The harness replays ten header transmissions recorded from the reference's recorder and
device layer over serial, flash and SD card stubs, seven multirotor and three wing: the fixed
text, the field definition lines of each table, and the sysinfo lines, each step with a
scripted free space, a replenished budget and a clock advance, checking every byte written,
the budget, the header index, the field cursor and the completion flag after each of the
13505 steps.

## D93. The flight log recorder (2026-10-12)

The flight log recorder unit contains the reference's recorder over the header unit (D92)
and the field encodings (D56): the log states from disabled and stopped through the log
file, the header, the field definitions, the sysinfo and the cache flush to running, paused
and shutting down, with the erase states beside them; the intra frame with every field its
condition admits, the delta frame against the previous frame or the average of the two
before it, with the compact encodings of the term, command and optional field groups; the
slow frame on change or at its interval; the GPS and GPS home frames; the events, with the
arming beep and flight mode changes logged as they happen; and the iteration policy that
places the frames by the intra and delta intervals derived from the loop time and the sample
rate. The motor test and always-on modes start and stop the log around the motors running
while disarmed, and a full device stops it.

The device, the sensors, the settings and the clock stay with the target. Each update
brings the device's answers (its free space, whether it opened with its buffer size,
whether the log file is ready and closed, whether its buffers are flushed, whether it is
full or erased, and whether a serial port is shared), the state to log as the reference
reads it (the controller terms, rates, commands and setpoints as values, the quaternion,
the motors, servos, battery, altitude and GPS solution, and the date and time already
converted to seconds), and the sysinfo settings; the recorder rounds the values as the
reference rounds them, keeps the three-deep history, and appends the bytes to a caller
owned array through the header unit's writer, so a full serial port drops them as the
reference's port does. The counts of the flushes, forced flushes, erases, beeps, opens and
closes the target carries out stand in for the device calls. The first motor's intra frame
field saturates at zero where the motor output is below the output low, which the reference
leaves undefined (findings F101).

The harness replays ten logs of 2500 iterations recorded from the reference's recorder and
device layer over serial, flash, SD card and no device, eight multirotor and two wing, with
the flight state on random walks, the device's answers, the boxes, the arming and the clock
scripted, disarms finishing the log and events and reinitializations between the updates,
checking every byte written, the log state, the iteration counters and intervals, the header
transmission, the budget, the histories and the request counts after each of the 22800
steps.

## D94. The position navigation target (2026-10-12)

The position navigation unit contains the reference's navigation target: a leg's target east,
north and up in metres with its cruise speed, arrival radius and completion speed; the
horizontal velocity toward it under the position gain, braked onto the target at the
approach deceleration and held within the acceleration limits, or the velocity the owner
states for a leg it profiles itself; the vertical ramp that walks the commanded altitude at
the leg's rate, braked into the leg altitude, slewed out of the rate of a leg it takes over
from and leashed to the craft; and the arrival test on the radius and the altitude window
with their hysteresis, the completion speed and the settle timeout. A new leg takes over the
velocity commanded so far, a moved target flies on without disturbing the ramp or the
arrival state, and the sequence survives a reset so a consumer still sees the next leg as a
change.

The owner that issues the legs stays with the target. The reference calls the leg's
callback inside its update, and a callback that issues the next leg keeps the velocity
flowing where a silent one has it cleared; the port's update reports the leg reached, and
the owner either sets the next leg or finishes the reached one, which clears the horizontal
velocity and the leg when it clears itself. The port's bounds are the estimator's position
bound, a kilometre per second of stated speed and the saturations declared in D6.

The harness replays six sequences of 2500 operations recorded from the reference: legs set,
moved, lowered and cleared, vertical profiles, acceleration limits, stated velocities,
approach brakes, arrival policies, settle timeouts, resets, approach speed queries, and
updates against an estimate on a random walk that drifts toward the target, with the
reached callback silent or issuing the next leg, checking every field of the leg, the
velocities, the arrival windows and the altitude and rate queries after each of the 15000
operations.

## D95. The OSD warnings line (2026-10-12)

The OSD warnings unit contains the reference's warnings line: one message chosen in the
reference's order of precedence, with its severity and its blink. Rescue failure comes
first. Arming disable reasons follow, rotated every half second to the next reason set
above the one on display and round to the lowest, with the arm switch dropped unless it is
the only reason. Then the DShot beacon guard, which shows the beacon for its first half
second and the tenths of a second until arming after it; the failsafe; and the ESC alarms
from the ESC sensor and then from the DShot telemetry, each alarmed motor with its letters,
R for a rotation at or below the alarm while the motor runs, C and T for a current and a
temperature at or above theirs, a plus where the thirty-one characters run out, and the
line centred in twelve when shorter than eleven. Below those come the crash flip, active or
switched on while disarmed; the launch control with the pitch in degrees when an
accelerometer is present, blinking within ten percent of the launch throttle; the RSSI,
RSSI dBm, SNR and link quality alarms; the critical battery; the CPU load; the rescue
unavailable in the first five seconds armed and the heading not yet known; the position
hold failure; the headfree mode; the core temperature in the selected unit with its symbol;
the low battery; the capacity alarm from the battery profile's capacity, else the setting;
the battery continued; the battery not full before the first arming; the visual beeper,
which the line reports shown so the target clears it; and the chirp excitation finished,
its series finished or one axis done.

The port follows the multirotor default build. The flight plan cues and the flight plan's
rescue descent, compiled out on default targets, and the wing launch cues, wing targets
only, are not in it. The settings, the sensors, the modes and the clock stay with the
target, which brings the values the line reads; the reason on display and the time it was
chosen are the only state the line keeps.

The harness replays six sequences of 2000 frames recorded from the reference, each sequence
under its own settings and enabled set, the frames under a precedence depth that holds off
the conditions above it so every message gets its turn. Every message of the 12000 frames
replays byte for byte with its blink, its severity and the beeper flag.

## D96. The MSP tunnel over telemetry (2026-10-12)

The MSP telemetry unit contains the reference's tunnel that carries MSP over a telemetry
link. A request arrives in chunks behind a status byte that holds the chunk's sequence
number, a start flag and the protocol version. The first chunk declares the request: the
command and payload size of a version 1 frame, the jumbo size past 254 bytes, or the flags,
the 16-bit command and the size of a version 2 frame; a version above two answers with a
mismatch error, a size past the 192-byte request buffer with a too-big error. The chunks
that follow continue the request while their sequence numbers run on from the last; a
chunk out of sequence drops the request, a chunk without a start is ignored, and a chunk
shorter than its header is ignored. The last chunk completes the request at the declared
size, extra bytes ignored, and a completed EEPROM write command reports itself so the
owner skips a few telemetry requests before replying. The reply goes back in chunks of the
link's size behind the same status byte: the first chunk carries the start flag, the error
bit for a failed request and the reply header in the request's framing, and every chunk
fills the link's size until the last carries the remainder; a reply that ends exactly on
a chunk boundary is followed by a chunk of the status byte alone.

The command processor stays with the target. The reference runs it inside the chunk
handler; the port's chunk handler reports a request ready, the owner processes it and
hands back the verdict and the payload, which the tunnel stores with an error byte
appended for a failed verdict, in the same state the reference leaves. The reply's flags
byte is zero, as the reference never sets it.

The harness replays six sequences of 400 operations recorded from the reference: requests
of every framing in chunks of random sizes with lost and out-of-sequence chunks, truncated
headers, trailing bytes and lone chunks, the processor's reply of random size under a
random verdict, requests arriving while a reply is still going out, and the replies pulled
at the SmartPort, CRSF and random chunk sizes. Every chunk, request state and reply state
of the 28655 lines replays byte for byte.

## D97. The OSD formatting (2026-10-12)

The OSD format unit contains the reference's formatting helpers, the functions the OSD
elements call to turn readings into text. A number prints with a leading and a trailing
symbol, its decimals, rounded half to even or cut at the last decimal, the integer part in
a width with zeros or spaces and a character before it, and a minus sign when the value is
negative and the digits are not all zero. Altitudes print in the selected unit with one
decimal or none, above the launch point or above sea level. Coordinates print from
ten-millionths of a degree with seven or four decimals, as degrees, minutes, seconds and
tenths with the hemisphere letter, or as the eleven-digit plus code, and read as zero until
the first fix. Distances print in feet or metres below a mile or a kilometre and in miles or
kilometres above with one decimal from ten and two below. A PID line prints its label and the
five gains in three places each. The clock prints the reference's short local form, the month,
day, hours and minutes, or the time alone, and prints nothing without a clock. Timers print
minutes and seconds with hundredths or tenths by their precision from the source their
setting names, the on time, the flight time, the last armed time, one or the other by the
arming state, or the launch time, with the source's symbol before them. The battery symbol
is the critical one or the cell voltage's step over the profile's range, the direction
symbol the heading's sector of sixteen, and the unit conversions cover metres, speeds,
climb rates and temperatures with their symbols.

The plus code unit contains the reference library's encoder for the grid lengths, the
only lengths the OSD asks for: the latitude clipped to its range and the pole moved half
a precision south, the longitude wrapped into its range, the two positions scaled to
integers at the grid precision, the five grid digits from the five by four refinement and
the ten pair digits from the base twenty alphabet with the separator after the eighth.

The warnings line now takes its unit system and its temperature conversion and symbol
from the format unit, where the reference's warnings call the elements file. The battery
symbol requires the profile's cell voltage limits to differ, where the reference divides
by their difference (finding F103). The readings and the settings stay with the target.

The harness replays six sequences of 1500 calls recorded from the reference, each call to
one helper under random readings, units, variants and symbols, the clock set to times
before the reference's conversion limit (finding F104) and the formats of the elements'
calls. Every text, symbol and conversion of the 9006 lines replays byte for byte.

## D98. The transmitter driver over MSP (2026-10-12)

The VTX MSP unit contains the reference's transmitter driver for a video transmitter
reached over the MSP link, the goggle systems' way. The driver starts offline and is ready
once the transmitter has answered on the driver's link and the table has bands, channels and
power levels. The configuration it holds is what the control layer sets, band and channel,
the power looked up in the table by index, the pit mode and the frequency, each marking
the configuration changed when it differs. Each cycle, once ready, a change of the low
power state marks the configuration changed too, and a changed configuration goes out once
two hundred milliseconds have passed since the last: the fifteen-byte frame with the device
type, the settings' band, channel and power, the lowest power while low power disarmed, the
pit mode, the frequency, the readiness, the low power setting, the pit mode frequency and
the table's counts, as an MSP reply carrying the transmitter configuration command. The
same frame wrapped for the CRSF telemetry buffer gets the sync byte, the length, the MSP
response type, the receiver and flight controller addresses, the header of a first chunk
in version 2, the MSP checksum and the frame checksum. The configuration reads back once
ready: the band and channel, the power index found in the table or zero for no power, the
frequency of the band and channel, the pit mode, and the table's power levels in
decibel-milliwatts and in milliwatts through the C library's power function.

The link, the port sharing that decides between the serial push and the CRSF wrapper, the
port selection of the initialization, and the command processor that reports the
transmitter's answer stay with the target: the owner tells the driver its link answered,
and pushes the frame the cycle hands back by the way its link requires.

The harness replays six sequences of 1200 operations recorded from the reference, each
sequence under its own table and settings, the operations the control layer's setters and
getters, the link's readiness with matching and foreign descriptors, the cycle under random
times, arming, failsafe and link flags, and the frame preparation alone. Every state field,
reply frame, wrapped frame and reading of the 7206 lines replays byte for byte.

## D99. The MSP display port (2026-10-12)

The display port MSP unit contains the reference's display port over the MSP link, the
OSD canvas of a goggle system. Each operation is a display port payload the target sends
as an MSP reply in the first framing: the heartbeat, the release, the clear, the draw, a
string at its column and row with the attribute byte, a system element at its column and
row, and a font character at its address with the sixty-four bytes of the glyph. The
attribute byte takes the profile's font bank for the element's severity and the device
blink bit for a blinking element; a string is cut at thirty characters, an empty string
sends nothing, and a character is the string of that character, the null character an
empty one. The initialization takes the canvas size from the configuration for a high
definition system and the standard lines of PAL or NTSC with the standard columns
otherwise, each with the profile's adjustment, and sends a clear and a draw. The display
layer's bookkeeping over the port is in the unit: a grab sends the heartbeat and a clear
and counts, a release the release payload, a clear marks the screen cleared and the
cursor off, and the device reports itself synced, ready and never mid-transfer.

The MSP link, the serial port the display answers on, the port selection of the
initialization and the eighty millisecond pause after a font character stay with the
target.

The harness replays six sequences of 600 operations recorded from the reference behind
its display layer, each sequence under its own profile, video system and canvas: grabs,
releases, clears, draws, heartbeats, redraws, strings of every length and attribute,
characters, system elements, font characters and the state queries. Every state field,
payload and result of the 3606 lines replays byte for byte.
