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

Amended 2026-10-13: the settings table keeps the reference's setting names and lookup
strings verbatim, so the command line reads and writes the reference's text and its diffs
paste. Four of those lookup strings name other projects: three rate types and one SPI
receiver protocol. The user ruled this exception for the generated table on 2026-10-13.
The sanitization gate allows the two of them it would reject, as whole upper-case strings,
in that table and its vectors, and nothing else.

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
deliberate deviation has a declared tolerance in the checker, an entry in this ledger and a
line in `DIVERGENCES.md`, which lists them all.

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

Amended 2026-10-13: the GPS rescue's two-argument arctangent (D6, D83) takes the same route
through the double-precision elementary functions, and its body is the second outside SPARK.

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
counts truncated back to counts before scaling. The stability record is a shifted bit mask. D136
adds the ESC sensor, virtual and MSP meters. The cutoff percentage is held to its range where the reference's byte leaves it after
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

## D34. Altitude hold with the autopilot's altitude controller (2026-10-09)

`Adaflight.Altitude_Hold` runs the hold in this order each task. Engaging the flight mode resets the
controller, sets the target to the current altitude, and captures the hover throttle from the stick
when no setting gives one. Releasing the mode resets the controller and drops the captured throttle.
Outside its deadband around the hover throttle, the stick moves the target. Under a failsafe or an
emergency descent the target instead drops at a rate that grows with altitude. Either way the target
moves only while the altitude estimate stays within one second of climb of it. Last, the autopilot's
altitude controller sets the throttle: relaxed integral, proportional term held through the
derivative gain, boosted derivative, acceleration and feedforward terms, hover offset, tilt
compensation, and throttle limits as a fraction of the receiver's range.

The mode, task interval, stick and its low status, failsafe, emergency descent, altitude estimate,
and tilt come in as inputs, since other units own them. Navigation targets that can replace the
stick's come with the navigation port. One guard covers a division by zero in the reference: a stick
beyond the receiver's range against a hover throttle at the range's edge leaves the stick factor at
zero. The target velocity is held to a bound that a stick within the receiver's range cannot reach.
No recorded vector reaches a guard.

## D35. Launch control inside the rate loop (2026-10-09)

The rate loop contains launch control. While the mode is active, the setpoint is twice the stick's
deflection within a half, scaled to the launch rate, on pitch alone or on every axis. On pitch the
setpoint runs down to the minimum rate over the last ten degrees before the angle limit, and to zero
past it. Iterm relax is skipped. The integral gain is the launch gain on every axis, and the yaw
windup limit and anti-gravity accelerator stay as they were. The D term and feedforward are zero.
After each axis the loop holds the yaw I term to its launch limit. In the pitch-only mode it also
holds the roll P and I terms and the yaw P term at zero and the pitch I term at or above zero. Each
axis's sum sees the holds applied before it.

The loop takes the mode's activity and the yaw stick as inputs. Activation from the mode switch, the
throttle trigger, and the arming delay stay with the core loop's port. The launch setpoint and the
held terms are contracted helpers. The setpoint's scaling over the angle window is held to the
launch rate, which a stick within a half cannot exceed. No recorded vector reaches a guard.

## D36. Launch control activation and runaway takeoff prevention in the core loop (2026-10-09)

The arming unit contains two core-loop guards. Launch control activates at arming when the switch is
on, arming is by switch, the motors run or airmode is on, 3D is off, and no flight mode is selected.
It triggers when the throttle passes its percentage, which also requests an I term reset. It clears
on disarm, or on a trigger only when the switch is off and the trigger reset is allowed. While
active it keeps stabilisation on and stops airmode from latching.

Runaway takeoff prevention runs after the controller. It watches for a sum past 600 with a rate past
15 degrees per second on roll or pitch, or 50 on yaw. Held for 75 milliseconds while armed with the
motors running, that condition disarms with its own reason and disable flag. Stable flight ends the
check once its delay has accumulated, halved at high throttle. Stable flight means the throttle
above the deactivation level with the sticks active, or above twice that level, and every sum under
100.

The controller's sums, the gyro's whole-degree rates, and the sticks' deflections join the inputs,
since other units own them. An arming attempt zeroes the runaway timers. The trigger deadline uses
the wrapping difference, which D6 records. The GPS rescue's hold on the runaway check and the
temporary disable that other features request come with their ports.

## D37. In-flight adjustments (2026-10-09)

The adjustments unit contains the adjustment task. The set ranges are listed once, as steps when
their center is zero and their function steps, and as dials otherwise. Each pass runs the steps
whose range is active. A step waits out the half-second ready timer and fires once per hold of the
switch past four tenths of its deflection from the configured center. The switch back at the center
arms the next step at once. Then, while the receiver has a signal, the pass runs the dials whose
switch channel moved. A dial selects a profile, the horizon strength, the master multiplier, or a
peripheral mode by the channel's position over the range of the mode steps. Otherwise it sets a
stepping function from the dial through its scale and center. Every step and dial change applies to
the rate profile that was active when the pass began.

The unit owns the selections that profiles and peripherals read, the display that names the
on-screen element for two seconds after a change, and the sticky configuration-dirty flag. It
reports the confirmation beeps and the PID, RC, and battery reinitializations a pass asks for, since
other units own those. The master multiplier runs the simplified tuning of the PID gains, which has
its own unit. The simplified filter sliders are in D152, and the OSD profiles come with the
configuration phase.

Two guards cover undefined behavior in the reference. A range whose function is None is skipped,
where the reference reads outside its function table (finding F27). A dial value is held within two
to the thirtieth before its conversion to an integer. D6 declares the feedforward and horizon
strength holds. The display and the timers compare through the wrapping difference. No recorded
vector reaches a guard.

## D38. Cooperative scheduler as phases around the clock reads (2026-10-09)

The scheduler unit contains the task scheduler. Each task in the table has a period, a static
priority, and a check function. Enabled tasks queue by static priority, equal priorities in order of
arrival. The realtime gyro, filter, and PID tasks lock to the gyro cycle. That lock recovers from a
gross overrun and tunes the start wait up when the loop arrives late and down when it polls. It
measures the gyro rate over 25000 interrupts and removes the skew to the interrupts every 50.
Dynamic priorities grow with the periods a task has waited, and check functions signal the
event-driven tasks. The highest-priority task must fit into the time left before the next gyro
cycle. The measured check time and the guard margin are tuned on each run's overrun. An unfit task
is deferred but runs every eighth pass, and a task skipped often enough has a tenth cut from its
estimate. Execution statistics are kept per task.

The reference runs a whole pass inline, tasks and clock reads together. The unit splits the pass
into phases at the clock reads. The pass begins with the first cycle reading. The caller polls up to
the target and runs the realtime tasks between the execution prologue and epilogue. The realtime
block ends with the gyro lock. The selection begins with the second reading, takes each queued task
in turn with its check's result, and ends with the third. The fourth reading confirms the fit, and
the fifth follows the run. The caller reads the cycle counter at those five points, so the recorded
passes, replayed with a cycle per read and the recorded durations, match cycle for cycle. Every
count keeps 32-bit wrapping arithmetic through the two casts between signed and unsigned counts.

Amended 2026-10-13: the floor on a rescheduled period and the gyro loop's period are platform
settings. They are 10 and 125 microseconds on the STM32 F4 and later, 100 and 1000 on AT32 and the
older STM32, and 1 and 100 on the simulator. The unit had held the floor at 100 for every platform.
With a floor of 1, a checked task's age, one plus its waiting time over its period, can pass the
32-bit range. The sum is therefore taken in 64 bits and keeps the low 16 bits that the reference
stores. The recorded passes reschedule at 125 microseconds and up, so they replay the same, and the
checker gives the scheduler the oracle platform's floor of 1. Two guards cover divisions by zero in
the reference: the overrun recovery and the skew run only while the gyro period in cycles is
positive. No recorded vector reaches a guard.

## D39. Beeper (2026-10-09)

The beeper unit contains the beeper. Sounds sit in a table in priority order. A request starts its
sound only when it outranks the one playing. The silence mode, the mute switch, and bench
suppression silence the beeper. Bench suppression applies to the USB flag with no battery and a USB
or configurator link. A sound is a sequence of on and off durations in tens of milliseconds, with a
leading zero for a pause first, ended by a stop or a repeat. Confirmation beeps, warning beeps, and
the satellite count fill a multi-beep buffer and play through the multi-beep entry, with room kept
for the stop.

The periodic update requests the beep switch's sound or the satellite count. It raises the DShot
beacon when the motors are stopped and either the link is lost without a configurator or the beep
switch is on with a link. The beacon waits out the guard after a disarm, stays off while arming, and
comes at most every 450 milliseconds. The update clamps the beacon time to a minute's age. It then
plays the next step of the sequence once its toggle time has passed, recording the first on step of
an arming sound as the arming beep's time.

The unit owns the beeper's on state, the warning LED's enable, and the visual beep's edge. The
beacon command, the visual beep, and the scheduler's exec-time waiver are the update's outputs,
since other units own them. The conditions the beeper reads come in as a record: battery, links,
mode boxes, GPS, motors, failsafe, and arming state. The arming beep's time is the update's time,
where the reference reads the clock again. One guard covers a read past the buffer in the reference.
A sequence that reaches the buffer's end without a stop ends as an error and silences the beeper,
where the reference walks into adjacent memory (finding F29). No recorded vector reaches a guard.

## D40. Receiver (2026-10-09)

The receiver unit contains channel processing. The active provider's raw channels are read through
the map into flight order. The four flight channels are scaled through their calibration ranges. A
range whose low end is above its high end inverts its channel. The type rules out equal ends, where
the reference's scale divides by zero (finding F31).

A received frame marks the signal and the data to process. The signal drops 150 milliseconds after
the last frame and asks for the loss to be processed, then rechecks every 50 milliseconds. On signal
loss a good channel's hold timer resets. A bad channel holds its last value for 300 milliseconds and
then its failsafe setting. A bad flight channel past that hold declares the flight channels invalid.
The failsafe switch applies its settings at once. In stage two the valid flight channels stay, the
throttle takes the failsafe throttle and the other flight channels the center, and the aux channels
take their settings.

Pulse receivers keep a three-sample moving average with its suspension and two skipped samples. Link
quality comes from the last sixteen frames. RSSI comes from an aux channel, from the frame errors
over each 100 milliseconds, from the analog input every 20 milliseconds, from the protocol, or from
the configurator with its 1.5-second timeout. RSSI is smoothed toward its raw value, along with the
dBm and the SNR.

The frame's flags, the raw channels, the failsafe switch, the 3D switch, the stage, and the task's
state come in. The data to process, the auxiliary frame to process, and the validity the failsafe
hears go out, since other units own them. The frame error sum is bounded by its poll count times the
full RSSI and the count stops at 65535 polls, so the mean over a window is exact at any frame rate.
The reference's 16-bit sum wraps above 64 good frames per window (finding F30). Every conversion of
a channel value to a 16-bit count holds a value outside the count at the bound, where the
reference's conversion is undefined. D6 declares the negative RSSI case. The recorded vectors keep
the pulses and ranges where the scaled values stay within the count. No recorded vector reaches a
guard.

## D41. SBUS protocol (2026-10-10)

The SBUS unit contains the SBUS receiver. Each serial byte arrives with its time. A gap of more than
five byte times restarts the frame. A frame starts only on the begin byte, and the twenty-fifth byte
completes it. The status poll decodes a complete frame once: sixteen eleven-bit channels from the
little-endian bit stream of the twenty-two channel bytes, and two digital channels from their flags.
The poll reports failsafe when the receiver flags it and dropped when it flags a signal loss.
Otherwise it keeps the frame's start as the frame time. The raw value the receiver reads is the
channel's fit to the X4R, five eighths of the count plus 880. Every channel starts at the count that
reads as the configured center. The serial port and the telemetry sharing stay with the port layer.
Where the reference uses packed bit fields, the unit unpacks by position, and the decoded channels
agree bit for bit. No guard was needed.

## D42. CRSF protocol (2026-10-10)

The CRSF unit contains the CRSF receiver. Each serial byte arrives with its time into a frame. The
frame restarts after the time a frame needs at the current rate, and a restart with a frame under
way counts an error. The declared length is checked as it arrives, and an invalid one drops the
frame without an error. The CRC runs over the type and the payload with the DVB-S2 polynomial. A
good frame clears the error count and asks for a telemetry response. The RC channel frames for the
flight controller are copied for the status poll. The poll unpacks the sixteen eleven-bit channels
of the packed frame, or the subset frame's channels at its ten to thirteen-bit resolution from its
start channel. A subset with no channels or a start past the last is dropped.

Link statistics for the flight controller go into the receiver. When the protocol owns the RSSI, the
active antenna's RSSI in dBm is scaled onto the RSSI range. The dBm, the antenna, and the SNR always
go in, and the link quality and RF mode go in when the protocol owns the quality. The uplink power
comes from its table. Third-version transmitter statistics go the same way. The 250-millisecond
statistics timeout at each poll zeroes the owned values. A command frame for the flight controller
is checked by the command CRC and reported for the port layer to process. The error count asks for
the default speed at three, unless a baud negotiation or an EEPROM write is under way.

The raw channel value goes through the frame type's scale. A negotiated rate recomputes the frame
time, and above the default rate the inbound frames drive the telemetry. The serial port, the
telemetry, and the configurator frames stay with their layers. The unit keeps the frame time and the
frame's start, like the SBUS unit. Two guards cover values the reference's conversions leave
undefined: a scaled RSSI below zero is held at zero, and a frame whose declared length escaped the
check is held to the frame size. The receiver takes the protocol's claims of the RSSI and the link
quality at its own init. No recorded vector reaches a guard.

## D43. SUMD and SUMH protocols (2026-10-10)

The SUMD unit contains the SUMD receiver. Each byte arrives with its time, and a gap over four
milliseconds restarts the frame. The sync byte starts the frame and clears the CRC. The third byte
gives the channel count. Bytes are kept while the buffer has room. The CRC runs over the header and
the channels, and the frame completes two bytes after the channels. The status poll takes a complete
frame only when its CRC matches those two bytes. The state byte makes the frame failsafe or
complete, and up to eighteen channels are copied. The raw value is the channel's eighth. A frame
that declares more than thirty-two channels is dropped at the poll, where the reference reads its
CRC bytes past the buffer (finding F32). The caller takes the unit's frame time for a frame that is
not failsafe.

The SUMH unit contains the simpler SUMH receiver: twenty-one bytes, with a restart after a gap over
five milliseconds. The poll takes the eight channels when the sync byte and the zero before the last
byte check. Each goes through the scale, a sixth and four tenths less 375, and is held at zero where
the reference's conversion of a negative value is undefined. The raw value reads zero past the
eighth channel. The recorded vectors keep the channel words where that conversion is defined. The
serial ports stay with the port layer. No recorded vector reaches a guard.

## D44. IBUS protocol (2026-10-10)

The IBUS unit contains the IBUS receiver for its two receiver families. Each byte arrives with its
time. A gap over 500 microseconds starts a new frame and ends any echo skip. A byte of a telemetry
reply's echo is skipped. A frame starts on an IA6B length byte (four for a telemetry request,
thirty-two for channels), on the IA6 sync byte before any family is known, or on the known sync
byte. The last byte of the frame's length completes it. The status poll takes a complete frame once
its checksum matches: the IA6B subtraction from all ones over the bytes before the two checksum
bytes, or the IA6 sum of the fourteen slots onto the seed. The poll decodes eighteen channels,
fourteen from the slots' twelve bits and four from the spare high bits, or reports a telemetry
request from a short IA6B frame.

The reference checks that the frame has room for each of the four high-bit channels. That holds for
both families' offsets, so the unit reads them without the check. The telemetry layer hands back the
length of its reply so its echo is skipped. The raw value is the channel count itself. The state's
predicate ties the family to its sync byte, frame length, and slot offset, and keeps the frame's
first byte equal to the sync byte. The checksum and channel reads are therefore proved within the
frame without clamps, and a frame start writes those fields as one aggregate to keep the predicate.
A byte is kept only while the frame has room. The reference writes past its buffer when a zero byte
before any sync is known is followed by more than thirty-one bytes without a gap (finding F33). The
telemetry reply itself is Phase 6, and the serial port stays with the port layer. No recorded vector
reaches the guard.

## D45. Spektrum protocols (2026-10-10)

The Spektrum unit contains the DSM receiver for its two resolutions and the SRXL variant. Each byte
arrives with its time. A gap over five milliseconds starts a new frame, and the sixteenth byte
completes the frame at its own time. The status poll takes a complete frame once and fills the RSSI
channel first. For SRXL the RSSI channel comes from the dBm report in the first byte, held through
four fades and dropped to the minimum at the fifth, through the range table onto the resolution. For
a satellite receiver it comes from the fade count: one byte with the system type while the receiver
reads as bound by the flight controller, and two bytes once a frame says otherwise. The count is
differenced over the half second and mapped from the fade limit down to zero, and the reference's
sixteen-bit conversion wraps it.

The poll then takes the VTX control word from the last four bytes of a first-phase frame for the VTX
layer and leaves those bytes out of the channels. The remaining channel pairs are decoded by the
resolution's shift and mask into the channels below the count, skipping the RSSI channel. A
first-phase frame opens the SRXL telemetry request. Once a queued reply has waited a millisecond
after the request, the poll asks for processing, which sends the reply and clears it. The raw value
is zero past the channel count, half the count plus 988 at the high resolution, and the count plus
988 otherwise.

The settings give the provider, whether the telemetry feature is on with the port unshared, and the
one-based RSSI channel. A channel past the count is dropped, as the reference's byte wrap drops
zero. The range table's interpolation runs on typed intermediates sized from the table, so it proves
without clamps. The fade mapping's wrap is the reference's own. The VTX control handling, the
telemetry content, the bind pulses, and the serial port stay with their layers. The reference
assembles the VTX control word with a shift that overflows a signed integer on every control frame
(finding F34). The unit shifts the unsigned word. No guard was needed.

## D46. XBUS protocol (2026-10-10)

The XBUS unit contains the XBUS receiver for the Mode B and RJ01 providers. Each byte arrives with
its time, and a gap over eight milliseconds drops the frame in progress. A frame starts on the
twelve-channel start byte, or on the sixteen-channel one in Mode B, with the length the provider and
the start byte give it. The last byte of that length unpacks the frame in the receive path, not at
the status poll. A Mode B frame yields its twelve channels through the pulse conversion, 800 plus
the word's 1400 fraction of 4096, once the CRC-16 over all but its last two bytes matches them. An
RJ01 outer frame yields the Mode B frame three bytes in, once its length byte reads 30 and the
Dallas CRC-8 over all but its last byte matches that byte. The status poll reports complete once per
unpacked frame. The raw value is the channel value itself.

The Mode B case ends at its own unpack. The reference's falls through into the RJ01 check, which
accepts a Mode B frame whose second byte reads 30 and whose Dallas CRC-8 matches its last byte, and
unpacks the bytes from offset 3 through the stale tail of the buffer (finding F35). The Mode B
sequences of the vectors each contain a frame pair built for that path: a sixteen-channel frame that
leaves its bytes 27 to 29 in the buffer, then a twelve-channel frame with length byte 30, a matching
outer CRC-8, a failing CRC-16 of its own and an inner CRC-16 that matches through the stale bytes.
The reference takes channels from that pair, the unit takes none. The state's
predicate keeps the position below the frame length while a frame comes in and at zero otherwise,
and ties the length to the provider. The frame writes and the unpackers' reads are therefore proved
within the buffer without clamps. The completion check moves ahead of the position increment to keep
the predicate. The serial port stays with the port layer. No guard was needed.

## D47. Jeti EX Bus protocol (2026-10-10)

The Jeti EX Bus unit contains the EX Bus receiver. Each byte arrives with its time, and a gap over a
millisecond drops the frame in progress. A frame starts on the channel or the request sync byte into
its own buffer. The second byte says whether the receiver may transmit. The sixth byte's message
length takes the frame when it is within its buffer's range and drops it otherwise. A byte at the
buffer's end drops the frame. The last byte of the length completes the frame with its time: the
channel frame for the status poll, the request frame for the telemetry.

The status poll takes a received channel frame once. When the CRC over the frame reads zero, the
poll decodes the channels and keeps the frame's time. It decodes as many words as the data length
holds, up to sixteen, each word's eighth, when the header names channel data with or without a
request. The raw value is the channel value itself.

The unit keeps the received frame's length beside the buffer, where the reference reads the buffer's
length byte again at the poll. The byte cannot change between the completion and the poll, since a
new frame into that buffer takes the state out of received first, so the two reads agree. The
state's predicate keeps the position within the size of the buffer the bytes go to, so the buffer
writes are proved without clamps. The CRC computes the nibble-wise form on eight- and sixteen-bit
modular words. The decode trusts the header's data length over the message length (finding F36). The
request frame, its state and time, the transmit permission, and the serial port stay with the
telemetry and port layers. No guard was needed.

## D48. Ghost protocol (2026-10-10)

The GHST unit contains the Ghost receiver. Each byte arrives with its time, and a byte after the
frame time of 500 microseconds starts a new frame. The frame is five bytes long until its length
byte is in, and that byte plus two after. A byte is kept while the frame has room. The last byte of
a frame addressed to the flight controller swaps the two buffers, marks the frame available, and
stamps its end.

The status poll takes an available frame once. The frame is complete with processing to do when the
CRC over its type and payload matches its last byte, and dropped otherwise. With no frame available,
the poll asks for processing alone when a telemetry reply waits and the bus has been quiet for more
than one and less than two milliseconds since the last frame. The processing sends the reply in that
window and then decodes the validated frame. A statistics frame sets the RF protocol with the
telemetry it allows and gives the receiver its RSSI, dBm, and link quality. The aux frames name the
four channels each one contains. Once the protocol is known, the four primary channels come from
their packed twelve bits, the aux four widened from eight, and a legacy frame is rescaled to the
twelve-bit range. The MSP frames go to the MSP layer with their payload length. The raw value is a
quarter of a primary count or an aux count as it is, plus 988.

The unit keeps the completed frame's length beside the buffers, where the reference reads the length
byte again at the poll and the processing. The validated buffer is not written until the next swap,
so the two agree. The swap itself is kept so the stale bytes of a short frame come from the same
buffer as the reference's. The RSSI scaling and the legacy rescaling hold a negative result at zero,
where the reference wraps it to sixteen bits, so a weak RSSI reads as full strength and a low
channel count as a value near the top of the range (findings F37, F38, D6). The telemetry content,
the MSP handling, the idle callback's source, and the serial port stay with their layers. No guard
was needed.

## D49. MSP receiver (2026-10-10)

The MSP receiver unit contains the receiver fed over MSP. A frame from the command handler sets the
channels it contains and resets the ones it leaves out to zero. It marks the frame done for the
receiver and for the override path, and keeps its time and channel count. A channel is fresh while a
frame has ever arrived, the last frame contained it, and that frame arrived within the last 300
milliseconds. The status poll reports complete once per frame and stamps the frame at the poll. The
override poll reports complete once per frame. The raw value is the channel value itself. The
command handler bounds the count at eighteen, so the count is a subtype. The millisecond difference
is the reference's unsigned one. No guard was needed.

## D50. SRXL2 protocol (2026-10-10)

The SRXL2 unit contains the SRXL2 receiver. Each byte arrives with its time and goes into the read
buffer while it is free and has room. Otherwise the packet is dropped. The port's idle ends a
transmission. It frees the read buffer when nothing came in, or hands the packet over by swapping
the two buffers, keeping the idle time.

The status poll processes the handed-over packet. The packet is dropped unless its id, its length
byte, and its CRC over the whole packet check, and then it is valid at the poll's time. A broadcast
handshake names the bus master, takes the fast rate when the master supports it, and runs the link.
A handshake to this unit gets the reply with the ids swapped, the priority, and the rate offered.
Control data requests telemetry when its reply id is this unit's. Its channel data gives the RSSI
percent onto the receiver's range when it is not negative, a dropped frame when the mask is empty,
and each channel under the mask from the next word. Its failsafe sets the RSSI to zero. Its VTX data
is packed into the Spektrum control word for the VTX layer.

The link state machine then runs. It listens for activity and toggles the rate while bytes come
without a valid packet. At its timeout it moves to sending or listening for a handshake. When a
handshake or the frames time out, it falls back to listening at the default rate with a failsafe
result. Processing is asked for when the write buffer holds a reply, and the processing sends it
once the bus has been idle for the reply quiescence. The bind request and the telemetry frame that
the telemetry layer fills go out through the same write buffer, with the CRC in their last two
bytes. The raw value is the count's quarter over sixteen plus 988.

The reference reads a handshake's or a control packet's fields without checking the packet's length
against them, so a short packet yields stale buffer bytes. The unit reads the same bytes from the
same buffer so the recorded vectors match (finding F39). The sending state asks for processing
without a reply to send (finding F40), and the unit keeps that. The baud rate the unit asks of the
port is its own field, where the reference asks the port back. The telemetry content, the MSP and
VTX handling, the serial port, and the idle callback's source stay with their layers. No guard was
needed.

## D51. FPORT protocol (2026-10-10)

The FPORT unit contains the FrSky FPORT receiver. Each serial byte arrives with its time. A marker
byte closes the frame in progress when it holds two bytes or more. The frame goes into a ring of
three buffers when the ring has room, a telemetry request opens the reply window and stamps its
time, and the marker starts the next frame. A byte after the escape has its fifth bit flipped, the
byte in the type position marks a telemetry request, and a byte is kept while the frame has room. A
frame older than the frame time plus half a millisecond is dropped, and so is one that outgrows its
buffer.

The status poll takes one frame from the ring. The frame counts when its length byte agrees with the
frame and the FrSky checksum folds to all ones. A control frame decodes its channels and flags
through the SBUS channel block, which the SBUS unit now exposes for both protocols. It scales its
RSSI from a percentage onto the receiver's range, stamps the control time, and keeps its start as
the frame time unless the receiver flags failsafe or a signal loss. A telemetry request counts only
while the telemetry layer is on. A data frame hands the frame rate to the receiver and asks for a
reply. A null frame asks for a reply until two have gone unanswered while the receiver does not
drive the rate, unless an MSP payload waits. A read or write frame keeps its payload for the
telemetry layer.

The poll asks for processing when a reply or a payload waits and half a millisecond has passed since
the window opened. It drops the RSSI to zero half a second after the last control frame. The
processing closes the window two milliseconds after it opened, consults the telemetry layer while it
is open, sends the empty reply when the layer left the window unused, and consumes the payload. The
reply's bytes, the telemetry content, the MSP handling, and the serial port stay with their layers.
A reply that the telemetry layer writes drops the frame in progress through `Begin_Reply`. The raw
value is the SBUS fit of the channel count. The ring indices, the frame position, and the escape and
request flags keep the state the recorded vectors see. No guard was needed.

## D52. MAVLink receiver (2026-10-10)

The MAVLink unit contains the MAVLink receiver with the library's frame parser, and the
MAVLink_Entries unit contains the library's message table behind the same bisection. Each serial
byte goes through the parser's states in the library's order. A start byte of either framing version
opens a frame and resets the checksum. The version one header has no flag bytes and a one-byte id.
The version two header contains two flag bytes and a three-byte id, and an incompatibility flag
other than the signing bit drops the frame. The payload bytes fold into the X.25 checksum as they
arrive, and the message's CRC extra folds in last when the table knows the id. An unknown id, or a
checksum byte that disagrees, marks the frame bad, but the parser still reads it to the end. A
signed frame waits for its thirteen signature bytes and passes without a signing key, since the
receiver holds none. A complete frame is copied out of the parser, with the wire's checksum in place
of the computed one when the two disagree, and the copy's length follows the parser's length on
every byte. A bad checksum returns the parser to idle, or to the start state when the byte itself is
a version two start byte.

A good RC channels override message takes its eighteen channels as consecutive words from its first
channel. The ninth word is therefore the two target ids, the following words are each one channel
early, and channel eighteen is never read (finding F41). A word of zero or all ones leaves the
channel as it was. The byte's time is the frame time. A good radio status message keeps the
transmitter's free buffer and scales the remote RSSI from the negative dBm range onto the receiver's
range, with a report below the range minimum held at the minimum. The reference's scale wraps such a
report to above 64000 (finding F42). It gives the receiver the dBm, the noise as the SNR, and the
local RSSI as the link quality. Every other good message goes into a queue of sixteen for the
telemetry task.

The status poll is complete once after each override message. The telemetry may send when the last
radio status left more free buffer than the configured minimum. The raw value is the channel as it
is. The payload index is held below the payload size and the signature count above zero by guards
the recorded vectors never reach. The signature bytes, the parse error count, and the parser's
status copy are not kept, since nothing reads them. The serial port and the telemetry task stay with
their layers.

## D53. MSP serial port with its frame decoder and reply encoder (2026-10-11)

`Adaflight.MSP_Port` is the serial port of the configurator protocol. The decoder takes one byte at
a time through the three framings: version 1, version 2 inside a version 1 frame, and version 2
native. It checks the exclusive-or checksum of version 1 and the CRC-8 of version 2, and rejects a
header whose size passes the 192-byte receive buffer. Between frames a frame start cancels a pending
request, the reboot character and the hash mark set one, a start of text enters the command line,
and any other byte cancels a pending reboot. A pending request fires once the port has been quiet
for a hundred milliseconds. One call of `Process` is one scheduler pass: it completes at most one
frame and leaves the bytes after it for the next call.

The caller answers a command frame itself and hands the reply to `Encode`, which lays out the header
for the request's framing, with the jumbo size past 254 payload bytes, and closes the frame with its
checksums. The send rule (an empty transmit buffer, or room for the frame) and the five-second
configurator activity window are functions beside it. Per call the caller supplies whether the bytes
between frames are read as requests, whether a device streams on the port, the reboot character, and
whether the command line kept the port, since the serial layer and the command line own that state.

Proof covers the receive buffer index through a predicate on the port record. The position is zero
before a header, at most the header size while a header fills, and below the data size while a
payload fills, with the data size held to the buffer by the header checks, so no byte can land past
the buffer. The encoder's frame buffer is sized for the longest header, the largest reply, and both
checksums. The encoder writes the jumbo size of a combined-framing reply right after the version 1
header and the version 2 header after it, as in the version 1 framing. The reference writes the
jumbo size after the version 2 header, where a decoder that follows the version 1 layout reads the
version 2 flags and command as the size (finding F43).

## D54. ExpressLRS hopping tables and link counters (2026-10-11)

`Adaflight.ExpressLRS` holds the common part of the ExpressLRS link ahead of its receiver:

- air rate and performance tables of the 900 MHz and 2.4 GHz bands as constants
- eight frequency domains with their first and last channel as register values and their channel
  count
- hopping sequence and the 14-bit CRC of the over-the-air packet
- link quality counter
- conversions of switches, telemetry ratios, rates, power indices, and the air rate index of a sync
  packet

The sequence generator fills whole blocks of the channel count. The sync channel comes first (the
channel count halved plus one, where the version 3 protocol places it), the channel that would
repeat the sync channel becomes channel zero, and the others follow in order. It then swaps every
entry but the first of each block with an entry from the same block, drawn by the seeded linear
congruential generator in the draw order of a single pass.

Proof covers the sequence indices through the block structure: an entry and its swap partner stay
within the block, and the blocks within the 256 entries. It covers the frequency arithmetic in
modular 32-bit words as the radio registers hold it, and the link quality window through a predicate
on its record. The bit position stays below four in the last word, so the window wraps where the
hundred periods end and the word index never passes the fourth word. The current index stays below
the sequence count by the record's predicate, and a regeneration reduces the index into the new
count before the count changes. The telemetry ratio value is a byte, so the standard marker reads
zero and the disarmed marker one, as the sync packet contains them. The CRC table entry is computed
per byte instead of held in a table of 256 words, the same function of the byte. The receiver's
packet handling, the connection states, and the telemetry link follow in their own units.

## D55. ExpressLRS telemetry link (2026-10-11)

`Adaflight.ExpressLRS_Telemetry` sends a telemetry frame to the transmitter and assembles the
transmitter's MSP frames, five bytes per packet each way, with the link's stubborn confirm scheme.
The sender keeps the frame under way, copied in, up to the 64 bytes of a CRSF frame. It also keeps
the chunk position, the size of the last chunk handed out, the package number, the confirm bit it
awaits, and the count of wrong bits against a limit. A telemetry slot takes the next chunk with its
package number: the resync marker (63) while resyncing, zero for the last chunk of a frame of more
than one, else the package number.

The transmitter's bit comes back in every packet. The awaited value advances the frame, flips the
awaited bit, and ends the frame or, after a first package, waits for one more confirm so the
transmitter can tell a new frame from a resend. A wrong bit counts, and past the limit the sender
resyncs. A frame set while another is under way resyncs first. The limit is the packets between
telemetry slots (the ratio times one plus the burst, over the burst) times twenty missed packets,
eighty at reset.

The receiver takes the transmitter's chunks by package number. The marker restarts the frame and
flips its bit. The expected package or a final package is taken and flips the bit. A first package
in mid frame restarts the frame, and a package after the last is ignored until the caller unlocks
it. Proof covers both buffers through predicates on the records: the position never passes the
length, so a chunk copied in or out stays within the frame. The sender's advance by the last chunk
is held at the length. A frame replaced between the chunk and its confirm could pass it, but the
protocol never does that, since the transmitter flips its bit only for a chunk it received. The CRSF
frames the sender sends, the device info reply, and the MSP frame handling behind the receiver come
with the CRSF telemetry port.

## D56. Flight log field encodings (2026-10-11)

`Adaflight.Blackbox_Encoding` writes the field encodings of the flight log into a stream over a
caller-owned array:

- unsigned variable byte integers: seven bits per byte, low bits first, the high bit set while more
  follow
- signed values through the zigzag mapping
- 16-bit and 32-bit words, low byte first
- float as its bit pattern
- packed groups

The group of three takes a two-bit selector for 2, 4, or 6 bits per field, or 32-bit fields of 1 to
4 bytes each behind a second selector of byte counts, the first field in the low bits. The variable
group uses the 5-5-4 and 8-7-7 bit splits instead and returns its selector. The group of four takes
a one-byte selector of field widths (none, 4, 8, or 16 bits) and packs the fields by nibbles, the
high nibble first, with a closing nibble when one is left open. The group of up to eight writes one
field bare, and more behind a header byte that marks the fields that are not zero, the first field
in the low bit, then those fields as signed variable bytes. The bytes come from the two's complement
bits of each value, so a field wider than its selected width is cut to it.

Every encoder asks for the room its longest form needs: five bytes per variable byte integer,
thirteen for a group of three, ten for the group of four, and one plus five per field for the group
of eight. Proof covers every write through the stream's contract, so no encoder can run past the
array. The header lines in text and the frame logic that chooses the encodings come with the log
itself.

## D57. Text conversions (2026-10-11)

`Adaflight.Text` holds the conversions the command line, the display, and the log headers need:

- digits of a number in a base from two to thirty-six, with lower or upper case letters past nine
- signed number in decimal, or in a base with uppercase letters where a base outside the range reads
  as ten
- fixed form of a float with three decimals behind a leading space or minus sign, rounded half away
  from zero
- float read from its text
- character classes and case folds over the basic letters alone
- comparison and search that ignore case
- formatter

Every writer takes the caller's buffer and reports the length it used, and each contract asks for
the room of the longest form, so no writer can run past its buffer. The fixed form accepts
magnitudes to two million and asks for twelve characters, where the reference's declared buffer of
eleven overflows from a magnitude of one hundred thousand (finding F45).

The float reader adds three rules. A mantissa or a divisor past 3.0E37 takes no further digit. The
scale of an exponent comes from a table of the thirty-nine values that the repeated products of
1.0E8 and 10.0 produce. The product of mantissa and scale is formed in double precision and
saturates at Float'Last where the reference overflows to infinity, so every finite result matches
and no float operation can overflow.

The formatter takes its arguments as a list of 32-bit values and slices of a caller's text pool. It
fills the d, u, x, X, c, s, and %% conversions behind an optional zero flag and width, and treats
the l modifier as nothing, since every number is 32 bits. It stops at a template that ends inside a
conversion, writes nothing for a conversion with no argument left, and holds the output to the
buffer's length. Its width parser takes a letter a or A after a width digit as a digit of ten, a
comparison kept from the reference so the vectors match (finding F44). The search returns no match
for an empty text, where the reference reads past it (finding F46). Proof covers every buffer index
and the float bounds of the reader. No recorded vector reaches the saturation or the empty-text
guard.

## D58. DShot protocol (2026-10-11)

`Adaflight.DShot` holds the protocol pieces that need no output hardware. The frame puts eleven
value bits over the telemetry request bit and the checksum of the three nibbles above it, inverted
when the reply shares the signal line. The command conversions map the 1000 to 2000 range onto 48 to
2047 and back. Each linear map is one factor and one offset written as nine-digit literals of the
single-precision constants a compiled reference folds, so every product and sum rounds once as the
compiled form does. The reverse map rounds to the nearest command with a tie going to the even one.
It uses a helper that takes the exact fraction above the truncated value, because the hosted
rounding attribute is outside the proof tool's support, and the maths unit's rounding has no
postcondition that ties its result to its argument, which the command range needs. The endpoints
take the idle setting in hundredths of a percent and the output limit as a fraction, and write the
low and high outputs and the stop. The two deadband edges of the two-direction mode are written only
in that mode.

The sampled reply decoder keeps the preamble skip, the smallest margin, and the next check time in a
record the caller owns. It finds the first low sample, then reads the samples one at a time within
the count, closing a run at every level change that is not the last position in reach. The
reference's unrolled scan reads up to three samples past the count when the preamble ends within
sixty-nine samples of it. Those reads never change the result, so the single reads are the same
decoder without the over-read (finding F48). The groups decode through the table of sixteen five-bit
codes with the invalid marker, and the nibble checksum gates the twelve-bit value. The period decode
shifts nine mantissa bits by the three exponent bits and divides sixty million hundredths by the
period, with the all-ones value as a stopped motor and a zero period as invalid. Proof bounds the
result at six hundred thousand.

The telemetry record contains the raw value, the last value per kind, the received set as a byte,
the highest temperature per motor, the processing state, the motor count, the rate factor from the
pole count, the forced extended decode, the rate filters, and the rates. Update decodes every motor
once per marked frame, keeps the kind's value as a 16-bit word, and folds the rate. It then runs the
rate filters over the stored words and takes their minimum. A rate above 65535 hundredths wraps in
the stored word while the per-motor rate uses the full value (finding F50). The sensor record gives
the period word as a signed 16-bit value. The pole count is one to 255, so the rate factor stays
below four. The reference accepts a zero pole count from the ground link and divides by it (finding
F49).

The quality record counts replies per hundred-millisecond bucket over ten buckets with the two
running sums. The invalid share is the rounded ratio in hundredths of a percent. A share at or above
9999.5 is returned as the whole without the rounding helper. That is the value the rounding gives
there, and it keeps the result in its range when the sums disagree, a state no counting sequence
produces. The output order check resets an order that is not a permutation of its indices to the
identity, and the postcondition bounds every entry by the length. Proof covers the sample indices
against the count, the shifts, the margin narrowing to a byte, the bounded period, the rate bounds,
and the order bounds. Every recorded vector replays exactly.

## D59. CRSF telemetry frames (2026-10-11)

`Adaflight.CRSF_Telemetry` writes every telemetry frame of the link from readings the caller
supplies, so the sensors, the battery meter, the attitude estimate, and the flight state stay with
their units. A frame is the sync byte, the length, the type, the payload, and the checksum over type
and payload.

- position frame: speed and course scaled, altitude held to zero to five thousand meters
- extended position frame: fix type derived from the fix flag and the satellite count
- battery frame: drawn charge in three bytes
- attitude frame: each decidegree angle reduced into a half turn and scaled by the single precision
  product of pi over 180 and a thousand
- compass frame: three times the field, truncated
- flight mode frame: name picked by priority, one character added while disarmed outside a failsafe
- device info frame: name from the caller

The packed altitude of the barometer frame keeps the reference's wrap above 32767 meters (finding
F51), and the packed climb rate goes through the logarithm approximation and the ties-to-even
rounding of the maths unit. The inertial frame scales rates and accelerations to sixteen bits
through a clamp that proof needs and the values never reach.

The schedule has one slot per enabled kind. Heartbeats fill it to five slots unless inertial frames
run, and the position and barometer frames are timed rather than slotted. The slots keep stale
entries past the count, and the slot index survives a new schedule, so a shorter schedule reads them
until the index wraps, which the vectors cover. The speed negotiation answers a proposal with the
command frame and its second checksum, applies the rate after four milliseconds, and marks the third
version running. The reference drains its one-frame receiver buffer before every pass, so its check
before the schedule is always true and the port has no such gate. The MSP buffer and the display
port chunks stay with their units. Proof covers every frame against the room of the longest, the
sixteen-bit conversions, the angle reduction, and the slot and baud table indices. Every recorded
vector replays exactly.

## D60. ESC telemetry over the serial line (2026-10-11)

`Adaflight.ESC_Sensor` polls each motor in turn for the ten-byte telemetry frame. After a boot delay
of five seconds it requests the next motor, then decodes the reply once complete and checks it with
the eight-bit checksum over its first nine bytes. A bad checksum, or a hundred milliseconds without
a complete frame, ages the reading instead. The request itself is the caller's, so the unit reports
it and the motor it is for. The byte receiver keeps bytes only while a frame is in flight.

The readings hold the temperature, voltage, current, consumption, and electrical rate of each motor
with the age of the reading. The combined reading takes the oldest age, the highest temperature, the
average voltage and rate, and the summed current and consumption, cached until a reading changes.
The reference counts timeouts and checksum errors only inside its debug mode (finding F52), so the
port keeps no such counters. An outside source may replace a motor's reading or age it. Current and
consumption from such a source are bounded by a predicate so the sums over every motor fit, which
the serial frames' sixteen-bit values always do. The same predicate keeps the frame fill within the
frame size. Every recorded vector replays exactly.

## D61. SmartPort telemetry stream (2026-10-11)

`Adaflight.SmartPort_Telemetry` answers the receiver's polls on the half-duplex line. The value
table is built once from the sensors enabled in the configuration and the sensors present:

- mode words and core temperature
- battery and cell voltages
- current, with the fuel and the charge used
- heading, attitude, and accelerations
- altitude and climb rate
- with the GPS feature: ground speed, the two coordinate words, home distance, and GPS altitude

The ESC table holds the voltage, current, rate, and temperature ids that the configuration leaves to
the ESCs. Received bytes are reassembled through the start byte, the sensor id, and the escaped
payload with its checksum. A poll of this sensor's id as the last byte waiting clears the stream to
send. The bytes are read up to the first complete payload and the count taken is returned, so the
caller offers the rest again.

Once cleared, the next value goes out within the attempts the caller allows, which stand for the
reference's time budget of one millisecond. The table position moves on each attempt, and every
seventh value comes from the ESC table over each motor and the combined reading in turn. A value
with nothing to report passes its turn: a GPS value without a fix, an ESC value without a reading,
the mode word without a source. The frame is the frame id, the value id, the value, and the FrSky
checksum, each byte escaped when it is one of the two reserved bytes. The table positions count in a
byte, and a read past the table gives no value (finding F75). The table holds all twenty-one ids a
configuration can enable (finding F76). The MSP tunnel over the stream waits for the MSP serial
port. Every recorded vector replays exactly.

## D62. RunCam device protocol (2026-10-11)

The RunCam device unit contains the device protocol and camera control. A packet is a header,
command, data, and a checksum over all of them. The older cameras take a five-byte command with a
high-first checksum, computed with the tail in the checksum's place. At the start the unit sends the
device information request with the configured retries and interval, and after its last failure it
sends the older command once. One request at a time waits for its reply. The reply is taken from its
header byte to the expected length, checked, parsed, and dropped on success. At the timeout the
request is sent again while retries remain, and otherwise parsed as timed out. The camera's own
requests are parsed from the bytes a waiting request leaves. The attitude request is answered with
roll, pitch, and the yaw in whole degrees as little-endian words.

The three camera buttons fire once per switch activation. The wifi and mode buttons are held while
armed, or while arming is blocked by a runaway takeoff or a crash. The five-key cable works from the
sticks. Yaw high at centred throttle, roll, and pitch opens the connection, and yaw low closes it.
In the menu, roll and pitch give the keys and yaw high the set key. The release comes when the three
sticks return to centre, each with the beep the connection result asks for. The bytes a call does
not take are offered again, as the reference's port keeps them, and a request flushes them all
before it is sent, whether or not the one slot is free.

An unsupported request returns the parser to the header state, and so does the 200 ms reset. The
reference parks the parser in a state no case handles after an unsupported request and resets it
to the command state after the gap, so one unsupported request stops its request parsing until a
gap falls between a header and its command byte (finding F77). Two behaviours of the reference are
kept. The older-protocol request after a failed device information request never waits for its
reply (finding F78). A reply
that fails its checksum leaves the request waiting with its count full, where the unit stops storing
at the buffer's end and the reference writes past it (finding F79). With the port closed a call does
nothing, since the task never runs then. The unit is SPARK for the reply and request buffers, whose
indexes the reference does not bound.

## D63. FrSky hub telemetry (2026-10-11)

The FrSky hub unit contains the hub encoder. Every 125 ms, by the signed difference of the
microsecond clock, a cycle counted one to forty sends its frames, then the tail. A frame is a
header, an id, and a sixteen-bit value low byte first, with its two bytes stuffed.

- Every cycle sends the three accelerations in thousandths of a g, truncated to whole g first, and
  the climb rate.
- Every fourth cycle sends the altitude in metres and centimetres, zero for the first five seconds
  after boot, and the heading in whole degrees with a zero fraction.
- Every eighth cycle sends the ESC temperature, the rate in tens of revolutions per minute, the cell
  voltage with its cell number in two-millivolt steps, and the pack voltage in tenths or in fifths.
  It also sends the current, the fuel as the percentage left or the charge used, the ground speed in
  knots with a fix, and the GPS altitude. The satellite count, or the dilution while it is poor,
  goes out on the first half of every sixteen cycles in the configured unit. The position goes out
  in degrees and minutes with the hemisphere letters: the configured position until the first fix
  and the last known one after it, or one degree each with a compass and no GPS.
- Every fortieth cycle sends the minutes and the seconds of the uptime.

Each value narrows to the frame's sixteen bits. The configured no-fix coordinates are bounded to
eighteen thousand hundredths, so their conversion stays within the reference's defined range. The
sensors present and the configuration are settings of the stream. The cell voltage's cell counter
and the fix memory are its state. The ESC branches of the temperature and the rate are the ones the
default build compiles. The unit is SPARK for the output buffer and the narrowing arithmetic.

## D64. iBus telemetry sensors (2026-10-11)

The iBus telemetry unit contains the sensor protocol and its port handler. The receiver polls the
half-duplex line with four byte requests: a length, a command with the address in its low nibble,
and a two byte checksum. The link answers from a table of fifteen sensor ids. The first nonzero
address polled becomes the base of the table, and an address below the base, past the table or at an
empty entry gets no answer. The three commands answer the discovery with the address, the type with
the id and its length, and the measurement with the value: two bytes for most sensors, four for the
pressure, the positions and the altitudes, and the parts in turn for the three combined sensors.

Each value has its own conversion and narrowing. The temperature is in tenths offset by forty
degrees, from the barometer when present, else from the gyro. The throttle is zero with the motors
stopped, or the capacity as the rate. In the mode code the last matching flag decides. The
accelerations are in thousandths of a g, and the attitude is in hundredths of a degree, wrapping
past the sixteen bits. The GPS values are zero without the sensor or a fix, and the status always
contains the fix type and the satellites. The pressure contains the temperature in its high bits.

The bytes received pass a four byte window, and the echo of each answer is skipped by its length. A
request is seen when the window's length byte is two to four and the checksum over that many bytes
less two matches its last two bytes. The reference sums past the window for other length bytes
(finding F80), so those never match here. Every byte offered is taken, and an answer that would not
fit the output is dropped, which no recorded vector reaches. The unit is SPARK for the window, the
frame and the output indexes.

## D65. HoTT telemetry link (2026-10-11)

The HoTT unit contains the binary mode. The receiver asks on the single wire with two bytes, a
request id and a sensor address. The link answers the electric air module address with its message,
and the GPS module address with its message when a GPS is present. It sends a byte per call with
three milliseconds between bytes and the running sum after the last. The line turns to send on the
call after the request, and back to receive, with every byte waiting flushed, on the call after the
sum. A request is seen when exactly two bytes wait on two checks four milliseconds apart, and more
than two are flushed. The count is read as a byte, so a receive buffer of exactly 256 bytes reads as
empty and stays until more bytes arrive (finding F81).

The two messages are prepared from the sensors five times a second, while one may be on its way out,
so the bytes after a preparation contain the new values. The voltage goes into the main and first
battery fields. The alarm and its inverse flag come once per configured interval from the voltage or
the charge state. The current and the charge used are in tenths, the altitude is offset by five
hundred metres, the climb rate by thirty thousand and the three-second rate by one hundred and
twenty. The satellites and the fix character are always sent. With a fix the message adds the
position in degrees and minutes with hundredths of a second, the speed in kilometres per hour, the
home distance, the altitude bounded to the field, and the home direction in two-degree steps. Each
field narrows to its byte width. The text mode waits for the menu system. The unit is SPARK for the
message indexes and the send position.

## D66. Ghost telemetry frames (2026-10-11)

The Ghost telemetry unit contains the frame scheduler and encoders. A schedule of up to four frame
types is built once from the configuration and the sensors present: the battery frame when a voltage
or current meter is configured and reported, the two GPS frames with the GPS feature and their
sensors reported, and the heading and altitude frame with a compass or a barometer reported. One
frame then goes out per cycle of a tenth of a second divided by the schedule length, in order. Each
frame is the receiver address, the length, the type, ten payload bytes and the checksum over the
type and payload, handed to the receiver driver to send.

The battery frame contains the pack or cell voltage, the current and the charge used in tens, and
the disarmed flag. The first GPS frame contains the position and the altitude in metres, zero
without a fix. The second contains the speed, course, satellites, the home distance and direction in
tens, and the fix flags. The last contains the heading and the altitude in metres bounded to the
field with their flags. Each value narrows to the width of its field.

The climb rate of the last frame stays zero and its flag clear, as the reference tests a sensor bit
no sensor sets (finding F82). An empty schedule sends nothing, where the reference divides by its
length (finding F83). The unit is SPARK for the frame and schedule indexes.

## D67. Race transponder codings (2026-10-11)

The transponder unit contains the three infrared codings and the repeat schedule. Each coding turns
the configured code into the toggles a timer plays out on the carrier. ILAP sends six bytes, each a
pulsed start bit, its eight bits low first and a silent stop bit, with eleven toggles and a gap per
bit, 720 toggles in all. Arcitimer sends nine bytes, each bit low first as four toggles, in a buffer
of 620 with silence after the 288 of the bits. ERLT sends the inverted code's six low bits high
first between two start bits and a parity bit, a one as twenty-five cycles and a zero as ten, pulsed
on the odd bits, with a silent cycle after the parity, so its length follows the code. The pulse
value of the ERLT coding passes through a byte, as the reference's helper narrows it (finding F84).

The schedule starts a transmission when the hardware is ready and the signed difference to the next
time is not negative. It sets the next time from the coding's delay and a tenth of its jitter times
the next step of a fixed table of fifteen. No coding means no transmission. The timer period and the
hardware are the target's. The unit is SPARK for the toggle buffer indexes, which the reference
drives through a static offset.

## D68. SRXL telemetry frames (2026-10-11)

The SRXL telemetry unit contains the frame schedule and encoders for the Spektrum receivers. Three
slots run in turn: the link quality frame and the rate frame always, then one user frame cycling
over the flight pack current, the GPS status, the GPS location and the text generator line. The text
line takes the slot whatever the cycle while the menu is on this display. Each frame is two address
bytes, a length, sixteen payload bytes and the CRC-16 over the payload, handed to the receiver
driver when its buffer is empty. A slot whose frame has nothing to say passes in silence.

The rate frame contains the period between pulses from the ESC rate, or the DShot average when the
ESC gives none, bounded to the shown range, the pack or cell voltage and the core temperature in
Fahrenheit, big-endian. The flight pack frame goes when the current or the charge changed or two
seconds passed. The GPS frames go with the GPS feature, a fix and four satellites. Their values are
binary coded decimals, each narrowed to its field, and the low altitude field goes through a
sixteen-bit integer before its digits (finding F85). The text frame sends the next line not yet
sent, or the next in turn when all were, and the menu system's characters mark their line through
`Put_Char`. The video transmitter frame follows the VTX control branch, where the schedule grows by
one user frame. The unit is SPARK for the frame and text indexes and the narrowing arithmetic.

## D69. FrSky OSD device link (2026-10-11)

The FrSky OSD unit contains the device link. The drawing, transform, context, grid and font commands
are queued into a buffer of 192 bytes. The queue is flushed when a command would not fit, on a
commit, on a request that waits and on the information request. Each flush is one frame of the
preamble, the length as a varint, the commands and the checksum over the length and commands. A
commit of a transaction with nothing drawn is dropped with its beginning. The coordinates are packed
two to three bytes of twelve bits each, and the transform values go as the bits of the floats.

The bytes received pass the frame states with the varint length. A complete response is handled once
per call, and the bytes after it are dropped until then. The information response sets the version
and the grid, the first one clearing the screen and resetting the drawing. The font read fills the
character being read. The information request goes out once a second for the life of the link, as
the field meant to pace it after the device answered is never set (finding F86).

The two font exchanges wait for their reply in the reference. The unit takes the bytes waiting
before the request, handling a complete response among them and dropping a partial one. The request
then goes out with whatever was queued, and the bytes arriving during the wait are all taken, the
first complete response deciding the outcome. The caller accounts for the time the wait took. The
strings are bounded to the payload the reference writes them into, which a longer string would
overrun (finding F87). The unit is SPARK for the queue, frame and payload indexes.

## D70. LED strip (2026-10-11)

The LED strip unit contains the strip. The layout is derived once from the configuration: the LEDs
in use up to the first empty one, the ring and scanner counts, the ring sequence length, the grid
halves for the indicator, the overlay timers nothing uses, and the bar lengths.

The status profile paints every LED from its function: a palette color blended toward its neighbours
by the auxiliary channel, the mode color of its first direction, the arm state, the battery, signal,
GPS and altitude hues offset by the value, and the bars. It then runs the overlay layers on their
own timers in a fixed order: rainbow, blink, scanner, ring, indicator, GPS, battery, signal,
warning. Each layer repaints its LEDs every call and steps its state when its time came, and a timer
more than five seconds behind restarts. The race and beacon profiles paint the whole strip one
color. The race color flashes for the beeper switch or failsafe, and the beacon follows its period.
The strip is repainted on a change or every second. The driver update scales each LED by the
brightness and converts it to red, green and blue, every LED after a change of count and the LEDs in
use otherwise.

The configuration text of a LED and of a color parses chunk by chunk. A chunk of more than ten
characters fails, and so does a color component over its limit or below zero. Two reference
behaviours are kept. A function mask also matches the functions whose numbers hold its bits, so the
battery, signal and GPS layers repaint the bar and ring LEDs too (finding F88). The ring timer's
rate reaches zero for a throttle of 861 to 880 while armed, where the reference divides by it and
the unit adds nothing (finding F89). The video transmitter layer and the race color that follows the
transmitter frequency wait for the VTX branches, and the layer leaves its timer alone. The unit is
SPARK for the LED, palette and timer indexes and the hue arithmetic.

## D71. Rangefinder readings (2026-10-11)

The rangefinder unit contains the processing of the distance a driver reports: the reading's time
and the interval between readings, and a median of the last five readings in range, with the reading
itself until five were seen. The pseudo signal ratio is the sum of the last five squared changes
over ten, each bounded. The dynamic ceiling on the usable distance rises to three quarters of the
reading while the ratio stays quiet and freezes once the ratio crosses six hundred. The altitude
comes from the reading and the cosine of the craft's tilt, out of range past the sensor's extended
cone.

The surface altitude is usable with positive readings, a quiet ratio and, once the ceiling froze, a
reading under it. The sensor is healthy within half a second of a valid reading. The detection, the
drivers and the legacy bounds the altitude estimator reads come with the target, and the bounds are
computed here from the range and the tilt limit. The unit is SPARK for the sample windows and the
integer bounds.

## D72. Optical flow readings (2026-10-11)

The optical flow unit contains the sensor processing without its drivers. Each read of the driver
sets the quality, and a sample whose time stamp moved is turned into the craft frame by the cosine
and sine of the mounting rotation, with the x axis flipped when configured. One filtered gyro
reading is kept per sample in a ring of sixteen with its time stamp. The slot whose age is nearest
the driver's gyro delay supplies the roll and pitch rates, which are subtracted from the flow after
their conversion to radians per second. An axis whose matched gyro rate exceeds two hundred degrees
per second keeps its previous processed rate and loses its validity, so a consumer can skip the axis
instead of reading a zero as rest. A slot still at time zero is passed over, as is a sample stamped
zero. The health check compares the clock with the last sample through the wrapping difference.

The cosine and sine of the configured rotation come from the platform's trigonometry at init,
because the reference computes them once with the C library and the unit keeps no transcendental
code. One guard covers undefined behavior in the reference: the age error of a slot is computed in
64 bits, where the reference subtracts the delay from a 32-bit age that can be near its minimum
after a long silence (finding F90). No recorded vector reaches the guard.

## D73. Pitot airspeed (2026-10-11)

The pitot unit contains the airspeed task without its drivers. The platform reads the I2C sensor and
the latest DroneCAN frame each pass, and the unit picks the source: the configured one alone or, for
the default, the I2C sensor first and the DroneCAN frame when it is less than half a second old. The
pressure of the source that answered goes through a first-order low-pass at five hertz over the
twenty hertz task period. A source that takes over resets the filter and, while disarmed and not yet
zeroed, starts its calibration: twenty filtered samples averaged into the source's zero, abandoned
by arming. The zero-corrected pressure gives the indicated airspeed as the square root of twice the
pressure over the sea-level air density, signed by the flow direction and in centimetres per second.
A pass without a sample keeps the last values for one second, then drops the source and zeroes the
pressure and the airspeed.

Two bounds hold the proof without touching a value in range. The accumulation of the calibration is
held within twenty signal bounds, the most twenty samples can sum to. The root of the pressure is
capped at one million before the multiplication to centimetres, a bound no pressure within the
signal bound reaches. The time comparisons use the wrapping difference. No recorded vector reaches a
guard.

## D74. Real-time clock calendar (2026-10-11)

The clock unit contains the calendar without its time source. The platform supplies the millisecond
uptime, and the clock keeps the set time less that uptime, zero while nothing was set. A date
becomes milliseconds since 1970 through the four-year leap cycle, the year from 2000, a table of
days to the start of each month, and the hours, minutes and seconds, in 32-bit unsigned arithmetic
that wraps and lands in a signed second count. The reverse conversion divides the seconds out and
walks the table from the end. A time zone in minutes moves a date through the time and back.

The text of a date is the ISO 8601 form with the zone, or the short form, each field padded with
zeros to its width. A date outside the valid ranges shows as the first of January of the year zero.
A split finds the letter T that separates the date from the time. The time with the zone applied is
stored as two 32-bit words across a reset and read back when either word is set.

The conversions count seconds in 64 bits, so a date past January 2038 and a time past January 2068
convert exactly, and a set clock is marked set, so a time equal to the uptime stays. The reference's
32-bit conversions wrap at those dates (findings F91 and F104) and its zero test for a set clock
loses that time (F95). A negative zone under an hour prints as positive (F93). Two guards cover the
reference's undefined behavior and its one buffer. The zone offset is applied only to a month that
indexes the day table, the default date showing otherwise (F92), and a stored time outside the
settable span of two to the sixty-second milliseconds is rejected on read. The five-digit year the
text can contain fits the 30-character result (F94). No recorded vector reaches a guard.

## D75. Internal ADC channels (2026-10-11)

The internal ADC unit contains the averaging and compensation without the conversions. The platform
reads the band gap reference and the temperature sensor and hands the two 12-bit values to each
pass. The pass runs each through a moving average of eight, with the sum kept as the sum of the
window by a record predicate. It computes the analog supply in millivolts as the chip's calibration
word times 3300 over the averaged reference. The core temperature is the averaged sensor reading
scaled by the supply over 3300, less the calibration point at thirty degrees, times the slope in
thousandths of a degree, rounded to degrees, offset by thirty and narrowed to sixteen bits. The nine
conversions at startup are nine passes driven by the platform.

The calibration word, the point and the slope are bounded to the values the chips store, so the
products stay in 32 bits where the reference would overflow (finding F96). One guard covers the
reference's division: an averaged reference reading of zero gives a supply of zero, the quotient the
target's core produces (F97). No recorded vector reaches the guard.

## D76. Flight statistics (2026-10-11)

The flight statistics unit contains the counters without the configuration store, the beeper and the
scheduler. An arm records the millisecond clock and the distance flown so far. A disarm, when the
minimum armed time is not off and the armed time reaches it, adds a flight, the armed seconds and
the metres flown since the arm to the totals and records the battery draw. It then asks for the save
after half a second while a save is owed.

The save, when the platform runs it, does nothing while armed. While disarmed it writes the
configuration and repeats the disarm beep when the craft lies still under the movement limit, or
when the limit is zero, and asks for another pass otherwise. In either case it clears the owed save.
A configuration change waiting for its own save leaves the statistics to it. The seconds and the
metres wrap in unsigned arithmetic, and a negative battery draw lands in the unsigned total. No
guard was needed.

## D77. Wing launch (2026-10-12)

The wing launch unit contains the launch state machine without its sensors, receiver and modes,
which the platform hands to each pass as inputs. An arm latches the launch when the switch is on,
the airframe is a fixed wing with an accelerometer and it lies at rest: specific force within 0.15 g
of one g, every gyro rate under 25 degrees per second, a vertical speed under a metre per second
when an altitude exists, and a ground speed under half a metre per second when the fix has five
satellites.

The pass then walks the states in order. The throttle wait restarts its clock while the throttle is
low and leaves after the idle delay. The idle ramp takes a second and a half for the throttle and
the climb angle. The detection wait holds the idle throttle and the climb angle and needs a bungee
pull, a swing or a run to hold for the detection time, and a frame without one seeds the clock
again. The motor delay follows, then the spin-up ramp from the idle to the launch throttle, and the
climb-out until the altitude, the timeout or the sticks. The finish cross-fades the handover factor
to the pilot, and any stick input ends it early.

A bungee pull is the forward specific force past the threshold while level within the tilt gate. A
swing is the tangential speed about the thrower's shoulder, the sideways force times gravity over
the yaw rate in radians, past the velocity threshold with a forward force. A run is the ground speed
past the same threshold with a forward force and a fix of five satellites.

From the motor delay on, a bank past the abort angle either way or a dive past it, held for a tenth
of a second, aborts. The sticks abort past the deadband once the minimum time from detection has
run. The mode going off or the failsafe aborts at once, as does the switch. Every exit hands the
aircraft straight back with a handover of one. While the launch owns the aircraft the pass writes
the angle targets the level controller reads: zero roll and the climb angle as a nose-down pitch.
The targets live with the caller and keep their values otherwise, where the reference keeps them in
globals. The times compare through the wrapping difference. No guard was needed.

## D78. Navigation trail (2026-10-12)

The navigation trail unit contains the breadcrumb recorder for the OSD map without its GPS. The
platform hands each poll the position east and north of home in centimetres, which the reference
computes inside the recorder from the home and current coordinates. The poll runs at ten hertz on
the wrapping clock, starts the line over on the arm edge before the cycle's position can land, and
takes a position only while armed with a fix and a home.

A position becomes whole metres east and north, rounded to the nearest and held in sixteen bits
before the distance gate, so a glitch past the range leaves the stored point and the gate's
arithmetic agreeing. The first point is stored, and a later one when its distance from the last
reaches the spacing, compared as squares in 64 bits. A full store of 240 points keeps every second
point and doubles the spacing, up to five kilometres, before the point goes in. The stored points
live in the record, and the harness checks their count, the spacing, the last point and a hash over
every point. No guard was needed.

## D79. GPS frame decoders (2026-10-11)

`Adaflight.GPS_Frames` decodes the two serial protocols of a GPS module into one solution record:
the position, altitude, dilution, accuracy, velocity, speeds, satellite count, time of week and
calendar time, with the fix flags, the satellite list, and the request to set the clock while it has
no time.

The NMEA decoder gathers a sentence field by field into a fifteen character buffer, identifies GGA,
RMC, GSV and GSA sentences from the three letters after the talker id, and parses each field as it
ends. It writes the gathered values to the solution once the parity after the star matches. The fix
state follows the GGA quality field once the parity matches, before the values are written. The
reference sets it as the field arrives, before the parity check, so a corrupted sentence or line
noise sets or clears the fix (finding F53, D6).

The UBX decoder walks the preamble, class, id, length, payload and the two Fletcher checksums. It
keeps up to 392 payload bytes, restarts on a declared length past 776 or on a bad checksum, and
interprets a complete message by class and id: NAV-PVT, NAV-POSLLH, NAV-STATUS, NAV-DOP, NAV-SOL,
NAV-VELNED, NAV-SAT, NAV-SVINFO, MON-VER and the acknowledgements. A message is read from the
payload buffer at its field offsets whatever length arrived, so a short message takes the stale
bytes of earlier ones from the shared buffer. The configuration reply that makes the module transmit
(CFG-GNSS) belongs with the autoconfiguration and is passed over.

Some conversions narrow: the speed in knots times 5144 over 1000 in thirty-two bits, and the
saturating hexadecimal read of the hardware version. The clock request's millisecond field is the
time's hundredths times ten. The reference masks the time with 100 in place of the remainder, so its
field reads 0 or 1000 (finding F54). The unit departs from the reference only where its behaviour is
undefined: the field cut that would land outside the buffer is dropped (F55), a satellite number of
zero skips the list (F56), and a month outside the calendar counts thirty-one days (F57). The oracle
feeds bursts of sentences and messages with cut frames, bad checksums, stale buffers and runs of
garbage, built with unsigned characters as the targets are, and every recorded vector replays
exactly.

## D80. GPS link (2026-10-11)

`Adaflight.UBX_Config` builds the configuration messages for a u-blox module: the frame around a
class, an id and a payload with the two running checksum bytes, the polls, the message rates, the
navigation rate, the dynamic model with the fixed defaults of the other navigation settings, the
autonomous assistance, the full power mode, the SBAS selection with the scan mask of the selected
system and the NMEA output disable. Each comes in the legacy form and, from the ninth generation,
the keyed value form, and the GNSS configuration goes back from the module's own reply with SBAS and
Galileo set as selected. A frame contains the id its acknowledgement names and whether the sender
counts it acknowledged at once: the legacy navigation rate and every keyed message but the
navigation rate are. The GNSS message holds at most seven blocks (finding F61).

`Adaflight.GPS_Link` runs the connection over a serial port the caller owns. The caller hands over
the bytes received since the last call and carries out what the call asks for: the bytes to send,
the port rate to set, the indicator toggle, the ready beep, the clock to set and the task rate, fast
while bytes arrive and normal one call after the last.

The detection polls the version three times, 330 ms apart, at each rate of a sweep that starts at
the configured rate, moves through the faster rates and wraps to 9600 upward. After two passes a
step waits 30 s. A version reply sends the module's own rate change sentence, the port follows a
second later, and the configuration starts after another second. It sends one step every 110 ms
while no acknowledgement is awaited, each step moving on at the acknowledgement or 150 ms after the
message, and a negative acknowledgement of the first step restarts the configuration. The steps slow
the navigation rate, turn the six NMEA sentences off, set the acquisition model, the assistance, the
SBAS selection and the power mode where the generation has them, pick the solution messages of the
generation (PVT from the seventh, the five legacy messages below), ask for the satellite information
at a fifth of the rate, set the configured rate and poll the GNSS configuration when SBAS is off or
Galileo is on. The reply is answered as it is received.

Receiving, a fix switches the module to the flight model once, and 2.5 s without a solution counts a
timeout, drops the fix and the satellite count and restarts the detection. An NMEA module keeps its
own rate: the port is set to the configured rate and the custom commands go out one every half
second, the link turning to receiving after the last. The reference leaves for receiving after the
first command and sends the next one per connection (finding F63). The ground link source takes
offered solutions and starts initialized. After a loss it leaves the detection state at the next
offered solution, where the reference stays in that state for good (finding F62, D6).

Every solution with a fix counts the stamp, sets the interval and the frequency of the solutions,
the distance and the direction home and, armed, the distance flown above 15 cm/s. The home position
is set on request from a fix with at least the minimum satellites, unless it is kept once set, and
the request also turns the satellite information off on a u-blox module. Disarmed, the home fix
clears each call unless kept, and the ready beep sounds once at a fix with enough satellites. The
link's clock starts at zero, so the first version poll is counted against zero (finding F64). The
distance over the local flat earth and the bearing use the maths approximations and the longitude
difference taken in 64 bits and folded across the antimeridian, where the reference's 32-bit
subtraction overflows and puts the east distance thousands of kilometres off (finding F58, D6), and
the ENU distance vector stays with the position estimate. The task time budget that stops the byte
loop belongs to the caller, which decides how many bytes a call takes. Every recorded vector
replays exactly.

## D81. Horizontal position estimate from the GPS (2026-10-11)

`Adaflight.Position_Estimator` takes over the altitude estimator of D33 and adds the east and north
filters of the earth frame. The horizontal axes run while armed and asked for, by the position hold
or rescue mode or by a GPS fix under a horizontal source setting that allows the GPS. Starting them
resets the two filters and takes the origin from the fix at hand, or from the first fix after. The
linear acceleration comes from the north, west and up rows of the attitude rotation over the scaled
counts, east being the negated west row. It corrects and predicts the horizontal filters while a
measurement is less than two seconds old, and otherwise discards their state and keeps the origin.

A fix is fused when its solution count has advanced or within the hold interval its rate gives, the
velocity before the position, each with a noise scaled by the reported accuracy between one and ten
times its base. The east and north distances from the origin follow the longitude difference, taken
in 64 bits and folded across the antimeridian where the reference's 32-bit subtraction overflows
before its correction (finding F58, D6), scaled by the cosine of the home latitude and by the
centimetres per unit, that constant rounded at each step as the C forms it.

Under an altitude source that allows the GPS, the fix also corrects the vertical filter, velocity
then position against the first GPS altitude, and the barometer then corrects position alone, since
the GPS measures the vertical velocity. Below the default barometer preference the fix anchors a
slow calibration of the barometer offset toward the offset the estimate implies, at a time constant
of two hundred seconds times the accuracy scale, while armed and both fed in the task.

The validity of each plane needs a measurement within two seconds, the trust falls with the mean
position variance, and each task raises the update events the altitude and position hold tasks take
once. A heading is required while the GPS is the horizontal source. The altitude hold now takes its
centimetre type from the position filter. Distances and altitudes beyond the filter's state bound of
167 km are held at it, and the oracle keeps the fixes within range. Four of its runs start within a
metre of the antimeridian and cross it. Every recorded vector replays exactly, the earlier altitude
vectors unchanged.

## D82. Position hold with the autopilot's horizontal control (2026-10-11)

`Adaflight.Position_Control` is the autopilot's horizontal controller and `Adaflight.Position_Hold`
the mode around it. The hold engages from its flight mode or a rescue: the controller resets,
captures the hold point, enters braking against the speed carried in, and asks the estimator for the
horizontal axes. It releases with the sticks cleared and the yaw controller stood down. Each task
reads the sticks against the deadband, unless a failsafe or a rescue holds them. It checks the
sensors for a valid horizontal estimate and, where the estimator requires one, a heading, with a
heading recovery standing in. Sensors returning after a dropout re-anchor the hold where the craft
is. The controller measures its interval between a quarter and four times the nominal and retunes
the feedforward filters when it moves by a twentieth. A missing estimate, an abort or a forced level
park fail the hold with the errors dropped, and a heading recovery levels the roll and pitches
forward instead. The ground speed and its half-second trend feed the braking stop and the fence.

The mode follows the rescue, the sticks and the braking. A rescue flies the velocity the rescue
sets, the target walking at it with the fence on the target and the integral accumulating. The
sticks fly their velocity, turned from the body frame by the heading, with the distance error
integrated from the velocity error while the integral freezes. Braking drags the target to the craft
with the integral frozen until the speed falls under the configured fraction of the entry speed, the
velocity reverses along the entry direction, or 1.2 seconds pass, then captures the point. The
settled hold anchors to the point and integrates against the wind, with the target velocity zero
outside a rescue.

The fence is the greater of twenty metres and twice the ground speed. A settled hold beyond it keeps
the previous lean until a second has passed, then spends the one re-anchor a clean ten seconds earns
back, or levels out and fails. A brake beyond it moves the fence ahead of a craft still slowing and
runs the same clock otherwise.

The law per axis takes the error and its integral, each within twenty metres, the proportional and
integral terms, damping on the velocity with a boost of a half per thousand centimetres a second
less the drag, the acceleration term, and the feedforward from the target velocity through the same
boosted gain and from its rate of change through its own, smoothed by a third order filter. The sum
turns into the body frame by the heading and is held to the lean limit, and a saturated lean stops
the virtual error from winding up.

The yaw controller steers to the rescue's heading or holds the heading captured at engagement or
where the pilot last left the yaw stick, ramped in over a second, held to the configured and any
external rate limit, and reversed with the yaw setting. It stands down while disarmed, without a
mode that wants it, or without a trusted heading, and the heading hold task drives it alone outside
a hold or a rescue. The navigation modes, their yaw modes and the velocity buildup clamp are in
D145, and there is no optical flow. A feedforward term beyond the signal bound and a target velocity
beyond 2 to the 26 centimetres per second are held at those bounds. Every recorded vector replays
exactly.

## D83. GPS rescue over the autopilot's controllers (2026-10-11)

`Adaflight.GPS_Rescue` is the rescue of the default target build, where the flight plan is off and
the rescue flies its own phases. Each task reads the sensors: the fix count, the heading and its
validity, the GPS health, the altitude, the estimate while valid, the distance and speed from home,
the bearing home from the C library's arctangent past the twenty centimetre acceptance radius, and
the heading error. It then decides availability, runs the sanity checks, then the phase.

The initialization fixes the return altitude from the mode, or a climb above the current altitude
close to home, holds the heading and resets the ramps and the altitude controller. The climb runs at
the ascend or descend rate until the return altitude is crossed. The turn toward home follows, with
the yaw target ramped in over a second, or a forward pitch while the heading is unknown, until the
error is within thirty degrees. The flight home at the ground speed, slowed within twice the descent
distance and ramped in at the start, hands the horizontal controller a velocity toward home and the
yaw target. The descent sets a rate from three times the setting at fifty metres to six tenths at
ten, then the landing holds the velocity at zero and the emergency descent aborts the horizontal
control.

The sanity checks disarm on a start within the acceptance radius below the landing altitude or on a
crash flip, and answer a failure by the setting with an emergency descent when an altitude is
available. Once a second they record the GPS health, the satellite count over fifteen seconds, and
the phase's own progress: the altitude change against the target change, the velocity home against a
fifth of the target speed, and the seconds spent turning, pitching forward, descending or landing.
The do-nothing phase is kept though the sanity check disarms first under its condition (finding
F59). Headings in decidegrees reach the rescue as tenths of a degree in floating point. The
reference divides them as integers first, so it steers in whole degrees (finding F60).

The autopilot's altitude controller moves from the altitude hold into `Adaflight.Altitude_Control`,
which the hold and the rescue drive with their own targets. The caller owns the controller state and
the horizontal controller state, as the autopilot shares them, and passes both in. A target altitude
change below a sixteen-millionth of a centimetre counts as none for the progress ratio, which the
reference divides by. Every recorded vector replays exactly, the earlier altitude hold vectors
unchanged.

## D84. Video transmitter table and the SmartAudio driver (2026-10-11)

`Adaflight.VTX_Table` contains up to eight bands of eight channels with their frequencies, names and
letters, the factory band flags, and up to eight power levels with their values and labels, cleared
to numbered defaults. It answers the lookups: the frequency of a band and channel, the band and
channel of a frequency searched from the last band down so a frequency in two bands names the later
one, and the value of a power index.

`Adaflight.SmartAudio` drives a SmartAudio transmitter over one half-duplex serial line the caller
owns. The caller hands in the bytes received and carries out the bytes and the line rate a call asks
for. A request builds its frame (the two preamble bytes, the command code, the length, the payload
and the checksum over the whole frame) and queues it, five deep, each queued frame with its own
bytes. The reference queues a pointer to one static buffer per command kind, so a later request of
the same kind rewrites an earlier one still queued and the earlier goes out with the later's bytes
(finding F65). A call sends one
frame: the outstanding command again 120 ms after its last transmission, else the next queued frame,
else a settings poll while a command went out within the last second and 150 ms have passed since
the last transmission. A disabled control drops the frame and clears the outstanding command.

Received bytes are reassembled through the preamble, the code, a length up to nineteen, the payload
and the checksum over the code, the length and the payload. The echo of a command fails that check
and is passed over by its odd code. A response clears the outstanding command by its code, or by a
settings code of a later version, and counts an out-of-order reply otherwise. The settings response
gives the version from its code, the channel, the mode, the frequency, the boot flag while in pit
mode, the power as the table index of the reported value, and the dBm levels of a 2.1 device. The
line rate moves one step of 50 between 4800 and 4950 when fewer than seven frames in ten are
answered. The start polls the settings, then asks a version 2 device for its pit mode frequency.

Band and channel are set through the table as the device numbers them, the power by the table value
with the dBm flag on a 2.1 device, the pit mode by the mode flags or, on a 2.1 device not booting
into pit mode, by a zero dBm power or a clearing mode, and the frequency within 5000 to 5999 MHz,
through a neighbouring frequency when the device already holds it in channel mode. The getters give
band and channel from the device's channel number split by the table's channel count (a zero count
divides as the hardware does, finding F66), the power index, the frequency from the table in channel
mode, the pit mode status, the power levels in dBm and in milliwatts through the C library's power
function, and the status bytes for the ground link. The table value sent as the power is its low
byte (finding F67). The menu hooks and the debug print of the reference are not ported. Every
recorded vector replays exactly.

## D85. Video transmitter settings update and control (2026-10-11)

`Adaflight.VTX` keeps the configured band, channel, power, frequency, pit mode frequency and low
power disarm policy as settings the caller holds, since the sticks, the switches and the receiver
change them at run time. The start makes the settings whole: the frequency of a configured band and
channel, and a pit mode frequency raised to the user range, each asking for the settings to be
stored.

Each task call outside the menu brings one parameter to the device. It moves through the power, the
band and channel (or the frequency when no band is configured), the pit mode and a confirmation of
the device state, and stops at the first parameter that needed a change. The device is then driven
while disarmed or while a change is pending. The settings in force put the pit mode frequency and
the default power in place at the pit mode switch, and the default power while disarmed outside
failsafe under the low power policy. The pit mode follows the switch's edges while disarmed and the
device reports its status, except when a pit mode frequency is configured.

The common layer over the one device selects a band and channel through the table. It sends the
device the band and channel of a factory band or the frequency of another, and reads band and
channel back from the device or, while a non-factory band is selected, from the device's frequency
through the table. The outputs keep their values when the device has none. A control word from the
Spektrum receiver, once per change, sets band and channel through the table, the power through the
device's steps and the pit mode at once, and stores the settings when they moved.

The stick commands step the band or channel within the table's counts, zero to the band or channel
count, and lock from the first arm on. The reference steps the bytes without bounds, so a band of
eight steps to nine and the table lookups find no frequency until the sticks step back (finding
F69). The switch conditions apply in order, the later one winning a field, band and channel
only until the first arm, the power always. The cycle commands step from the device's band, channel
and power and wrap within the table. The reference wraps the power when its index reaches the level
count, so the top level is never selected (finding F71). A Spektrum band past the five known ones is
not a table band (finding F70). Every recorded vector replays exactly.

## D86. Tramp driver and the device dispatch (2026-10-11)

`Adaflight.Tramp` drives a Tramp transmitter over one half-duplex serial line the caller owns, in
sixteen-byte frames: a start byte, a command, twelve payload bytes, a checksum over the command and
the payload, and a zero. The driver queries the device's limits every 200 ms until it answers, then
its settings, then watches the frequency, the power and the pit mode against the configuration. One
change goes out per 200 ms while retries remain, twenty from each configuration change, with the
frequency and the power held back under the device's race lock. A settings query follows each
change, every second otherwise, and a temperature query follows each settings reply.

The received bytes are read up to the first complete and valid reply, and the count taken is
returned, so the caller offers the rest again. A reply whose first word is zero is the echo of a
request and is passed over, so a device reporting zero limits never comes online (finding F73). A
temperature reply returns the driver to the settings monitor. The reference stays in the temperature
state until the request period passes, so its settings monitor waits one period after every
temperature reply (finding F74). The frequency is accepted within the device's limits, or the user
range while they are unknown. The power index is looked up in the table from the configured power,
unknown for a value outside it. The status contains the configured pit mode and the race lock.

`Adaflight.VTX` now drives either device. The device of the kind in use takes the frequency, the
power, the pit mode and the queries. A factory band goes to a SmartAudio device as band and channel
and to a Tramp device not at all, and the Spektrum power steps map to each device's indices. The
protocol library beside the Tramp driver is not ported (finding F72). Every recorded vector replays
exactly, the control vectors now over both devices.

## D87. LTM telemetry stream (2026-10-11)

`Adaflight.LTM_Telemetry` writes the light telemetry stream every 100 ms while enabled. Each cycle
sends an attitude frame with the pitch, roll and yaw in whole degrees. Alternate cycles then send a
status frame (the battery in millivolts, the charge drawn held to sixteen bits, the signal scaled
from its 1023 range to a byte, no airspeed, and the mode code with the armed and failsafe bits) or a
GPS frame (the position, the ground speed in metres per second, the altitude and the satellite count
with the fix type, left out while no GPS is present). Every tenth cycle adds an origin frame with
the home position, no home altitude, the display flag and the home fix.

Each frame is the two start bytes, the frame letter, the little-endian fields and the exclusive-or
of the fields. The mode code follows the precedence of the flags: passthrough, headfree, angle,
horizon, rescue, position hold, altitude hold, then rate. The port handling that enables the stream
belongs to the caller, which passes the enable. Every recorded vector replays exactly.

## D88. GPS lap timer (2026-10-12)

The GPS lap timer unit contains the gate timer over the fixes the platform hands it: the position,
the fix time in milliseconds, the cosine of the latitude the GPS link keeps for the local flat
earth, and the reset switch's state. Every fix first takes the distance and bearing to the gate
through the GPS link's flat-earth arithmetic (D80), the bearing through the fast arctangent in
hundredths of a degree.

While the gate is being set, the fix joins a running average of up to a thousand readings whose sums
live in the timer in 64 bits, bounded by the readings counted so the averages fit the gate. The
count moves before the sums so the bound holds at every step, an order the reference leaves
unobservable, and the quotient is held at the coordinate bound it never reaches. Ending the set
writes the averaged gate into the settings. The reset switch clears the gate from the settings and
every lap figure but keeps the circle tracking, which the reference keeps in file statics.

A lap is looked for while the timer is stopped or the shortest lap has passed since the last one.
Inside the gate's circle the closest approach and its time are tracked. Leaving the circle records a
lap from that time, moves the three previous laps along, keeps the best lap and the best sum of
three in a row, and restarts the timer from the closest approach. The lap count and the sums wrap in
sixteen and thirty-two bits. The harness replays 20000 steps over ten courses that loop through the
gate, hover at it while it is set, pulse the reset, cap the readings and wrap the millisecond clock,
and checks every figure, the file-level state and the settings' gate.

## D89. MSP box table (2026-10-12)

The MSP box unit contains the box table and its MSP services. The table names each flight and switch
mode box and gives it the permanent id that identifies it to the configurator for life, with lookups
by box and by permanent id. The box name serializer writes a user box's custom name of up to sixteen
characters when its first character is set and the table's name otherwise, each with the semicolon
separator, or nothing when they would not fit. The permanent id serializer writes the one byte or
nothing. The box reply walks the active boxes in their order and serializes the thirty-two of the
requested page, stopping at the first that does not fit.

A box's state is the arming flag for the arm box, the flight mode flag for the flight mode boxes,
the launch flight mode for the launch box on a wing build, and the switch state otherwise. The
status packing sets one bit per active box in the order they are counted, in two 32-bit words, and
returns the count. The active set from the build's features, sensors and settings stays with the
target, which hands it in as a mask. The harness replays 20000 steps of random active sets, flags,
switches, user names, pages and buffer sizes, half from a host build and half from a wing build, and
checks the packed words and count, every serialized byte of both replies and the lookup by permanent
id. No guard was needed.

## D90. Dispatch queue (2026-10-12)

The dispatch unit contains the delayed-call queue over target numbers up to a capacity of eight,
with the handlers left to the caller. The reference links entries that contain a function pointer,
and SPARK keeps the entry table and the order while the caller numbers its targets and runs each one
the queue hands back. An added target takes its due time from the clock plus the delay, which wraps
in unsigned arithmetic for a negative delay, and goes before the first entry not due earlier on the
wrapping clock difference. A target already queued stays where it is. A processing pass takes the
head while it is due, unlinks it first and hands it back, so the handler can queue it again, and the
caller loops until nothing is due.

The queue keeps its entries in an array by position rather than through pointers, with one slot per
target. The one guard refuses an addition at full capacity, which one entry per target never
reaches. `Adaflight.Dispatch_Targets` numbers the three calls the reference queues: the statistics
save, the MSP reboot, and the settings write and read. The harness replays 20000 operations over the
eight targets of adds with positive and negative delays, clock advances that wrap, enabling, and
processing passes whose handlers requeue themselves at random, checking the fired order with every
requeue, the queue's order, and each entry's due time and flag.

## D91. ExpressLRS receiver (2026-10-12)

The ExpressLRS receiver unit contains the SPI receiver over the hopping tables and link quality
counter (D54) and the telemetry link (D55). A packet from the radio is checked against its 14-bit
CRC seeded from the unique id, with the CRC's upper bits cleared from its first byte in place before
the check, so the payload copy contains the cleared byte. It is then decoded by type. A channel
packet is copied to the payload for the channel decode. A sync packet contains the rate, the switch
mode, the telemetry ratio and the model match that drive the connection. An MSP packet with the bind
command writes the unique id while binding, and any other MSP packet feeds the MSP receiver on a
connection, whose finished frame sets the model id or is handed to the target.

The telemetry slot builds the response from the link statistics or from the sender's next chunk,
counting the burst the rate and telemetry ratio allow, and the next frame the target offers starts
in the sender when it is idle. The timer's tick advances the nonce and the link quality window after
the phase lock update, the tock records its time for the lock, and each programs the next
half-period with the lock's frequency offset and phase shift. The receiver task runs the delayed
start, a pending initialization, a bind request, the connection states with the rate cycling while
disconnected, the configuration write-back and the link statistics reports. The radio, the timer
hardware, the bind button and the LEDs stay with the target, which reads the radio configuration,
the timer period, the start, power and save requests and the reports the unit records.

The receiver record keeps the receiver structure and the file-level state side by side under one
predicate that holds every rate within its band's table, so the 900 MHz bands' four rates and the
2.4 GHz band's six are never mixed. Initialization takes the time, which the reference reads from
the clock for the rate cycle. The telemetry frame comes in through the telemetry slot's parameters
where the reference calls out for it, and the sender keeps its own copy, as the reference's static
frame buffer is rewritten only while the sender is idle. The signal to noise mean holds its sample
count at 2 ** 24 - 1 (D6). The burst limit is computed in a wide count, reserves the link
statistics slot and is held at 255, so a 1000 Hz link with a 1:2 telemetry ratio sends 255 data
frames per link statistics frame. The reference's 8-bit limit wraps to zero there and the two
kinds alternate (finding F99).

The harness replays ten sequences of 2000 operations recorded from the reference compiled with its
driver and telemetry sources: the transmitter's packets at the rate's cadence (sync packets with
rate, switch mode and telemetry ratio changes, channel packets in the wide and hybrid switch modes,
bind packets, MSP chunks with model id commands, and corrupted, lost and off-rate packets), timer
overflows at the programmed period, task passes with the system ready flag and bind requests, and
channel decodes of fresh payloads. They run over both bands, a bound or unbound unique id and every
telemetry ratio, checking the decoded payload and channels, the telemetry response, the hop and
status results and ninety-two state fields after every operation.

## D92. Flight log header (2026-10-12)

The flight log header unit contains the log header: the field definition tables of the main, GPS,
GPS home and slow frames with each field's name, index, sign, predictors, encodings and condition,
the condition cache built once at the log start, and the chunked writers that send the fixed header
text, the field definition lines and the system information lines under the device's byte budget.
The budget is replenished each iteration from the device's free space, grown by the per-iteration
allowance and held at the accumulated limit. A reservation the budget cannot cover fails for the
iteration, permanently when the device's buffer could never hold the bytes. The writer appends to a
caller owned array, lowers the device's free space by one per byte, and drops a byte a serial port
with no room cannot take. A wing's main table has the three stabilization terms after the
feedforward terms, and its sysinfo lists the stabilization settings in place of the autopilot and
rescue settings, so one unit serves both crafts through a flag.

The device, the settings and the clock stay with the target. It reports the device kind, the
per-iteration allowance, the buffer size and the free space, fills the sysinfo's values and texts,
and reads the writer's budget and counts. The firmware identity, the board, the craft name and the
debug mode name are texts the target provides, and the motor outputs and receiver rate arrive
already rounded. The P ratio line divides the intervals in 16-bit width.

The harness replays ten header transmissions recorded from the reference's recorder and device layer
over serial, flash and SD card stubs, seven multirotor and three wing: the fixed text, the field
definition lines of each table, and the sysinfo lines. Each step has a scripted free space, a
replenished budget and a clock advance, and the harness checks every byte written, the budget, the
header index, the field cursor and the completion flag after each of the 13505 steps.

## D93. Flight log recorder (2026-10-12)

The flight log recorder unit contains the recorder over the header unit (D92) and the field
encodings (D56). The log states run from disabled and stopped through the log file, the header, the
field definitions, the sysinfo and the cache flush to running, paused and shutting down, with the
erase states beside them. The intra frame contains every field its condition admits, and the delta
frame is taken against the previous frame or the average of the two before it, with the compact
encodings of the term, command and optional field groups. The slow frame goes on change or at its
interval, beside the GPS and GPS home frames and the events, with the arming beep and flight mode
changes logged as they happen. The iteration policy places the frames by the intra and delta
intervals derived from the loop time and the sample rate. The motor test and always-on modes start
and stop the log around the motors running while disarmed, and a full device stops it.

The device, the sensors, the settings and the clock stay with the target. Each update brings the
device's answers: its free space, whether it opened with its buffer size, whether the log file is
ready and closed, whether its buffers are flushed, whether it is full or erased, and whether a
serial port is shared. It also brings the state to log (the controller terms, rates, commands and
setpoints as values, the quaternion, the motors, servos, battery, altitude and GPS solution, and the
date and time already converted to seconds) and the sysinfo settings. The recorder rounds the
values, keeps the three-deep history, and appends the bytes to a caller owned array through the
header unit's writer, so a full serial port drops them. The counts of the flushes, forced flushes,
erases, beeps, opens and closes the target carries out stand in for the device calls. The first
motor's intra frame field saturates at zero where the motor output is below the output low, which
the reference leaves undefined (finding F101).

The harness replays ten logs of 2500 iterations recorded from the reference's recorder and device
layer over serial, flash, SD card and no device, eight multirotor and two wing. The flight state
runs on random walks, with the device's answers, the boxes, the arming and the clock scripted,
disarms finishing the log, and events and reinitializations between the updates. It checks every
byte written, the log state, the iteration counters and intervals, the header transmission, the
budget, the histories and the request counts after each of the 22800 steps.

## D94. Position navigation target (2026-10-12)

The position navigation unit contains the navigation target. A leg has its target east, north and up
in metres, a cruise speed, an arrival radius and a completion speed. The horizontal velocity toward
the target comes from the position gain, brakes onto the target at the approach deceleration and
stays within the acceleration limits, unless the owner states the velocity for a leg it profiles
itself. The vertical ramp walks the commanded altitude at the leg's rate, brakes into the leg
altitude, slews out of the rate of a leg it takes over from, and stays leashed to the craft. The
arrival test checks the radius and the altitude window with their hysteresis, the completion speed
and the settle timeout. A new leg takes over the velocity commanded so far. A moved target flies on
without disturbing the ramp or the arrival state. The sequence survives a reset, so a consumer still
sees the next leg as a change.

The owner that issues the legs stays with the target. The reference calls the leg's callback inside
its update, and a callback that issues the next leg keeps the velocity flowing where a silent one
has it cleared. The port's update reports the leg reached, and the owner either sets the next leg or
finishes the reached one, which clears the horizontal velocity and the leg when it clears itself.
The port's bounds are the estimator's position bound, a kilometre per second of stated speed and the
saturations declared in D6.

The harness replays six sequences of 2500 operations recorded from the reference: legs set, moved,
lowered and cleared, vertical profiles, acceleration limits, stated velocities, approach brakes,
arrival policies, settle timeouts, resets, approach speed queries, and updates against an estimate
on a random walk that drifts toward the target, with the reached callback silent or issuing the next
leg. Every field of the leg, the velocities, the arrival windows and the altitude and rate queries
are checked after each of the 15000 operations.

## D95. OSD warnings line (2026-10-12)

The OSD warnings unit contains the warnings line: one message chosen in a fixed order of precedence,
with its severity and its blink. Rescue failure comes first. Arming disable reasons follow, rotated
every half second to the next reason set above the one on display and round to the lowest, with the
arm switch dropped unless it is the only reason. Then come the DShot beacon guard, which shows the
beacon for its first half second and the tenths of a second until arming after it, the failsafe, and
the ESC alarms from the ESC sensor and then from the DShot telemetry. An alarmed motor prints with
its letters, R for a rotation at or below the alarm while the motor runs, C and T for a current and
a temperature at or above theirs, and a plus where the thirty-one characters run out. A line shorter
than eleven is centred in twelve. Below those come, in order:

- the crash flip, active or switched on while disarmed
- the launch control with the pitch in degrees when an accelerometer is present, blinking within ten
  percent of the launch throttle
- the RSSI, RSSI dBm, SNR and link quality alarms
- the critical battery
- the CPU load
- the rescue unavailable in the first five seconds armed and the heading not yet known
- the position hold failure
- the headfree mode
- the core temperature in the selected unit with its symbol
- the low battery
- the capacity alarm from the battery profile's capacity, else the setting
- the battery continued
- the battery not full before the first arming
- the visual beeper, which the line reports shown so the target clears it
- the chirp excitation finished, its series finished or one axis done

The port follows the multirotor default build. The flight plan cues and the flight plan's rescue
descent, compiled out on default targets, and the wing launch cues, wing targets only, are not in
it. The settings, the sensors, the modes and the clock stay with the target, which brings the values
the line reads. The reason on display and the time it was chosen are the only state the line keeps.

The harness replays six sequences of 2000 frames recorded from the reference, each sequence under
its own settings and enabled set, the frames under a precedence depth that holds off the conditions
above it so every message gets its turn. Every message of the 12000 frames replays byte for byte
with its blink, its severity and the beeper flag.

## D96. MSP tunnel over telemetry (2026-10-12)

The MSP telemetry unit contains the tunnel that transports MSP over a telemetry link. A request
arrives in chunks behind a status byte that holds the chunk's sequence number, a start flag and the
protocol version. The first chunk declares the request: the command and payload size of a version 1
frame, the jumbo size past 254 bytes, or the flags, the 16-bit command and the size of a version 2
frame. A version above two answers with a mismatch error, a size past the 192-byte request buffer
with a too-big error. The chunks that follow continue the request while their sequence numbers run
on from the last. A chunk out of sequence drops the request, a chunk without a start is ignored, and
a chunk shorter than its header is ignored. The last chunk completes the request at the declared
size, extra bytes ignored. A completed EEPROM write command reports itself, so the owner skips a few
telemetry requests before replying. The reply goes back in chunks of the link's size behind the same
status byte. The first chunk holds the start flag, the error bit for a failed request and the reply
header in the request's framing. Every chunk fills the link's size until the last takes the
remainder, and a reply that ends exactly on a chunk boundary is followed by a chunk of the status
byte alone.

The command processor stays with the target. The reference runs it inside the chunk handler. The
port's chunk handler reports a request ready, the owner processes it and hands back the verdict and
the payload, which the tunnel stores with an error byte appended for a failed verdict. The reply's
flags byte is always zero.

The harness replays six sequences of 400 operations recorded from the reference: requests of every
framing in chunks of random sizes with lost and out-of-sequence chunks, truncated headers, trailing
bytes and lone chunks, the processor's reply of random size under a random verdict, requests
arriving while a reply is still going out, and the replies pulled at the SmartPort, CRSF and random
chunk sizes. Every chunk, request state and reply state of the 28655 lines replays byte for byte.

## D97. OSD formatting (2026-10-12)

The OSD format unit contains the formatting helpers that the OSD elements call to turn readings into
text. A number prints with a leading and a trailing symbol, its decimals rounded half to even or cut
at the last decimal, the integer part in a width with zeros or spaces and a character before it, and
a minus sign when the value is negative and the digits are not all zero. Altitudes print in the
selected unit with one decimal or none, above the launch point or above sea level. Coordinates print
from ten-millionths of a degree with seven or four decimals, as degrees, minutes, seconds and tenths
with the hemisphere letter, or as the eleven-digit plus code, and read as zero until the first fix.
Distances print in feet or metres below a mile or a kilometre and in miles or kilometres above, with
one decimal from ten and two below. A PID line prints its label and the five gains in three places
each. The clock prints the short local form, the month, day, hours and minutes, or the time alone,
and prints nothing without a clock. Timers print minutes and seconds with hundredths or tenths by
their precision, from the source their setting names: the on time, the flight time, the last armed
time, one or the other by the arming state, or the launch time, with the source's symbol before
them. The battery symbol is the critical one or the cell voltage's step over the profile's range.
The direction symbol is the heading's sector of sixteen. The unit conversions cover metres, speeds,
climb rates and temperatures with their symbols.

The plus code unit contains the reference library's encoder for the grid lengths, the only lengths
the OSD asks for: the latitude clipped to its range and the pole moved half a precision south, the
longitude wrapped into its range, the two positions scaled to integers at the grid precision, the
five grid digits from the five by four refinement and the ten pair digits from the base twenty
alphabet with the separator after the eighth.

The warnings line takes its unit system and its temperature conversion and symbol from the format
unit, where the reference's warnings call the elements file. The battery symbol requires the
profile's cell voltage limits to differ, where the reference divides by their difference (finding
F103). The readings and the settings stay with the target.

The harness replays six sequences of 1500 calls recorded from the reference, each call to one helper
under random readings, units, variants and symbols, with the clock set to dates up to 2099, which
the 64-bit conversions place exactly where the reference's 32-bit count wraps (finding F104), and
the formats of the elements' calls. Every text, symbol and conversion of the 9006 lines replays byte
for byte.

## D98. Transmitter driver over MSP (2026-10-12)

The VTX MSP unit contains the transmitter driver for a video transmitter reached over the MSP link,
the goggle systems' way. The driver starts offline and is ready once the transmitter has answered on
the driver's link and the table has bands, channels and power levels. The configuration it holds is
what the control layer sets: band and channel, the power looked up in the table by index, the pit
mode and the frequency, each marking the configuration changed when it differs. Each cycle, once
ready, a change of the low power state marks the configuration changed too, and a changed
configuration goes out once two hundred milliseconds have passed since the last. The frame has
fifteen bytes: the device type, the settings' band, channel and power, the lowest power while low
power disarmed, the pit mode, the frequency, the readiness, the low power setting, the pit mode
frequency and the table's counts, sent as an MSP reply with the transmitter configuration command.
The same frame wrapped for the CRSF telemetry buffer gets the sync byte, the length, the MSP
response type, the receiver and flight controller addresses, the header of a first chunk in version
2, the MSP checksum and the frame checksum. The configuration reads back once ready: the band and
channel, the power index found in the table or zero for no power, the frequency of the band and
channel, the pit mode, and the table's power levels in decibel-milliwatts and in milliwatts through
the C library's power function.

The link, the port sharing that decides between the serial push and the CRSF wrapper, the port
selection of the initialization, and the command processor that reports the transmitter's answer
stay with the target. The owner tells the driver its link answered, and pushes the frame the cycle
hands back by the way its link requires.

The harness replays six sequences of 1200 operations recorded from the reference, each sequence
under its own table and settings: the control layer's setters and getters, the link's readiness with
matching and foreign descriptors, the cycle under random times, arming, failsafe and link flags, and
the frame preparation alone. Every state field, reply frame, wrapped frame and reading of the 7206
lines replays byte for byte.

## D99. MSP display port (2026-10-12)

The display port MSP unit contains the display port over the MSP link, the OSD canvas of a goggle
system. Each operation is a display port payload the target sends as an MSP reply in the first
framing: the heartbeat, the release, the clear, the draw, a string at its column and row with the
attribute byte, a system element at its column and row, and a font character at its address with the
sixty-four bytes of the glyph. The attribute byte takes the profile's font bank for the element's
severity and the device blink bit for a blinking element. A string is cut at thirty characters, an
empty string sends nothing, and a character is the string of that character, the null character an
empty one. The initialization takes the canvas size from the configuration for a high definition
system and the standard lines of PAL or NTSC with the standard columns otherwise, each with the
profile's adjustment, and sends a clear and a draw. The display layer's bookkeeping over the port is
in the unit: a grab sends the heartbeat and a clear and counts, a release the release payload, a
clear marks the screen cleared and the cursor off, and the device reports itself synced, ready and
never mid-transfer.

The MSP link, the serial port the display answers on, the port selection of the initialization and
the eighty millisecond pause after a font character stay with the target.

The harness replays six sequences of 600 operations recorded from the reference behind its display
layer, each sequence under its own profile, video system and canvas: grabs, releases, clears, draws,
heartbeats, redraws, strings of every length and attribute, characters, system elements, font
characters and the state queries. Every state field, payload and result of the 3606 lines replays
byte for byte.

## D100. OSD statistics (2026-10-12)

The OSD stats unit contains the flight statistics: the extremes tracked while armed and the text of
every statistic on the page after a flight. The reset at arming sets each extreme at its far end,
the link quality floor at 99 without a link quality source and 100 with one. Each update takes the
readings of the cycle through sixteen-bit comparisons: the speed in three dimensions or over the
ground, the voltage of the pack or the average cell by the setting, the current, the signal percent,
the altitude, the acceleration, the link quality, the signal strength and the noise ratio, the home
distance under a fix and a home fix, the ESC temperature from the sensor's combined reading when its
feature is on and from the telemetry's per-motor maxima otherwise with the motor that set it, and
the average ESC rotation from the sensor converted or the telemetry averaged. A reading past sixteen
bits wraps, except the home distance, which the statistics keep unsigned to 65535 metres. The
reference keeps that distance in a signed field, so a distance from 32768 metres records negative,
every later distance passes the comparison, and the statistics page prints a minus sign (finding
F105).

The page's text for a statistic comes with its label beside the value, or the value alone across the
label's place for the clock, and reports when the statistic is not shown: the speed, distance and
flight distance only with the GPS feature, the current, charge and energy only with a current meter,
the flight log status only for a flash or card device, the log number only when there is one, the
acceleration only with an accelerometer, the peak frequency only with the dynamic notch active. The
timer statistics print the timer without its symbol under its precision unless its source is the on
time, and label it with the source's name. The lap times print seconds and hundredths rounded, or a
blank. The flight log status prints the storage used in percent from the card's blocks and free
space or the flash partition's sectors and offset, or a fault. The display, the readings and the
settings stay with the target, which places the label thirteen columns left of the middle, the colon
five right and the value seven right.

The harness replays six sequences of 1500 operations recorded from the reference: resets with and
without a link quality source, updates under random readings with the wrapping ones among them, and
each statistic's text under random settings, clocks, meters, devices and totals, checked against the
display writes the reference made with their columns and rows. Every extreme, text and position of
the 9006 lines replays byte for byte.

## D101. OSD page and arming screen (2026-10-12)

The OSD page unit contains the statistics page, its arming and boot screens, and the three steps the
OSD runs around them each cycle. The page is laid out one row per statistic enabled, in display
order, each row the label thirteen columns left of the middle, a colon five right and the value
seven right, or the clock alone at the label's place. A counting pass finds the row count, then the
page is centred vertically with its heading when the rows fit, and the refresh walks its phases of
the first clear, the count, the clear between and the rows until the page is complete or the rows
run out. The arming screen clears the display, draws the logo when the setting shows it always or
until the first arming, and writes the armed word in the middle and the crash flip warning below it
when that mode is on. The pause after it lasts the logo's duration or half a second. The boot screen
clears the display and draws the logo, the version in capitals, the menu help and the clock when
there is one, with a pause of four seconds. The logo goes to the display as a whole when the display
draws it itself, else as the font's logo characters row by row.

The first step of a cycle sees the arming transitions. Arming resets the statistics and starts the
pause with the arming screen. Disarming enables the page when a statistic is enabled, the page is
not suppressed, no failsafe is active, and the disarm was not a runaway or crash with the warnings
visible, keeping the end voltage and resetting the row count. While armed the extremes update and
the flight and launch times grow by the cycle, the launch time resetting while launch control is
active. While disarmed with the page enabled, a grabbed display drops the page, the switch hides it
and shows it again, and a shown page refreshes every second. The auxiliary value follows its channel
every second. The second step keeps the pause: while it lasts the cycle draws nothing, and a high
throttle or pitch stick or the crash flip switch while disarmed ends it early. Once the pause has
passed the display clears and the page is dropped. The third step reads the acceleration when the
element shows it or its statistic is enabled. The display, the sticks, the switches, the arming
disable reasons and the readings stay with the target, which draws the writes each step hands back.
The counting pass sees the display's rows and columns.

The harness replays six sequences of 500 operations recorded from the reference: the first step
under random times, arming, failsafe, grabbing, switch, launch control and readings; the refresh
walked to completion under random settings, pages and extremes with displays that draw the logo
themselves and ones that do not; the second step under random sticks, switch and pauses; the third
step; the arming screen; and the boot screen with the version and the clock. Every state field,
extreme, write and position of the 11803 lines replays byte for byte.

## D102. OSD element set, alarms and active list (2026-10-12)

The OSD elements unit contains the item set with its position fields, the blink the alarms drive and
the list of the active elements. The item set is the eighty-nine items of a one-megabyte target
without flight plan, map or pitot, in the reference's order, which fixes each item's place in the
position table and in the blink bits. A position field holds the column in five bits with a sixth
above the row for wide displays, the row in five bits, the three profile bits and the variant in the
top two. An item is visible when its profile bits meet the active profile's bit, the first profile
standing in for profile zero. The blink has a bit per item and a state the half second cadence sets
from the clock, on in the first half. An item blinks while its bit is set in the on half, and a
reset clears every bit.

The alarms set the bits each cycle: RSSI, RSSI dBm and link quality under their thresholds; battery
voltage and cell voltage while the battery state is not OK; satellites without a fix, under four, or
under the rescue's minimum when the rescue is configured; each timer whose source has reached its
alarm minutes; charge drawn and remaining time estimate at the capacity alarm; battery usage at the
capacity alarm, or on a low battery without one; altitude at its alarm while armed; home distance at
its alarm while armed with a home fix; and ESC temperature at its alarm from the ESC sensor's
combined reading, or from the first motor whose DShot telemetry contains one. The timer alarm is the
alarm minutes times sixty million in sixty-four bits, so an alarm the thirty-two-bit timer cannot
reach never fires. The reference multiplies in thirty-two bits, which wraps past seventy-one minutes
and fires almost at once (F107). The capacity alarm is the battery profile's capacity when it has
one, else the setting. The altitude compared is the selected unit's value over a hundred, truncated.

The active list is built from the positions and the active profile: horizon, g force and up and down
reference with an accelerometer, then the display order of seventy-three items, then the eight GPS
items with a GPS, the three ESC items with an ESC sensor or DShot telemetry, the three lap times
with a GPS, and the total flights. The up and down reference and the total flights are listed twice
when visible, and the list holds the ninety-one adds of a list with every item visible (F106). Six
items ask for the accelerometer when active. Settings, sensors, clocks and readings stay with the
target.

The harness replays six sequences of 400 operations recorded from the reference: the active list
under random positions, profiles, sensors and features; the alarms under random thresholds,
readings, clocks, battery profiles and motor telemetry, with the blink synced to the clock and one
item's blink read back; and the reset. Every count, listed item, accelerometer need, blink word and
state of the 2406 lines replays byte for byte.

## D103. OSD element renderers for readings (2026-10-12)

The OSD render unit contains the element renderers that format readings, thirty-eight of the
seventy-six: altitude, pitch and roll angles, anti gravity, average cell voltage, compass bar, core
temperature, crosshairs, current, the two debug lines, disarmed, g force, charge drawn, watt hours,
battery usage, battery voltage, numerical heading, vario, PID and rate profile, the three PID lines,
power, remaining time estimate, RSSI, RSSI dBm, RSNR, throttle, the two timers, auxiliary value,
ready mode, position hold ready, total flights, flip arrow, flight mode and clock. Each render
starts from an empty text, offsets at zero, normal severity, drawn and complete, and fills them as
its element does. The altitude prints in the unit when a barometer or a GPS fix supplies it, else
the altitude symbol and a hyphen, critical past the altitude alarm while armed. The angles print
with a sign and two digits. The cell and pack voltages print with the battery symbol, warning and
critical by the battery state, the pack voltage with one decimal from ten volts. The compass bar is
nine characters of the heading strip. Charge, watt hours and remaining time are critical past the
capacity alarm, the remaining time being the flight time scaled by the charge left over the charge
drawn, dashes below a tenth of the capacity and zero past it. The battery usage prints as a
percentage of the profile's capacity or of the voltage estimate, or as a bar of eleven cells with a
half cell. The RSSI is capped at ninety-nine and critical under its alarm. The RSSI dBm prints with
the antenna once a second antenna has reported. The timers are critical when either alarm has
passed. The flip arrow comes from the folded roll and the pitch while crash flip is on or the craft
lies disarmed off its feet. The flight mode prints in order of precedence from failsafe to acro,
with the chirp's axis, repeat and finish. The clock prints in the variant's form when the clock is
set. The remaining time's conversion to microseconds saturates at the signed thirty-two-bit limit
(F108). The PID line's feedforward widens to sixteen bits (D97). Settings, sensors and readings stay
with the target. The graphics, GPS, link, ESC and name elements and the draw cycle come later.

The harness replays six sequences of 500 renders recorded from the reference, each element under
random settings, readings, attitude, battery profile, gains, clocks, switches, modes and clock.
Every text, offset, severity and flag of the 3006 lines replays byte for byte.

## D104. OSD element renderers for GPS, link, ESC and names (2026-10-12)

The OSD render unit grows by the GPS, link, ESC, motor, log, name and text renderers, twenty-nine
items, and the craft and pilot name backgrounds: flight distance, home direction and distance, the
two coordinates, satellites, speed, efficiency, the three lap times, link quality, uplink power, log
status, ESC temperature, ESC rotation and frequency, motor diagnostics, the rate, PID, OSD and
battery profile names, the four custom messages, the custom serial text, the adjustment range and
the lidar distance. The GPS elements print their values with a fix and a hyphen without one. The
home direction points to the lap timer's start while a lap runs, and the home distance measures to
it. The coordinates set their blink while a fix once held is lost. The satellite count is critical
without a fix or under four and a warning under the rescue's minimum, with the dilution appended on
request. The efficiency filters the current over the speed at half a hertz and prints up to four
digits. The link quality prints by its source, with the mode before it for Crossfire except in the
second variant. The uplink power prints in milliwatts below a watt. The ESC temperature prints the
sensor's combined reading or each motor's telemetry and stops at the text's thirty-one characters,
where the reference writes past its buffer (F109). The ESC rotation elements walk the motors one row
a render. The motor diagnostics scale each output into a bar and mark a stopped motor. A name prints
in capitals, or its default with the profile's number when empty. A custom message prints as stored
or its number. The serial text prints up to thirty-one characters or dashes. Settings, sensors and
readings stay with the target. The graphics and the draw cycle come later.

The harness replays six sequences of 500 renders recorded from the reference, each element under
random fixes, positions, satellites, speeds, laps, links, logs, ESC telemetry, motor outputs, names,
messages and texts, with the efficiency filter kept between renders. Every text, offset, severity,
blink, flag and filter state of the 3006 lines replays byte for byte.

## D105. OSD element renderers for graphics and the VTX channel (2026-10-12)

The OSD render unit grows by the graphics renderers, the VTX channel and the remaining backgrounds:
artificial horizon, up and down reference, the left and right stick overlays, RC channels, VTX
channel, and the horizon sidebar, camera frame and stick overlay backgrounds. The artificial horizon
walks nine columns one a render, each bar character from the roll and pitch held to their limits and
scaled, drawn only when its row falls on the ladder. The up and down reference marks the zenith or
nadir from the attitude matrix's up row within twenty-five degrees, its offsets scaled from the
small angles. The stick overlay places the cursor sprite from the radio mode's sticks and draws its
cross one row a render. The RC channels print one channel a render scaled to thousandths. The VTX
channel prints the band letter, channel name and power label from the table, the band and channel
looked up from the frequency when the band is zero, the power from the transmitter while it limits
power disarmed, dashes when locked, with the disable or pit mode mark. The horizon sidebars write
their decorations row by row and then the level marks. The camera frame writes its top, its sides
row by row and its bottom. A renderer's direct writes are one-character string writes with the blink
bit while the element blinks. The reference prints the up and down reference's symbol as the low
byte of its string's address (F110). Adaflight prints the letter, a deviation declared in D6.
Settings, sensors, sticks, tables and readings stay with the target. The draw cycle comes next.

The harness replays six sequences of 500 renders recorded from the reference, each element under
random attitude, limits, sticks, radio modes, channel settings, frame sizes, tables, transmitter
states and blink bits, with the rows walked between renders. Every text, offset, severity, flag and
direct write of the 3006 lines replays byte for byte, the up and down reference's letters standing
for the bytes the reference printed.

## D106. OSD warnings element (2026-10-12)

The OSD render unit contains the warnings element: the warnings line from the warnings unit (D95)
with its severity, and the element's blink bit set while the line blinks and cleared otherwise. With
the craft name messages on, a link quality message replaces the line while the blink is in its
hidden half or the line is empty: the mode, quality and RSSI dBm for Crossfire, the quality and RSSI
dBm for Ghost, else the quality scaled to one digit. The element then copies its first sixteen
characters into the craft name, zero filled after a shorter text, and ends the name with a zero. The
reference copies fifteen, so a text of fifteen characters or more leaves the name's sixteenth byte
as it was (F111). The craft name buffer, the blink and the readings stay with the target.

The harness replays six sequences of 500 steps recorded from the reference, the warnings scripted as
for D95 with the craft name messages, link sources, qualities, modes, blink halves and stored names
added. Every text, blink bit, severity, beeper flag and craft name byte of the 3006 lines replays
byte for byte.

## D107. OSD draw cycle (2026-10-12)

The OSD draw unit contains the element draw cycle. Each call takes the element on turn from the
active list. Where the display has no background layer and the element has a background not yet
drawn, the call draws the background. Otherwise it draws the foreground and moves to the next
element once the renderer reports the element complete, returning false after the last element and
starting again at the first. A foreground draw is skipped for an element without a foreground, and
for an element whose blink is in its hidden half unless the display blinks it itself. A system
element goes to the display as a system write at its position. The warnings element renders through
the warnings unit with the craft name messages. Every other element renders through the render unit
with its variant, its blink bit taking the renderer's change. A render stores its text in the
element buffer when it writes one, and the buffer keeps its old text otherwise, so renderer outputs
gain a flag for whether they stored their text. The pending write goes to the display at the
element's position plus its offsets, with its severity and the blink attribute while its blink bit
is set, a background's before a foreground's. An empty buffer writes nothing. The background pass
after an analysis selects and clears a background layer and draws every active element's background
to completion into it, or asks a display without the layer to redraw its background. The pass writes
the renderers' own characters and leaves text backgrounds pending (F112). The element on turn keeps
its number across an analysis that shortens the list, and the bound checks restart the cycle. The
display, active list, blink, settings and readings stay with the target, which runs the operations
each call hands back.

The harness replays six sequences recorded from the reference as the OSD task steps the cycle, one
draw or display call at a time with readings rescripted between calls: eighteen elements visible at
random positions and variants, an occasional re-analysis with new positions and sensors, and
displays with and without a background layer and their own blink. Every return, pending flag,
element number, blink bit, craft name byte and display operation of the 3612 lines replays byte for
byte.

## D108. OSD spec prearm screen (2026-10-12)

The OSD spec unit contains the spec prearm screen, drawn one row a call. The first row is the RPM
limit: on with its value when the limit is set and the motors run bidirectional DShot, else off.
With the limit on, the screen adds the motor's KV and pole count and the limit's three gains. The
throttle limit follows with its kind and, unless off, its percentage, then the motor output limit,
the pack voltage with two decimals and the battery symbol, and the version, after which the screen
is complete and starts again. Each row is centred on the display's middle column. The first goes
three rows above the middle row and each next row below the one before. The settings, readings and
version stay with the target, which writes each row.

The harness replays six sequences of 600 calls recorded from the reference under random limits,
motors, gains, batteries and display sizes. Every row's text, position and completion of the 3606
lines replays byte for byte.

## D109. OSD task (2026-10-13)

The OSD task unit contains the OSD task: the update check and the update state machine. The check
wakes an idle task once the clock passes the frame's due time, which steps past the clock by whole
frames of a second over the frame rate, or starts one frame ahead. A check or transfer state waits
while the display transfers. Each update runs one state, in this order:

- the boot state, once the display is ready: it selects the foreground, opens a transaction, draws
  the boot screen, sets a four-second pause, resets the element state and analyzes the active
  elements
- the heartbeat
- the three statistics steps with the arming screen and the clears they ask for, the statistics page
  between the first and second when due, and the second opening a transaction each time
- the alarms, skipped while the menu holds the display
- the canvas, which waits out the pause, clears for the OSD switch, clears or copies the background
  layer, re-analyzes the elements when the GPS sensor appears or goes, and syncs the blink
- the draw cycle's element draws and displays
- the spec prearm screen after the elements while disarmed when the setting asks for it
- the commit
- the transfer, repeated while the display reports more to draw

Each update keeps a running peak time per state, and per element place for the draws, decaying by
one and replaced by a longer time, and names the next state's anticipated time to the scheduler. The
state times wrap past 2047 µs in sixteen bits (F113). The display port's answers come in with the
call, and its operations go back in order. The statistics page renders only when its readings fit
the page's bounds, which every physical altitude does. Settings, readings and the display stay with
the target.

The harness replays six sequences of 1500 scheduler steps recorded from the reference, each a check
and, when due, an update, over MAX7456, MSP and FrSky displays with and without the logo and with
random answers, arming, switches, sticks, sensors and readings, six elements visible, the statistics
page off, and clocks that sometimes run a state past 2 ms. Every check result, state, scheduler flag
and time, page state, statistic and display operation of the 17162 lines replays byte for byte.

## D110. MAVLink telemetry streams (2026-10-13)

The MAVLink telemetry unit contains the stream messages: system status with system time, raw RC
channels, raw GPS, global position, GPS origin, home position, attitude, heartbeat, HUD and battery
status. Each message is packed in the library's wire order and framed as MAVLink 2 with trailing
payload zeros trimmed, the link's sequence number and the message's CRC extra.

A pass runs when the receiver's buffer report asks for one, or 20 ms after the last pass when no
report is valid. It sends each message past its due time in table order and moves that due time one
interval past the clock, whether or not the message had anything to send. The pass ends with the
arming report: a status text of the disable reasons, cut at 49 characters, sent when the reasons
change to a nonzero set. The disable reason names move from the OSD warnings unit into the arming
unit, which both readers share.

Stream rates set the intervals, at least 20 ms, each first due one interval plus 3 ms per table
place ahead. A ground station sets one message's interval, zero restoring the rate's, and reads it
back in microseconds, held at the largest signed 32-bit count. The reference multiplies the
milliseconds in 32 bits before it compares, so an interval above 4294967 ms wraps and reads back
short (finding F115). Global position sends the microsecond clock in its millisecond boot time field
(F114). Port, receiver link and readings stay with the target. Incoming commands and the mission
protocol are open.

The harness replays six sequences of 500 steps recorded from the reference: telemetry passes under
random readings, rates, arming reasons and clocks, interval sets including unknown messages and the
saturation and wrap edges, each edge set read straight back, and interval reads. Every frame byte,
due time, interval and sequence number of the 3019 lines replays byte for byte.

## D111. MAVLink commands (2026-10-13)

The MAVLink commands unit contains the telemetry's incoming side. Messages from a ground station
arrive two ways: drained from the telemetry's own port, up to 64 bytes a pass through a frame parser
of its own, or popped from the MAVLink receiver's queue, up to sixteen a pass. The parser state
moves out of the receiver's record into a record of its own so both parsers share the code. MAVLink
2 framing moves into a unit of its own, shared by the stream messages and the replies with one
sequence number.

Ping and time sync requests are answered. A command long or command int addressed to this system, or
to every system, is executed and acknowledged. Command long also requests the autopilot version,
protocol version, component information, available modes, modes monitor and a message's interval,
and sets a message's interval. Both execute disarm, mode selection, return to launch, set home and
reboot. Arming over the link is a build option the default leaves out, so it answers unsupported.
Float parameters are decoded from their bits. A parameter counts as a whole number only when finite,
not negative and not above the handler's maximum.

Disarms, mode override clears and sets, and home resets and sets go out as requests in call order,
for the target to apply to the arming, modes and GPS units. An accepted reboot goes out as a reboot
request at the end of the pass that accepted it, from the port's drain or the receiver's queue. The
reference runs a pending reboot only after the port's drain, so one accepted from the receiver's
queue stays pending for good (finding F116). Coordinates, altitudes and intervals past the range of
the reference's float conversions saturate, where the reference is undefined (F117). A set-home
altitude goes out as commanded, and the home position telemetry multiplies it by ten (F118). The
modes unit's override mask, which the reference adds to the switch-selected modes and clears at each
disarm, is open.

The harness replays six sequences of 500 steps recorded from the reference, alternating the owned
port and the receiver's queue: heartbeats, pings, time syncs, and command long and command int
messages with random targets and parameters (NaN, infinities, signed zeros, subnormals, handler
bounds), unknown messages, MAVLink 1 frames, noise and corrupted frames. Every reply byte, request,
home value, interval, sequence number and parser state of the 3006 lines replays byte for byte.

## D112. MAVLink mode overrides (2026-10-13)

The mode update takes a mask of overridden boxes and forces them on after the switches vote. A
ground station sets these boxes through the MAVLink commands (D111). The mask lives in the arming
state, where every disarm clears it before anything else, and the arming unit hands it to the mode
update. The reference keeps the mask with the mode state and clears it from its disarm path, in the
same order. Boxes are forced on or released one at a time, and the whole mask clears at once.

The arming vectors were recorded again with a third random stream that clears, sets and releases
overrides before each step. Of the 15030 lines, 4015 change from the earlier recording. Overrides
are active in 3789 of the 15000 steps, and a disarm clears them 15 times. Every line replays byte
for byte.

## D113. Jeti EX Bus telemetry (2026-10-13)

The Jeti telemetry unit contains the answer to a transmitter's telemetry request. A call answers
when the receiver may transmit, the request is a telemetry request no older than 3 ms with a good
CRC, and no byte waits on the port. A stale or failed request is dropped, and an answer ends the
permission to transmit. The receiver's request state gains the processed state an answer sets.

The first 255 answers are text messages that describe the enabled sensors and the two device
descriptions in turn. The answers after them hold sensor values: each message starts at the next
sensor and holds the following enabled sensors of its group of fifteen, at most four values. A value
takes three bytes with its decimals in the top byte, and a GPS coordinate takes four bytes of
degrees and thousandths of a minute with the longitude and sign flags. The GPS sensors leave the
values when the text phase ends with the GPS feature on, and return once a GPS is detected. The RPM
value averages the motors with fresh ESC data and rounds ties to even. With no sensor enabled the
reference reads a value length past its table (F119), and adaflight sends no value frame. A power
product past 32 bits wraps as the target's multiply does, and a G-force past 16 bits saturates.

The harness replays seven sequences recorded from the reference, each request frame fed through the
receiver byte by byte: telemetry requests, other requests, channel frames, corrupted and cut frames,
stray bytes, waits up to 5 ms and busy ports, under random sensor sets, readings and ESC data. One
sequence enables a single sensor, and one enables none and stops inside the text phase. Every
request state, permission, sensor set and frame byte of the 15707 lines replays byte for byte.

## D114. FrSky SPI receiver, D8 (2026-10-13)

The FrSky SPI unit contains the FrSky receiver on a CC2500 radio for the D8 protocol, with the SPI
receiver's LED and bind button handling and the CC2500 helpers. Start-up checks the chip when the
setting asks, raises the LNA and antenna pins, lowers the transmit enable pin and claims the RSSI
source. The first protocol call after 10 ms resets and configures the radio and calibrates every
channel. The target measures the calibration and hands it back.

Binding, on a bind request or with auto bind, tunes the frequency offset up and then down in steps
of two every 50 ms until a bind packet arrives at each end, keeps the midpoint, and collects the
transmitter id and the hop table in ten chunks of five. Bound, the receiver hops over 47 channels. A
packet from its transmitter with the CRC bit set hops on, sets the RSSI from its status byte, and
every fourth one is answered 1.38 ms later with the telemetry frame: transmitter id, A1 and A2
values and RSSI. Without packets the receiver hops on, switches antennas after two misses, drops the
RSSI after 100, and searches with a 13-channel skip at the slow timeout. Channels decode at two
thirds of their 12-bit values and are kept unless one leaves 800 to 2200.

Radio operations, pin changes, RSSI updates, delays and the configuration save go out in order. The
target runs them and shows the receive FIFO and the interrupt line on each call. A bind chunk index
past the hop table writes nothing beyond it, where the reference writes into the settings after it
(F120). Hub telemetry data in the frame is open.

The harness replays six sequences of 3000 calls recorded from the reference with a scripted
transmitter: bind packets with random chunks, bad headers and missing CRC bits, data packets with
telemetry slots, wrong ids and short FIFOs, noise, dropouts of up to 300 calls, bind button presses
and bind commands, under random pins, LED inversion, auto bind, A1 sources and bound or unbound
settings. Every operation, channel value, bind result, hop table and state of the 18006 lines
replays byte for byte.

## D115. FrSky SPI D8 hub telemetry (2026-10-13)

The FrSky SPI unit gains the D8 telemetry frame's hub data. With the telemetry feature on and the
FrSky hub stream free of a serial port, the receiver owns the hub stream. When the transmitter
acknowledges the last frame, the next frame starts a hub burst once the previous one is sent. When
it asks again, the unacknowledged bytes go out again. A burst lands in a 64-byte buffer and goes out
ten bytes a frame. A burst of 64 bytes or more fills the buffer, goes out in full and clears for the
next burst. The reference's send position wraps at the buffer's size and never reaches a full count,
so it resends the same 64 bytes for good (finding F122).

The harness replays the six D8 sequences of D114 unchanged and three more with telemetry on: one
with every sensor and a GPS fix, where the eighth hub cycle stalls the buffer, and two with random
sensor sets and settings, the scripted transmitter acknowledging nine telemetry frames in ten. Every
operation, frame byte and buffer count of the 27009 lines replays byte for byte.

## D116. FrSky SPI X receivers (2026-10-13)

The FrSky SPI unit gains the four D16 variants: FCC, LBT, and their V2 forms, each with its radio
configuration, packet length and telemetry delay. A V2 bind is one packet, decoded with the 0xA7
mask, whose transmitter id seeds a generated hop table that steps around each band's reserved
channels. A packet passes the D16 CRC over its body, the transmitter id, and the receiver number
when both sides set one. The first good packet after a reset gives the hop skip.

Each good packet stores the transmitter's telemetry slot by its sequence id and answers with either
a resend request for the first missing slot or an acknowledgement of the slots received in order.
Five resend requests in a row reset the transport. The receiver's own telemetry frame alternates the
RSSI and the A1 value, answers an init request, resends a slot on request, or fills the next slot
with up to five SmartPort bytes, and ends with the D16 CRC. After the telemetry slot the receiver
waits 3.7 ms, hops by the skip, switches antennas after two misses, and resets the hop skip after
100. Channels decode as eleven-bit values with a shift bit that moves a channel eight up, and a
failsafe packet leaves them as they were. SmartPort payloads over the link are open.

The harness replays eight sequences of 4000 calls recorded from the reference, two for each variant,
with a scripted transmitter: bind packets, D16 packets with random skips, receiver numbers, failsafe
flags, shifted channels and telemetry markers with init and resend requests, corrupted and short
packets, noise and dropouts up to 900 calls. Every operation, frame byte, channel value, bind result
and state of the 32008 lines replays byte for byte.

## D117. S-FHSS receiver (2026-10-13)

The S-FHSS unit contains the S-FHSS receiver on a CC2500 radio. The CC2500 radio unit now contains
what the SPI receivers share: the operations in order, the pins, the LED with its blink timer, bind
requests, the RSSI from a status byte, the antenna switch, register lists and channel calibration.
The antenna switch follows the antenna pin that start-up set. The first protocol call after 10 ms
resets and configures the radio and calibrates its 30 channels, six channel numbers apart from 16.
The target measures the calibration and hands it back.

Binding listens on channel 15. The frequency offset rises by 16 every 220 ms until a packet arrives
with a link quality above 40, which gives the transmitter id. The offset then widens by 4 up and
down while packets keep arriving within 880 ms, and the midpoint becomes the bind offset, or binding
starts over when the two ends meet. The coarse sweep wraps from 112 to -128 as a signed byte (F125).
Bound, the receiver hunts with a hop every 500 ms until a packet with channels 5 to 8 arrives, then
hops 0.5 ms after that half, 3.5 ms after the other half, or 6.8 ms after a miss. It switches
antennas after two missed hops and hunts again after 100. Each packet's hop code moves the channel.
A code of 30 or 31 moves it past the calibrated channels, where adaflight writes zero calibration
and the reference reads past its table (F123). The proof shows that the hop loop ends in every state
the receiver can reach. Start-up reports success when the chip does not answer, without the radio's
pins or the RSSI source (F124).

The harness replays ten sequences of 3000 calls recorded from the reference with a scripted
transmitter: packets inside an offset window during binding with poor link quality, failed CRCs, bad
headers and other ids, a transmitter that goes quiet after the coarse sweep, channel packets with
failsafe flags, wrong channels and short FIFOs, hop codes 28 and 29 and an occasional code of 30 or
31, noise, dropouts up to 260 calls, bind presses and bind commands, a clock near its wrap and a
chip that does not answer. Every operation, channel value, bind result and state of the 30010 lines
replays byte for byte.

## D118. Redpine receiver (2026-10-13)

The Redpine unit contains the Redpine receiver on a CC2500 radio, in a fast and a slow mode with
their own radio configurations. The first protocol call after 10 ms resets and configures the radio
for its mode and calibrates 255 channels, which the target measures and hands back.

Binding switches to the fast mode, configures and calibrates again, and listens on channel 0 with
the hop table cleared. The frequency offset rises by 16 every 220 ms until a bind packet arrives,
then widens by 2 up and down while bind packets keep arriving within 880 ms. Each bind packet gives
the transmitter id and five hop table entries at its chunk index. A chunk past the table writes
nothing beyond it, where the reference writes into the settings after it (F126). Binding starts over
when the two ends are 10 or less apart, and returns to the coarse sweep without clearing the table
while an entry is still zero. The midpoint becomes the bind offset. Auto bind blinks the LED 80
times over 4 s instead of saving, and restarts binding after any 2 s without packets (F127). The
coarse sweep wraps from 112 to -128 as a signed byte (F125).

Bound, the receiver hops over 49 channels. A 13-byte packet from its transmitter gives the loop
time, 100 µs or 1 ms per count by mode, and the RSSI from its status byte, and the receiver hops on.
Without one, it hops on after a loop time and an eighth, switches antennas after two misses,
resynchronizes after 50 loop times, and switches modes after 2 s. Channels decode as four sticks
from eleven bits, scaled by two thirds onto 817 to 2182, and twelve switches at 1000 or 2000. A
status frame instead asks for video transmitter band, channel and power while disarmed.

The harness replays seven sequences of 4000 calls and one start-up with no chip, recorded from the
reference with a scripted transmitter in fast or slow mode: bind packets with random chunks inside
an offset window, a window too narrow for the coarse sweep, data packets at the transmitter's loop
time with VTX frames, wrong ids and short FIFOs, noise, gaps up to 4 s, auto bind with a 3 s gap,
bind presses, bind commands, arming changes and a clock near its wrap. Every operation, channel
value, bind result, hop table and state of the 28008 lines replays byte for byte.

## D119. FlySky receivers (2026-10-13)

The FlySky unit contains the FlySky receivers on an A7105 radio: AFHDS with eight channels and AFHDS
2A with fourteen. The CC2500 radio unit becomes the SPI radio unit, shared by both radios, and gains
what the A7105 needs: an id write, FIFO writes of up to 64 bytes, a discarded register read, a wait
for a register to clear, the interrupt flag reset, and the LED's link loss blink. Start-up resets
the A7105, writes its id and registers, starts its calibration and waits for it, then listens on the
bind channel, or on the stored map when bound.

The radio raises an interrupt when it finishes a transmission or a reception. The target shows the
interrupt flag and its time, the mode and RSSI registers and the receive FIFO on each call, and
clears the flag on each reset operation. After a strobe to receive or transmit the receiver takes
the next interrupt, and after any other strobe it ignores the flag. After a transmission the
receiver hops when bound and listens again. A reception with a good CRC is a packet, and any other
answer restarts reception.

Unbound, an AFHDS bind packet gives the transmitter id, which chooses one of 16 channel tables and
an offset. An AFHDS 2A bind packet gives the id and the channel map, and the receiver answers it 0.5
ms later with its own id. Binding completes 200 ms after the last bind packet and saves the id and
the map. Bound, a packet with the transmitter's id, and for AFHDS 2A the receiver's id, gives the
channels as two bytes each, updates a 16-sample RSSI average and hops on. AFHDS 2A answers a channel
packet with telemetry every 57 ms: battery voltage, RSSI and error rate, the full frame the first
time and its changing part after that. Without packets the receiver hops by the packet times missed,
and after 32 timeouts lengthens its timeout and drops the RSSI. The error rate is the number of
packets short of 100 in each period of 101 packet times. The RSSI conversion leaves 0 to 1023 at
both ends, and adaflight passes the values on as computed (F128). Unbound, AFHDS 2A reads 27 bytes
of a packet, and adaflight reads zeros for the rest where the reference copies unread bytes into
five channels (F129).

The harness replays eight sequences of 3000 calls, five AFHDS 2A and three AFHDS, recorded from the
reference with a scripted transmitter: bind packets with and without a channel map, channel packets
at the transmitter's period, failsafe and settings packets, wrong ids, failed CRCs and disabled
reception, transmit completions after the replies, dropouts, strong and weak signals, bind presses
and commands, and a clock near its wrap. Every operation, channel value, bind result, timer and
state of the 24008 lines replays byte for byte.

## D120. Spektrum SPI receiver (2026-10-13)

The Spektrum SPI unit contains the DSM2 and DSMX receiver on a CYRF6936 radio. The SPI radio unit
gains the CYRF6936's block writes, kept in a byte area of the output, and a write the target repeats
until the register reads it back. Start-up wakes the radio with that write, resets it, checks its
framing register and configures it. A radio that does not answer fails the start-up.

Unbound, the receiver listens for bind packets on channel 13 and moves two channels on every 11 ms.
A bind packet whose id repeats and whose two checksums agree gives the manufacturer id, the channel
count and the protocol, which the receiver saves. It then answers with 501 bind packets, one every
11 ms, and starts the transfer. The id gives the CRC seed and the code columns, and for DSMX the 23
hop channels from a linear congruential sequence, at most 8, 7 and 8 in its three bands. DSM2 steps
through the channels until it finds its two. Bound, a packet whose first two bytes match the id, as
sent or inverted by protocol, gives seven channel words, each naming its channel, and the receiver
hops on with the RSSI from the radio. Misses hop on with a timeout chosen by CRC seed and channel
count, and after 31 the receiver searches again. With the telemetry feature on, a packet on the id's
own seed is answered every 176 ms with the battery voltage and the RSSI percentage. A packet length
from the radio is taken up to 16 bytes with zeros for the bytes not read, where the reference reads
any length into a 16-byte buffer (F130).

The harness replays seven sequences of 3000 calls and one start-up with no radio, recorded from the
reference with a scripted transmitter for each protocol: bind packets with broken repeats and
checksums, two packets per 11 or 22 ms frame, receive errors with and without a bad CRC, short
counts, other ids, dropouts, bind presses and commands, the telemetry feature and a clock near its
wrap. Every operation, channel value, bind result, timer and state of the 21008 lines replays byte
for byte.

## D121. RC statistics (2026-10-13)

The RC statistics unit contains the statistics the OSD statistics page shows as full throttle time,
full throttle count and average throttle. Each update at 100 Hz takes the throttle percentage. Once
the throttle passes 15% after arming, each update while armed and out of crash flip counts a sample,
adds the percentage to the sum, adds the time since the last update while the throttle is at 100%,
and counts each new arrival at 100%. Arming clears only the raised flag, so the statistics run from
power-on across flights. The average is the float quotient of the sum by the count plus 0.5,
truncated. Before the first sample adaflight returns 0, and when 3D reverse throttle has wrapped the
unsigned sum it returns 127, where the reference conversions are undefined (F131).

The harness replays six sequences of 3000 updates recorded from the reference: flights with arming
and disarming, throttle ramps and holds at full throttle, crash flip, irregular update times, one
sequence with 3D reverse throttle and one with a clock near its wrap. Every count, sum, time and
defined average of the 18006 lines replays exactly.

## D122. MSP override in the receiver (2026-10-13)

The receiver takes its raw channels as floats, so a provider's fraction of a microsecond reaches the
channel ranges. The receiver unit adds the MSP override: the channels set for it and whether it may
stand in for a lost link. While any channel is set, every channel reads as a whole microsecond. A
channel that is set and fresh on the MSP receiver reads the MSP channel within the pulse limits when
the override mode is on, and the provider's channel otherwise. The reference truncates every channel
this way (F132). With the override mode on and the link setting on, a complete override frame counts
as a received frame in the frame check. The frame check reads the MSP receiver's override status
only then, since a read consumes it.

The receiver vectors gain eight sequences of 300 steps recorded from the reference with the override
compiled in: fractional pulses throughout, six with an override mask and random link settings, the
override mode switched on and off, MSP channels inside and outside the limits, random freshness and
override frame status. The 30 earlier sequences record byte for byte as before. Every value of the
11894 lines replays exactly.

## D123. Receiver task (2026-10-13)

The RX task unit contains the receiver task's state machine. One call checks the receiver, the next
updates the modes when the check found data, and the next updates the RC commands and the arming
status. The caller runs the step the unit names. Every step but the last tells the scheduler to
ignore the task's rate. Unless the scheduler ignores the call's time, the estimate of the step just
run takes the scheduler's anticipated time when that differs, then the execution time plus a
microsecond when that is longer, and otherwise decays by a 64th of a microsecond. The estimate of
the next step goes to the scheduler. The unit takes the scheduler's values as inputs and names its
outputs, so it stays independent of the scheduler unit, and the target joins them. An execution past
33 seconds counts as 33 seconds, where the reference's shift would overflow.

The harness replays four sequences of 4000 calls recorded from the reference task source with the
processing and the scheduler's hooks stubbed: random check results, execution times, ignored
execution times, anticipated times that echo the last estimate or change, and a clock near its wrap.
Every step, hook call, estimate and state of the 16004 lines replays exactly.

## D124. Barometer read cycle (2026-10-13)

The barometer task unit contains the barometer's read cycle. One call starts a temperature
conversion, the next calls read and sample it, and the same three steps follow for the pressure. The
pressure sample computes the altitude through the barometer unit and starts the cycle over, from the
pressure when the device reads both values at once. A start sleeps for the device's conversion
delay, and a restart sleeps for the rest of the 40 Hz period when the cycle was shorter. Other calls
sleep 1 ms. A read or sample the device has not finished keeps the phase and tells the scheduler to
ignore the call's time. A busy bus keeps the phase and tells the scheduler to ignore the state's
time. Every phase but the pressure start tells the scheduler to ignore the task's rate. The unit
keeps the longest execution of each phase without decay (F133) and names the next phase's to the
scheduler as a signed time delta, which wraps past 2 ** 31 microseconds. The caller makes the device
call the unit names and passes its answer, and after a finished pressure sample the device's
pressure and temperature. The unit is SPARK for its state machine and the time delta conversion.

The harness replays eight sequences of 2500 calls recorded from the reference barometer with the
device, the bus and the scheduler's hooks stubbed: separate and combined reads, a device without
temperature delay, slow pressure conversions, unfinished reads, a busy bus, invalid pressures, a
ground level reset, execution times past 2 ** 31 microseconds, and clocks that start at zero or near
their wrap. Every phase, device call, hook call, sleep time, estimate and barometer value of the
20008 lines replays exactly, with the altitude in the declared 3 cm tolerance (D6): 4 of 20000
altitudes needed it.

## D125. MSP state replies (2026-10-13)

The MSP out unit contains the replies that report the flight controller's state: the status and
extended status, the raw accelerometer, gyro and compass readings, the motor outputs, the RC
channels, the attitude as angles and as a quaternion, the estimated altitude with the vario, the
rangefinder altitude, the analog and battery state readings, and the debug values. The caller
gathers the state into a snapshot: the packed mode flags from the box unit, the arming disable
reasons, the sensors present, the profiles, the readings and the motor protocol's external values.
Each reply writes its fields in the protocol's order and width. Integers wrap to their field.
Readings and quaternion components round to the nearest integer with ties to even, and pulses
truncate. The battery voltage, drawn capacity and current saturate to their fields, and the load to
100%. The extended mode flag bytes follow the count of active boxes. Any other command writes
nothing. The unit is SPARK for the reply length, which stays within the 36 bytes of a full RC reply,
and for the conversions.

The harness replays eight sequences of 500 requests recorded from the reference MSP processor with
the target's accelerometer, motor, rangefinder, vario, internal ADC and I2C switches on and the
state it reads stubbed: random snapshots with values inside and outside each field's range, ties in
the readings, and channel counts from 0 to 18. Every result, length and byte of the 4008 lines
replays exactly.

## D126. MSP GPS, ESC and clock replies (2026-10-13)

The MSP out unit adds the replies for the GPS solution, the home vector and the satellites, the ESC
sensor data and the motor telemetry, the pitot readings, the transmitter information and the
real-time clock. The GPS solution reports the fix as the reference's state flag value 2 and the
altitude in whole metres saturated to 16 bits, and the home direction drops to whole degrees. The
satellite list holds up to 32 entries. The ESC data comes from the ESC sensor when that feature is
on, from the DShot telemetry otherwise, and without either the reply is an error. The motor
telemetry takes the rate from the DShot telemetry ahead of the ESC sensor, the invalid share as the
whole without an active motor, and the extended DShot values when the motor reported them, which the
ESC sensor's record then overrides. Rates round to the nearest integer with ties to even, and the
pitot readings truncate to 32-bit integers. The clock reply is empty while the clock is unset. The
caller gathers each source's values into the snapshot, the ESC sensor's rate converted to
revolutions per minute by the DShot unit. The longest reply is the satellite list at 129 bytes.

The harness replays eight sequences of 400 requests recorded from the reference MSP processor with
the target's GPS, ESC sensor, DShot telemetry, clock and pitot switches on and the state stubbed:
random solutions, home vectors and satellite counts up to 16 or 32, both telemetry sources on and
off, motor counts from 0 to 8, pitot readings near the 32-bit limits, every RSSI source, and a set
and unset clock. The ESC sensor's rate stays non-negative, since the reference sign-extends a
negative 16-bit value into its unsigned rate conversion. Every result, length and byte of the 3208
lines replays exactly.

## D127. BLHeli 4-way interface (2026-10-13)

The four-way unit contains the BLHeli 4-way interface that ESC configurators reach through the MSP
passthrough. A host frame is an escape byte, a command, a 16-bit address, a parameter length with 0
for 256, the parameters and a CRC-16/XMODEM. The reply repeats the command and the address and adds
the output parameters, the acknowledgement and its own check. The unit takes the host's bytes one at
a time, where the reference blocks in a loop on the port, and asks the caller for each bootloader
operation in turn with the selected ESC, the address, the count and the data. A connect tries up to
three times, each with the STK500v2 bootloader first unless the interface is in the ARM mode, then
the BLHeli bootloader, and keeps the first device whose signature matches an Atmel, SiLabs or ARM
part. The other commands read, write, erase and verify the flash and EEPROM through the bootloader
of the interface mode, set that mode, restart the ESC with an optional 300 ms low pulse on its pin,
and report the interface name and versions. A flash write in the power-on C2 mode replies OK without
a bootloader call (F134). Starting the interface stops the motors and takes the pins of the enabled
motors as the ESCs. The exit command hands the pins back and restarts the motors when every motor
took its pin back. The receive LED lights from the escape byte to the reply, the transmit LED from
the check to the end of the reply. The interface mode, the device information and the selected ESC
persist between sessions. The unit is SPARK for the 256-byte parameter buffer, the reply length and
the operation list.

The harness replays six sessions recorded from the reference interface with both bootloader
protocols on and the port, the pins, the motors, the LEDs and the bootloader calls stubbed: 120
frames each of every command with random addresses, lengths up to 256 and data, broken checks, stray
bytes between frames, scripted bootloader answers and device signatures, and one session without
ESCs. Every operation, bootloader call with its arguments, and reply byte of the 5530 lines replays
exactly. The host platform defines every pin configuration as 0, so the oracle gives the input,
output and alternate settings distinct values.

## D128. Gimbal control (2026-10-13)

The gimbal control unit moves a camera gimbal from a head tracker's frames and the sticks. The head
tracker's frames arrive on the gimbal port mixed with bytes for the gimbal, which pass through. A
frame is the opcode 16#5AA5#, the stabilisation mode and the sensitivity, the roll, pitch and yaw as
12-bit angles, and a CRC-16 CCITT sent high byte first. A valid frame goes on to the gimbal with its
angles scaled by the gains, the roll, pitch, yaw and throttle sticks added by theirs, the pitch
stick with separate gains below and above the centre, the offsets added, the limits applied, and the
configured mode and sensitivity. A frame with a broken check is dropped. After 250 ms without bytes
from the head tracker, each update sends the frame for the sticks alone. A byte after the first
opcode byte that is not the second goes on behind the held-back first opcode byte, where the
reference writes a byte 1, the value of a logical AND, in its place (F135). Without a configured
port the control asks for its task to stop. The sticks lie within the receiver's pulse limits, where
every sum of the reference's 16-bit arithmetic stays in range, and the integer scale truncates its
division as C does. The output holds twice the input and one frame, which no update exceeds. The
unit is SPARK for the 12-bit field packing, the scale arithmetic and the buffers.

The harness replays six sequences of about 1670 updates recorded from the reference with its
settings registered and the port and sticks scripted: default and random gains, offsets and limits,
valid frames, frames with broken checks, broken opcodes, passthrough bytes, gaps past the timeout, a
clock near its wrap, and a sequence without a port. The sticks start centred with the throttle at
its minimum, as the receiver leaves them before the gimbal starts. Every frame and output byte of
the 10061 lines replays exactly.

## D129. OSD custom text (2026-10-13)

The OSD custom text unit contains the text that a serial port sends for the OSD's custom text
element. A message ends with a line feed or a null as configured. Carriage returns are dropped, and
so are nulls when the line feed ends messages. The unit keeps the first 63 bytes of a message and
drops the rest up to the end of the message, and the text shows the first 31. An empty message
clears the text. Without a configured port the text stays empty. The port opening with its baud rate
default stays with the target. The unit is SPARK for the two buffers.

The harness replays six sequences of updates recorded from the reference source with its settings
registered and the port stubbed: messages from empty to 90 bytes with both terminators, carriage
returns, stray nulls and high bytes, unterminated messages, chunks of up to 50 bytes, and a sequence
without a port. Every text of the 5284 lines replays exactly.

## D130. PID audio (2026-10-13)

The PID audio unit plays the PID sum as a tone while its mode box is on. The output starts with
white noise when the box turns on and goes silent when it turns off. Each update with the box on
plays a tone from the roll sum, the pitch sum, or the mean of their magnitudes, as the mode the
in-flight adjustments select says: the magnitude up to 500, truncated to an integer, maps onto 63
down to 0 with the truncating integer division of C. The off mode plays the middle tone, 32. The
unit is SPARK for the tone range.

The harness replays four sequences of 3000 updates recorded from the reference with the audio
output, the box and the sums stubbed: the box toggled at random, the mode changed now and then
across all four, and sums with fractions, whole values near the limit and magnitudes up to about
3.75 million. Every call and tone of the 12004 lines replays exactly.

## D131. PINIO boxes (2026-10-13)

The PINIO box unit sets each of the four PINIO outputs to the state of the box that its setting
names by permanent id, looked up in the MSP box table at start. An unknown or unset id leaves its
output alone. The task runs while any assigned box has a mode condition. The caller computes the box
states with the box unit and drives the outputs. The unit is SPARK for the box lookup and the output
contract.

The harness replays six sequences of 1000 updates recorded from the reference with the box table for
the permanent ids and the box states, mode conditions, outputs and task switch stubbed: permanent
ids that name a box, unset ones, and unknown ones, with the states and conditions drawn at random.
Every assignment, output and task state of the 6006 lines replays exactly.

## D132. Warning LED (2026-10-13)

The warning LED unit holds the LED the arming status drives: off, on, or flashing. A refresh sets
the LED off, on, or toggles it, and sets the next refresh 500 ms later. An update refreshes once
that time has come, compared by the wrapping difference. The caller drives the LED. The unit is
SPARK for the wrapping time.

The harness replays four sequences of 3000 steps recorded from the reference with the LED calls
stubbed into a log and the clock scripted: mode switches at random, updates at intervals from none
to two seconds and around 500 ms, direct refreshes, and a clock near its wrap. Every LED call of the
12004 lines replays exactly.

## D133. NRF24L01 driver and V202 receiver (2026-10-13)

The NRF24L01 unit contains the radio driver the NRF24 receivers share. Register writes go out as SPI
commands with the write bit, address registers as block writes, the payload read and the FIFO
flushes as their commands, and the chip enable pin sets the standby, receive and transmit modes. The
power-up waits out the chip's 100 ms settling time from start before it writes the configuration,
then 4.5 ms. Register reads, the status and the FIFO status, are inputs the target supplies. The SPI
radio unit gains the chip enable pin and a delay longer than sixteen bits for that settling wait.

The V202 unit contains the V202 receiver. It takes 16-byte packets with a two-byte CRC on a fixed
address. Unbound, it hops the first row of the frequency table every millisecond and binds to the
first packet with both bind flags, whose transmitter id picks a table row and an offset for its
sixteen channels. Bound, a packet with that id gives the throttle, the three sticks in sign and
magnitude scaled onto 1000 to 2000 in integer arithmetic, four switches from the flag byte and three
from the mode byte. A bound receiver ignores bind packets and other ids. The receiver hops after
each packet, and after the timeout of 1 ms while binding or 10 ms once data arrives. The unit is
SPARK for the hop table and the channel scaling.

The harness replays six sequences of 2500 calls recorded from the reference driver and protocol with
the SPI commands, the chip enable pin and the clock stubbed: both data rates, a start inside the
settling time, a clock near its wrap, bind packets, data packets with the bound id and with
corrupted ids, bind packets after binding, and gaps that make the receiver hop. Every operation,
result, channel and binding state of the 15006 lines replays exactly.

## D134. SYMA receivers (2026-10-13)

The SYMA unit contains the SYMA X and X5C receivers on the NRF24L01. The X starts unbound on a fixed
address at 250 kbit/s and binds to a 10-byte packet with three bind marks, whose first five bytes
give its transmitter's address in reverse. The address's low five bits pick four hop channels,
computed as one 32-bit word stored low byte first. The X5C starts bound at 1 Mbit/s on its own
address and fifteen channels. Data packets give the throttle, the three sticks in sign and magnitude
scaled onto 1000 to 2000, a three-position rate, and four switches from the flag bytes. The receiver
hops every second packet and after 10 ms without one. The timeout compares a plain 32-bit sum, so
within 10 ms of the clock's wrap every call hops (F136). The X reads its headless switch from byte
14, which a 10-byte packet never writes, so the switch stays low (F137). The caller hands back the
receiver's buffer with the bytes a shorter packet leaves. The unit is SPARK for the hop table and
the channel scaling.

The harness replays six sequences of 2500 calls recorded from the reference driver and protocol with
the SPI commands, the chip enable pin and the clock stubbed, and the receiver's buffer static and
zeroed as on the target: both variants, bind packets with a scripted address, data packets, gaps
that make the receiver hop, a start inside the settling time, and three clocks near their wrap.
Every operation, result, channel, hop and address of the 15006 lines replays exactly.

## D135. XN297 payloads and H8_3D receiver (2026-10-13)

The XN297 unit contains the payload helpers for NRF24L01 receivers that talk to XN297 transmitters.
The unscramble works in place: each byte as received joins a CRC-16 CCITT that starts from 16#B5D2#
over the receive address in reverse, then is XORed with its scramble byte and bit-reversed. The CRC
takes a final value per length.

The H8_3D unit contains the H8_3D receiver. Unbound, it hops the bind channels 6 to 38 every
millisecond and binds to a packet with a good check, three bind marks and a checksum over its
transmitter id. The id picks four hop channels and, when the receiver's id setting is empty, becomes
that setting. A stored id at start binds at once. A data packet with a good check gives the four
sticks between their ends with the truncating division of C, a three-position rate, six switches,
the camera tilt and three trims, each wrapped to sixteen bits. The receiver hops after each data
packet and after 5 ms without one, and the timeout compares a plain 32-bit sum (F136). The unit is
SPARK for the hop channels, the channel arithmetic and the buffer.

The harness replays six sequences of 2500 calls recorded from the reference driver, XN297 helpers
and protocol with the SPI commands, the chip enable pin and the clock stubbed: a transmitter that
scrambles its packets with the reference's tables, bind packets with good and broken checksums, data
packets with the sticks inside and outside their ends, broken checks, gaps that make the receiver
hop, a stored id at start, a start inside the settling time, and two clocks near their wrap. Every
operation, result, channel, hop and stored id of the 15006 lines replays exactly.

## D136. Battery meter sources (2026-10-13)

`Adaflight.Battery` contains the ESC sensor, virtual and MSP meters beside the analog ones. The ESC
voltage meter runs the combined ESC reading through the display filter while the ESC sensor feature
is on and reads zero once the data is more than 10 sensor periods old. With the feature off the
voltage meter keeps its last values. The virtual current meter starts from its offset and, while
armed, adds the throttle factor times the scale over 1000. The factor is the mixer throttle in
thousandths, rounded with a tie going to the even one, plus its square over 50, or zero at low
throttle with motor stop on. Its charge accumulates as the analog meter's does (D6). The ESC current
meter adds a tenth of the configured offset to the combined current, and the offset's charge over
the millisecond clock to the consumption. That charge comes from a 32-bit unsigned product that
wraps after 268 s at 16000 mA (F139), and the unit forms the same product. The MSP meter reports the
current and the capacity of the last analog reply and asks for a new reply every 100 ms on the
wrapping microsecond comparison. The rounding helper sits in the unit, so its postcondition bounds
the throttle factor for the proof.

The harness replays six sequences of 2000 steps recorded from the reference voltage, current and
battery logic with the ESC sensor reading, the throttle, the arming flag, the MSP replies and the
cell count scripted: ESC meters with fresh and stale data, the ESC feature off, the virtual meter
with motor stop and a clock across its wrap, the MSP meter's requests, and a 16000 mA ESC offset
past the wrap of its charge product. The virtual meter's scale stays within 1000 and its offset
within 2000, and the generator checks that the reference's charge product stays in range. Every
meter field and request of the 12006 lines replays exactly.

## D137. Flash filesystem (2026-10-13)

`Adaflight.Flash_FS` contains the volume the flight log writes to on SPI flash. The volume starts at
the start of the flash and spans the filesystem partition. Bytes go into a 128-byte ring buffer that
holds up to 127 of them. Once 64 are in use, an asynchronous flush hands the buffered runs to the
flash as one page program at the tail address, trimmed at the page boundary as the flash layer trims
it, and the tail address and the ring's tail advance when the program ends. A byte past a full
buffer empties it and loses the buffered bytes. The erase takes the chip erase when one partition
covers a whole NOR chip and otherwise erases one sector per call, toggling the status LED, and turns
the LED off at the end. The search for the start of the free space reads the first sixteen bytes of
2048-byte blocks in a binary search and stops at a short read. A close puts the tail on the next
2048-byte boundary, after the flash's flush and the next page on NAND. Synchronous flushes, seeks
and reads wait for the flash before and after their program.

The unit hands the flash its operations in order, as the SPI receivers do: ready checks and waits,
page programs with their bytes, erases, reads, the NAND flush and the status LED. Each call takes
the flash's readiness as it stands at the call, where the reference polls the flash at every check.
A flash that completes a program inside the program call, as a bus without background transfers
does, ends the program at once. On a bus with background transfers the caller reports each program's
end between calls, and a synchronous flush ends its own program after its wait. The unit applies
every end the caller reports, where the reference's flash layer drops the end of a program still in
flight when an erase or a read starts (F140). A synchronous write needs a flash that completes
inside the call. The range erase has no caller and stays out, as do the test pattern and the verify
tool. The unit is SPARK for the ring indices, the trimmed program lengths and the search bounds.

The harness replays eight sequences of 1500 calls recorded from the reference flash layer and
filesystem over a stub chip whose memory is an array: NOR and NAND layouts, one partition and two,
completions inside the call and between calls, completions that arrive late so the buffer fills past
its end, a short read in the search, a nearly full volume, sector and chip erases, seeks and reads
past the end, and closes. The stub completes programs as the m25p16 driver does, is busy while a
transfer is in flight, and has each pending completion delivered before an erase or a call that
waits for one. Every operation, program byte, result and state field of the 12008 lines replays
exactly.

## D138. Flight plan storage and waypoint capture (2026-10-13)

`Adaflight.Flight_Plan` contains the stored plan: up to 30 waypoints with their position in 1e-7
degrees and centimeters, speed, duration, climb rate, type, hold pattern and yaw behaviour. The last
three stay the configuration's bytes, for the executor to check. `Adaflight.Flight_Plan_Capture`
contains the capture gesture on the capture switch. A press samples the GPS position while the
executor is idle and the fix is good. A release before 1.5 s appends the sampled point as a fly-by
waypoint or reports the plan full, and a hold of 1.5 s deletes the last waypoint once per press, so
a hold works on a full plan. Edits are refused while the executor flies the plan, and invalid
channels freeze the gesture with its press time. Each edit leaves its message, formatted with the
printf-style formatter, for 2.5 s on the wrapping microsecond clock, and the capture's step or the
OSD's read clears an expired one (finding F207, amended 2026-10-26 as declared in D6 and D232). The
reference shows the message on the OSD warnings line, which gains it here with the executor. The
unit is SPARK for the plan's bounds and the message buffer.

The harness replays six sequences of 2500 steps recorded from the reference capture with the plan,
the executor's activity, the fix, the position, the switch, the channel validity and the clock
scripted: short and long presses, signal losses during a press, an executor that starts and stops,
empty, nearly full and full plans, and a clock across its wrap. Every gesture state, plan count,
last waypoint and message of the 15006 lines replays exactly.

## D139. MAVLink mission protocol (2026-10-13)

`Adaflight.MAVLink_Mission` contains the MAVLink mission protocol over the flight plan, and
`Adaflight.Flight_Plan_Nav` contains the executor's orbit period it converts loiter turns with. A
ground station uploads a plan with a count and then each item on request. The unit asks for the
first item, for the next one as each arrives, and again after 1.5 s up to five times before it
cancels. Waypoints and splines become fly-by waypoints with their dwell. Loiter times, turns,
unlimited loiters, loiters to an altitude and follows become holds. The landing and takeoff forms
become landings and takeoffs, and altitude changes, delays and yaw speeds become the modifier types.
A return to launch in the last slot ends the plan. An item with a non-finite parameter, a position
out of range, an unsupported frame or a relative altitude without a home fix is refused with its
reason. The plan's count drops to zero when an upload starts and takes the received count, less a
final return to launch, at its end. A download answers requests for the next item or the one before
it, each stored item sent in the command of its type. A fence of up to 16 items is kept in memory
the same way, without enforcement. Uploads and clears of the plan are denied in the autopilot mode.
A set-current request goes to the executor, and the caller hands its answer back: the current item
report when it took the index, an error acknowledgement when not. The unit reports the current item
every second and each waypoint the executor reaches. Wire floats are decoded from their bits in
exact steps, so the unit stays SPARK, and altitudes beyond the 32-bit range saturate (D6). The unit
is SPARK for the payload offsets, the stores' indices and the float decoding.

The harness replays six sequences of 2500 steps recorded from the reference protocol with the
reference executor's orbit period: uploads and downloads of missions and fences with every item
command, faults in sequence, type, partner and target, non-finite parameters, bad frames and
positions, retries to cancellation, set-current answers, clears, autopilot denials and a clock
across its wrap. Every frame, request and state field of the 15006 lines replays exactly, with the
stored plan and fence compared through a hash.

## D140. Flight plan executor helpers (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the first part of the flight plan executor: the plan it flies
and the geometry its legs are built from. The plan is the stored mission or, while it holds
waypoints, an injected one of up to four. The next positional waypoint skips the modifiers, and a
fly-over or fly-by waypoint with another positional one after it, or one that faces its target,
flies a carrot along its leg. A waypoint's target comes from the GPS distance to the estimator's
origin, now public in `Adaflight.Position_Estimator`, with the altitude offset between the estimator
and the GPS frame. The braking deceleration at a lean of 10 to 70 whole degrees takes its tangent
from a static table of the correctly rounded single-precision values, which the C library's tangent
gives at every entry, so the unit needs no elementary function. The rest point, the carrot placed
within the controller's 5 m reach of the craft or of its rest point, the braking distance with a
turn-in's width, the navigation deltas, the bearing with its 2 m floor and the nose test keep their
operations in order. The angle wrap takes the remainder of the division by 360 by one exact
subtraction of the whole turns, which equals the C library's remainder over the inputs the executor
gives it. The pattern carrot is an orbit or a figure eight through the centre. The unit is SPARK for
the plan's indices, the table and the geometry's bounds. Each square root is held at a bound whose
square covers its input, as the core's other bounded roots are, so the hold never acts.

The harness replays 1200 calls of each group of helpers recorded from the reference executor with
random plans, waypoints, estimates, leg states and settings within the configuration interface's
ranges. Every result of the 9600 lines replays exactly.

## D141. Flight plan executor legs (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the second part of the executor: one cycle of a carrot leg. The
tracker reads back the carrot the navigation has walked and finds the next positional waypoint. The
corner speed comes from a constant velocity-change budget, and a point leg next lowers it to its
braking speed. The gate is the corner speed's radius on a fly-by and the arrival radius on a
fly-over. It is crossed at the waypoint, at the carrot where the leg turns, or past the waypoint
inside an 8 m corridor. Before the gate, the stall and flyaway checks judge the distance to the
waypoint: 30 s without closing by 2 m, or a fall back past a margin of 20 m to 100 m, aborts the
plan. The carrot marches along the leg line at a trapezoid speed keyed on the filtered along-track
distance and steers toward a point one lead ahead within the carrot acceleration, which goes to the
turn first. Its brake starts early by the distance the carrot covers in the craft's 0.5 s lag.
Through the approach the nose blends onto the next leg. A turn-in heads straight at the waypoint at
up to 4 m/s and releases its lean cap once the craft's course is within 15 degrees. A leg that
states its yaw holds the nose or faces its target or the next waypoint, and a face-the-target leg
waits until the nose has come round, for at most 10 s. The heading-fault detector reports a GPS
course 70 degrees off the nose for 2 s at speed while the nose is on the waypoint. Each cycle
returns its calls into the autopilot in order. The caller advances the plan on a crossed gate, which
is the executor's next part.

The unit is SPARK for the leg's bounds. Every cycle keeps the leg's points and the carrot within the
navigator's 2^18 m bound and the carrot's velocity within 1000 m/s in each component. Each
intermediate of the tracker has a stated range, and the steering, its turn, the corner speed and the
leg line are separate subprograms, so each proof runs in a small context. The leg's direction and
the steering aim are held within 2 in each component, which a unit vector never reaches, and the
carrot's velocity within 1000 m/s, which no cruise reaches, so no hold acts. The time a fault is
held saturates at 10^6 s, past the 2 s abort. `Adaflight.Maths.Atan2_Approx` now takes any finite
arguments: the turn-in's course test passes it products of the craft's velocity and its distance to
the waypoint.

The harness replays 120 scenarios recorded from the reference executor with its rescue plan compiled
in. Each sets up a carrot leg through the navigation's own calls, with a craft that follows the
commanded velocity or only drifts, a nose that turns toward the commanded heading at 90 degrees a
second, and a GPS course that follows the nose, off by a bias in some scenarios. Every state field,
autopilot call and commanded velocity of the 43076 steps replays exactly, and every line of the
executor's body runs.

## D142. Flight plan executor dispatch and landing (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the third part of the executor: the dispatch of a leg, the
arrival at a waypoint, and the landing. The dispatch walks past the modifier waypoints and stages
each for the next leg: an altitude override, a delay window, and a yaw rate cap the autopilot is
told of. The leg's target comes from the GPS distance, at the craft for a takeoff and at the craft's
resting point for the rescue's first stop. Its radius is the hold radius on a station-keeping
waypoint and the arrival radius, at most 12 m, on any other, and a rescue leg arrives at the descent
distance and brakes onto its point. A delay lowers the cruise to cover the rest of the leg in the
delay's time, never below 0.1 m/s. A carrot leg starts on the craft when it turns in, from the
carrot the leg before held the craft to, or from where the craft comes to rest at its speed along
the leg. A point leg goes to the navigator with its arrival and the executor's reached handler,
which the owner runs when the navigator reports the leg reached. A face-the-target point leg first
holds the craft where it is while the nose comes round. The rescue's first stop without a heading
starts the heading recovery's level climb.

On arrival the listener hears the stored plan's index, a station-keeping waypoint with a duration
holds, a landing waypoint lands at the leg's target, and the plan advances or completes. The
rescue's first stop without a heading pitches forward instead, or waits for the climb's drift to die
away. A landing descends at no less than 0.3 m/s toward a target kept 200 m below the craft. It
watches for touchdown once the descent is established, or once the craft has been below the landing
altitude for 5 s, and completes the plan with a disarm when the descent has stopped for the
touchdown time.

The navigator's command records whether its owner handles the arrival, in place of the reference's
callback. The executor's outputs became a list of the calls it makes out, to the autopilot, to the
arming, and to the reached waypoint's listener.

The harness replays 3000 calls recorded from the reference executor on random executor states,
navigator legs and plans within their ranges: half of them dispatches, a quarter arrivals, and a
quarter landings followed by up to 30 cycles of the touchdown watch. Every executor field, navigator
field and call of the 22175 lines replays exactly.

## D143. Flight plan executor update (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the fourth part of the executor: its cycle, its engagement and
the plans it takes. Each update takes its interval from the last, at most 0.25 s. The rescue's
heading recovery waits for the GPS course to stay within 5 degrees of the nose at speed for half a
second, or 2 s after the attitude trusts its heading, then turns in onto the next leg, and aborts
after 15 s without a heading. An idle executor dispatches again until the estimator has an origin,
and a leg the position controller lost is dispatched afresh. A landing runs its touchdown watch.
While a leg or a hold flies, an invalid estimate aborts, and past the geofence's distance from home
the executor returns home at the return altitude or lands in place. A delay's end restores the leg's
cruise. The rescue's blind climb keeps its target over the craft and pitches forward once the
climb's drift has died away or after 5 s. A leg runs nose control, swaps a nose hold for the real
target once the nose is round, flies a carrot or checks progress, and on a heading fault parks the
craft level and aborts. A hold counts time in per-update deltas, starts a pattern once arrival
braking has settled or after 5 s, advances pattern phase every 0.2 s, and on expiry lands or moves
on.

Engaging clears heading-fault park, nose command, modifiers and nose gate, captures altitude frame,
and flies a staged rescue plan or the stored plan from the waypoint a set-current chose while idle.
Disengaging drops plan and target. An injected plan of one to four waypoints replaces the stored one
while the executor is active, and a set-current moves the stored plan's current waypoint, or the
next engage's start while idle. Queries give distance and bearing in tenths of a degree to the
waypoint, and time to it at the craft's ground speed, at most 65535 s.

The harness replays 3600 calls recorded from the reference executor on random executor states,
navigator legs and plans within their ranges: half of them updates, the rest engages, disengages,
injections, set-currents and initializations. Every executor field, navigator field, call and query
of the 7200 lines replays exactly. Every line of the executor's body runs except three the reference
never reaches:

- landing in place when a return plan cannot be injected, which the update only reaches while the
  executor is active
- a point leg's progress check without a target, which the update dispatches afresh first
- orbit period saturation, beyond hold radius and cruise ranges

## D144. Flight plan executor rescue plan (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the last part of the executor: the failsafe rescue's plan. With
a GPS fix and home, the plan climbs where the craft comes to a stop, returns home and lands there.
Its altitude is the highest flown plus the initial climb, a fixed height above home, or the current
altitude plus the initial climb, and never below the craft. A craft that stops within the minimum
start distance of home lands where it stops instead, and gets no plan without a heading to hold that
point. The plan replaces one already flying at once, or waits for the next engage. Without a plan
the rescue descends on altitude alone: alt hold's emergency descent at the rescue's rate, with the
landing's touchdown watch and disarm.

The harness replays 1440 stagings and 960 descents of up to 32 cycles recorded from the reference
executor on random executor states, navigator legs, GPS fixes and settings within their ranges.
Every executor field, navigator field and call of the 21766 lines replays exactly.

## D145. Autopilot navigation modes (2026-10-13)

`Adaflight.Position_Control` contains the autopilot's three navigation modes over the navigation
target (D94). A target flown at a velocity its owner states is tracked as a moving anchor. A fixed
target is approached through a reference point, seeded where the position error stands, walked onto
the target at the navigator's velocity and held within 5 m of the craft in each axis. A target its
owner moves without a stated velocity is tracked from within 5 m until it is 7.5 m away and flown by
the navigator's velocity otherwise, and each new leg starts unanchored. Navigation takes up a leg
with the feedforward filters at the nominal interval, the distance error, its integral and the
target velocity's history dropped, and no braking. A heading recovery ends that continuity, so the
leg is taken up afresh after it. On a leg the distance error is held within 5 m, the integral stays
at zero, and a leg's own lean limit applies below the configured one. A leg whose velocity starts
from the craft's motion seeds the feedforward filters and the target velocity's history with the
current command, on the first task of navigation and on each new leg. Flying by velocity, the
damping and feedforward drive that builds speed is held to the configured buildup lean, and a drive
that sheds speed is left whole. On a leg the nose takes the override heading when one is set, and
otherwise follows the configured yaw mode. The velocity mode steers along the course over the ground
above the minimum forward speed and releases it below three quarters of that speed. The bearing mode
steers at the target outside its acceptance radius, or along a stated velocity above half a metre a
second. The hybrid mode steers along the course and falls back to the bearing. A rescue flown as a
plan leaves the rescue's own velocity mode to the navigation modes.

The navigator updates between the checks that fail a hold and the rest of the task, and a reached
leg's owner runs there, so a leg its owner replaces on arrival is flown on the same task.
`Begin_Step` and `Finish_Step` split the task at that point, and `Adaflight.Position_Hold` offers
the same split around its engagement and sensor checks. Its single `Update` finishes a reached leg
with no owner. The navigator's velocity is held at 2 ** 26 centimetres per second, the bound of the
controller's target velocity (D82).

The harness replays 16 flights of 900 tasks recorded from the reference autopilot and position hold
with the navigation module, 12 with the rescue flown by its own velocity and 4 with the rescue flown
as a plan: legs to fixed, moved and velocity-stated targets with every setter, an owner that issues
the next leg from inside the navigator's update on 18 of 31 arrivals, retargets, clears, nose
overrides, sticks, heading recoveries, level parks, estimate dropouts and rescue windows, in every
yaw mode. Every controller field, navigator field, lean and yaw rate of the 14416 lines replays
exactly.

## D146. MSP identification and meter replies (2026-10-13)

`Adaflight.MSP_Common_Out` contains the MSP out messages every MSP host answers: the protocol and
API versions, the firmware variant and calendar version, the MCU name, the board information, the
build information with its option codes, the unique id, the feature and beeper configuration, the
voltage and current meters, the analog voltage sensors, the analog and virtual current sensors, the
battery and transponder configuration, and the OSD canvas. The board information covers the target's
capabilities, names, signature, configuration state, gyro rate, configuration problems and bus
device counts. The version reply leaves out the version text for a request from the port an HD video
transmitter shares. The caller gathers the firmware's identity, the target's options, the
configuration and the meter readings into a snapshot, so the replies hold no identity of their own.
With the ESC sensor built in, both meter replies leave out the per-motor slots past the motor count.
The current meters keep the reference's trim, which drops the MSP meter when that meter is built as
well (findings F141). A displayed voltage rounds to tenths within a byte, consumption and current in
milliamperes saturate at the field's range, and the year since 2000 and the cell voltages in tenths
wrap to a byte. The beeper configuration reply exists only with the beeper built in.

The harness replays 4800 requests recorded from the reference MSP processor in two builds, one with
every option the replies branch on and one without, on random identities, configurations and meter
readings. Every result, length and byte of the 4808 lines replays exactly.

## D147. MSP tuning replies (2026-10-13)

`Adaflight.MSP_Tuning_Out` contains the MSP out messages that report the tuning: the PID gains with
their names and controller, the rate profile, the advanced configuration, the filter configuration,
the advanced PID configuration, the board and sensor alignment, the arming configuration, the 3D
throttle and the stick deadbands. The caller gathers the active PID and rate profiles, the gyro,
filter, motor and system configuration and the build's options into a snapshot. Each value keeps its
configuration width and the reply narrows it to the protocol's field: the first gyro cutoff wraps to
a byte, the board alignment in degrees wraps to sixteen bits, and the signed gyro yaw offset,
compass alignment and profile cell count wrap to their fields. A value whose option is left out of
the build goes out as zero. Retired fields keep their place in the layout and go out as zero, or one
for the retired gyro sync divider.

The harness replays 4800 requests recorded from the reference MSP processor with the reference PID
names, in a build with every option the replies branch on and one without, on random profiles and
configurations. Every result, length and byte of the 4808 lines replays exactly.

## D148. MSP receiver and mode replies (2026-10-13)

`Adaflight.MSP_Receiver_Out` contains the MSP out messages that report the receiver and the
switches: the mode ranges, their logic and links, the adjustment ranges, the receiver configuration,
the failsafe configuration, each channel's failsafe, the RSSI channel and the channel map. The mode
replies name each box by its permanent id from `Adaflight.MSP_Box`, and a channel's failsafe step
goes out as its pulse, 750 microseconds and 25 more per step. The caller gathers the configured
conditions and ranges, the receiver and failsafe settings, the runtime channel count and the build's
options into a snapshot. The SPI receiver's settings, RC smoothing, the USB device type and the
ExpressLRS binding go out as zero when their option is left out of the build, and the retired fields
keep their place as zero.

The harness replays 4800 requests recorded from the reference MSP processor with its box table, in a
build with every option the replies branch on and one without, on random configurations within their
ranges. Every result, length and byte of the 4808 lines replays exactly.

## D149. MSP hardware replies (2026-10-13)

`Adaflight.MSP_Hardware_Out` contains the MSP out messages that report the hardware configuration:
the mixer, the motors, the compass declination, the GPS receiver, the GPS rescue and its gains, the
accelerometer trims, the flight log, the sensors selected and detected, the gyros detected, and the
flash and SD card storage. The caller gathers the configuration, the recorder's rate divider and P
ratio, the sensors detected, the storage state and the build's options into a snapshot. The compass,
GPS, rescue and trim replies exist only with their option built. A sensor left out of the build
reports its hardware selection as none and its detection as 16#FF#. The flash summary counts the
partition's sectors from its first and last, and the SD card summary merges the card's presence and
health with the file system's state, giving the free and total space in kilobytes once the card is
ready.

The harness replays 4800 requests recorded from the reference MSP processor, in a build with every
option the replies branch on and one without, on random configurations and storage states. Every
result, length and byte of the 4808 lines replays exactly.

## D150. MSP peripheral replies (2026-10-13)

`Adaflight.MSP_Peripheral_Out` contains the MSP out messages that report the peripherals: the servo
outputs, the servos' configuration and mix rules, the motor output order, the LED colors, the LED
strip and its mode colors, the video transmitter's configuration, and the wing's tuning. The caller
gathers the outputs, the configuration, the transmitter's state, the target's servo count and strip
length, and the build's options into a snapshot. Signed values wrap to their fields. The servo, LED
and transmitter replies exist only with their option built, and a strip built without its status
mode reports every LED as zero. The transmitter's type, pit mode and readiness come from its device
when one is present. The reply for the MSP transmitter's own port also marks that transmitter ready,
and that call stays with the caller.

The harness replays 4800 requests recorded from the reference MSP processor, in a build with the
servos, the 64-LED strip with its status mode and the transmitter with its table, and one without
them, on random outputs, configurations and devices. Every result, length and byte of the 4808 lines
replays exactly.

## D151. MSP text, table and battery profile replies (2026-10-13)

`Adaflight.MSP_Text_Out` contains the MSP out messages that answer with text, a table row or a
profile: the craft name, a text by its type, a video transmitter band or power level from the
frequency table, the LED strip's brightness and rainbow, and a battery profile. The request's first
byte selects the text type, the band, the level or the profile, and the profile falls back to the
active one without it. An unknown text type, a text the build leaves out, a band or level outside
the table and a profile beyond the third are errors that write nothing. The caller gathers the
names, the build key and release name, the battery profiles, the strip settings and the table into a
snapshot. The table replies exist only with the table built and the strip values only with the
strip. A band or level reply to the MSP transmitter's own port also marks that transmitter ready,
and that call stays with the caller.

The harness replays 4800 requests recorded from the reference MSP processor with the reference build
strings, in a build with the table, the strip, a build key and a release name, and one without, on
random names, profiles, tables and request bytes. Every result, length and byte of the 4808 lines
replays exactly.

## D152. Simplified tuning filter sliders (2026-10-13)

`Adaflight.Simplified_Tuning` contains the filter sliders beside the gain sliders. With the D term
filter slider on, each D term lowpass cutoff in use is set from its default through the slider in
percent: the dynamic range from 75 and 150 hertz, the first static cutoff from 75 and the second
from 150, each held to 1000 hertz. The gyro filter slider does the same for the gyro lowpass filters
from 250 and 500 hertz. A cutoff that is off stays off. Apply runs the gains, the D term filters and
the gyro filters in that order, and Disable turns every slider off.
`Adaflight.Gyro_Filters.Settings` gains the gyro filter slider and its multiplier. The dynamic
range's ends are written in the order that keeps the lower end at or below the upper end at every
step, the invariant the profile and gyro settings state.

The harness replays 6000 calls recorded from the reference simplified tuning on random profiles and
gyro configurations within their ranges, each applying one slider set or turning the sliders off.
Every gain, cutoff and flag of the 6000 lines replays exactly.

## D153. MSP simplified tuning messages (2026-10-13)

`Adaflight.MSP_Simplified_Tuning` contains the MSP messages of simplified tuning: slider read with D
term and gyro cutoffs, gains, D term filters or gyro filters computed from a requested slider set
without storing them, validation of gains, gyro filters and D term filters against their sliders,
and an in message that stores a slider set with its cutoffs and applies every slider. A request
reads zero past its end. A request with a field outside its setting's range is an error that writes
and changes nothing: mode beyond roll, pitch and yaw, gain slider above 200, filter switch above
one, filter multiplier outside 10 to 200, cutoff above 1000 hertz, or dynamic range with its lower
end above its upper end (D6). The in message checks the whole request before it stores anything.
Dynamic range ends are written in the order that keeps the lower end at or below the upper end at
every step.

The harness replays 4800 requests recorded from the reference MSP processor on random profiles and
gyro configurations, about a third of them already at their sliders' result, with requests within
their ranges, short, long, or with one field outside its range. Every result, length, reply byte and
setting of the 4025 requests within their ranges replays exactly, and each of the 775 outside them
is an error that leaves the settings unchanged.

## D154. MSP OSD replies (2026-10-13)

`Adaflight.MSP_OSD_Out` contains the MSP out messages of the OSD: configuration and warnings line.
The configuration reply holds OSD flags from the display device's type and readiness, video system,
units, alarms, element positions, statistics enabled, timers, warnings enabled as low half and full
mask, profile count and selection, stick overlay mode, camera frame, and link quality and RSSI dBm
alarms. A reply to the MSP display port's own serial port keeps the layout of the first 80 elements
without the RSSI dBm alarm. A build without the video system, profile or stick overlay options
reports the HD video system, one profile selected, or overlay mode zero. The warnings reply gives
the line's severity with the blink bit and the line as a length-prefixed string. The element set is
the 89 items of D102. The caller gathers the settings, the display device's type and readiness and
the rendered warnings line into a snapshot.

The harness replays 4800 requests recorded from the reference MSP processor, in a build with the
video system, profiles, stick overlay, MSP display port with its font and frame buffer OSD and one
without, on random settings, devices and warnings lines. Every result, length and byte of the 4808
lines replays exactly.

## D155. Serial feature map (2026-10-13)

`Adaflight.Serial_Feature_Map` contains the map between the features that name a serial port in
their own settings and the per-port view of function bits and baud rates: a port's function bits and
its baud rate of a class from the features naming it, the claims on a port with their setting names,
a function mask applied to a port, a baud rate applied to a port's features of a class, implied MSP
ports, port conflict rule, configuration check and its fix. Applying a mask clears every claim on
the port first, and changes nothing when the mask asks for two VTX protocols or for more MSP or
telemetry slots than are free. A port's functions conflict when MSP or a serial receiver is on a
soft serial port, when an MSP VTX is alone on its port, or when shared functions are neither MSP
with functions that share with it nor a serial receiver with the telemetry of its link. The fix
drops every claim but MSP on each conflicting port and, when the assignment is still invalid, clears
every claim and puts MSP on the target's first port at its default baud rate. The build's features,
telemetry protocols and soft serial ports come in as options, with one telemetry slot per protocol
built, at most three. The rangefinder's and optical flow's hardware enter as whether they talk MSP.

The harness replays 4800 operations recorded from the reference feature map, conflict rule, port
types and telemetry port sharing check, in a build with every feature that names a port and one
without the ESC sensor, RC device, gimbal, Tramp and MSP VTX, rangefinder, optical flow, MSP display
port and MSP over telemetry, on random assignments, half of them sparse. Every function mask, claim,
baud rate, conflict, check result and assignment of the 4808 lines replays exactly.

## D156. MSP serial port replies (2026-10-13)

`Adaflight.MSP_Serial_Out` contains the MSP out messages of the serial ports in the legacy and the
common layout: each available port's identifier, an empty function mask and its baud rate of each
class from the serial feature map (D155), with the common layout led by the count of available ports
and holding a 32-bit mask. Port functions live in the features' settings and the command line shows
them, so both layouts give an empty mask, which an older configurator reads as an unassigned port.
The caller gives the target's ports with their availability, which the serial layer's initialization
and port removals decide, the build's options and the feature assignments in a snapshot.

The harness replays 4800 requests recorded from the reference MSP processor with the reference
feature map and serial layer linked, in the full and the reduced build of D155, on random
assignments with soft serial on or off and random ports removed. Every result, length and byte of
the 4808 lines replays exactly.

## D157. MSP transmitter device status (2026-10-13)

`Adaflight.MSP_VTX_Status_Out` contains the MSP out message of the video transmitter's device
status: device type and readiness, band and channel, power index, frequency and status with whether
the device knows each, power levels in decibel-milliwatts and milliwatts, and the device's own
status block. The values come from the driver of the device in use, SmartAudio (D84), Tramp (D86) or
MSP (D98), and a value the device does not know goes out as zero. The status has the pit mode bit
and, for Tramp, the race lock bit. SmartAudio reports its own power levels from version 2 on, the
MSP device reports the table's, and Tramp reports none. Only SmartAudio has a status block of its
own: version, mode, pit mode frequency and boot flag. The others send a zero length. Nothing goes
out without a device. The RTC6705 driver is not ported, so its device does not appear.

The harness replays 4800 device states drawn into the reference common transmitter layer and its
SmartAudio, Tramp and MSP drivers, with random frequency tables, each step making one device current
or none. Every length and byte of the 4808 lines replays exactly.

## D158. Configuration storage image (2026-10-13)

`Adaflight.Config_Store` contains the storage image of the parameter groups: header with storage
version 178 and magic byte, one record per group with its size, group number, version and class,
zero terminator, and the CRC over all of it, inverted and big-endian, so the CRC of the whole image
is a constant. The structure check scans the records to the terminator, each record at least its own
header long and ending before the region does. Lookup finds a group's first record of a class with
the same scan. Loading resets every group to its defaults, takes its stored bytes when a system
record has the group's version, as many as the group holds, and hashes each group with FNV-1a.
Saving writes only when the image's version or structure is invalid or a group's bytes no longer
match its hash. It zeroes the region, as the reference's RAM storage does, then writes header,
records, terminator and CRC. Each group's bytes are adaflight's own layout, so an image the
reference writes does not load. Bytes past the region read as erased and an image longer than the
region is not written (D6).

The harness replays 4800 operations recorded from the reference storage code over a 512-byte RAM
region with six parameter groups: structure checks, lookups, loads and saves on images built from
random records, about a third of them clean and the rest often corrupted, never one whose scan reads
past the region. Every result, group, hash and image byte of the 4808 lines replays exactly.

## D159. Mixer setup (2026-10-13)

`Adaflight.Mixer_Init` contains the mixer setup:

- each mixer mode's motor count, whether it drives servos, and its motor table where the build has
  it
- the motors in use and their mix, from the mode or, for the custom modes, from the custom table up
  to its first entry without throttle, at most the build's motors
- the launch control mix, which holds every motor that pitches the nose up at zero
- disarmed outputs reset to the disarm value
- a mode's table loaded into the custom table for the command line
- whether the motors run or saturate

The modes keep the configuration's order, from tri to octo X8 plus. The build's options select quad
X only, the uncommon frames, the motor count and launch control. A mode whose table the build leaves
out keeps the previous mix for its motor count, as the reference does (findings F144). The motor
mixer (D16) takes the count and the mix.

The harness replays 4800 setups recorded from the reference mixer setup, in a build with every
frame, launch control and 8 motors, one without the uncommon frames and launch control for 6 motors,
and one for quad X only, on random previous and custom mixes and outputs. Every count, flag and
weight of the 4808 lines replays exactly.

## D160. Task setup (2026-10-13)

`Adaflight.Task_Init` contains the task setup over the scheduler's task table: which tasks run from
boot and at what period, from the build's options, the features, the sensors detected and the
settings. The serial task takes its update rate, the voltage task the fast rate with sag
compensation, the gyro, filter and PID tasks the gyro's sample and loop periods, the accelerometer
task its sample rate, the telemetry task 500 hertz on a Jeti Ex Bus or CRSF receiver, and the OSD
task its frame rate. The battery alert task runs with a meter and an alert or the OSD, the position
task with any measurement source, the hold tasks with their sources, and the menu task with the MSP
display port or the OSD or dashboard. The heading hold task follows the compass and a heading mode
on a switch, and is set again whenever the modes change. The caller gives the PINIO box task's
state, which `Adaflight.PINIO_Box` decides.

The harness replays 4800 setups recorded from the reference task setup and scheduler, in a build
with every task but BST, whose bus header the host build lacks, and one without pitot, stack check,
speed negotiation, DroneCAN, custom OSD text, sag compensation and the MSP display port, on random
boot inputs, a third of them followed by a mode change. Every task's enable and period of the 4808
lines replays exactly, on the oracle platform's floor of 1 microsecond and gyro period of 100 (D38).

## D161. CX10 receivers (2026-10-13)

The CX10 unit contains the CX10 and CX10A receivers on the NRF24L01 with XN297 payloads. The
receiver listens on bind channel 2 for a packet with a good check and the bind mark 16#AA#, whose
transmitter id picks four hop channels. It then answers the transmitter in nine calls. Each answer
sends the received packet with byte 9 set to 1 on the bind channel and on each hop channel, waits
for every send to leave the transmit FIFO, and waits out the rest of 1 ms. Bound, a packet with a
good check gives the four sticks, a three-position rate and four switches on nine channels. The
CX10A packet holds them four bytes later. The receiver hops after each packet and after 1.5 ms
(CX10) or 6.5 ms (CX10A) without one, and the timeout compares a plain 32-bit sum (F136). The unit
is SPARK for the hop channels, the channel arithmetic and the buffer.

The SPI radio unit gains two operations for the answers: a register wait with a delay after each
read that finds the bits clear, and a delay for what remains of a period after those waits. The
NRF24L01 unit gains the payload write, and the XN297 unit the payload as an XN297 transmitter sends
it, scrambled after the reversed address and followed by its CRC.

The KN receiver stays out: its start-up reads the protocol setting from the receiver configuration
instead of the SPI receiver configuration, so no reference build compiles it (F145).

The harness replays twelve sequences of 1250 calls recorded from the reference driver, XN297 helpers
and protocol with the SPI commands, the chip enable pin and the clock stubbed: both variants, a
transmitter that scrambles its packets with the reference's tables, bind packets with and without
the mark, broken checks, sticks with the flag bit set, gaps that make the receiver hop, a late bind,
a start inside the settling time, and four clocks near their wrap. During the 108 answers, each wait
finds the FIFO full a scripted number of times, so 88 answers wait out the rest of 1 ms, 10 use
exactly 1 ms and 10 use more. Every operation, result, channel, hop and id of the 15012 lines
replays exactly.

## D162. Acknowledgment payload receiver (2026-10-13)

`Adaflight.Ack_Payload_Receiver` contains the remaining NRF24 receiver, the one that uses the
radio's automatic acknowledgments. The reference names it after another firmware project. As with
the rate curve families (D2), the unit takes the name of what sets it apart: the radio answers each
packet with a payload the receiver queued. Unbound, the receiver listens on channel 76 at a fixed
address for a packet with the two bind marks. It queues the bind reply, the packet with two reply
marks, the hop count and the payload size, takes the transmitter's address from the packet with four
hop channels from its first byte, and goes to data. A data packet gives the four sticks and four
auxiliary channels at ten bits, a three-position rate, five switches and two eight-bit channels on
eighteen channels. The last two stay zero. A bind packet while bound queues the bind reply again.
The receiver hops after each data packet and after 5 ms without one, and the timeout compares a
plain 32-bit sum (F136). Every start binds anew, and a bind never stores the address (F147). The
data acknowledgment payload stays empty, and the received power is read and dropped (F148). The unit
is SPARK for the hop table and the channel arithmetic.

The NRF24L01 unit gains the acknowledgment payload write, the activate command, a register read
whose value goes unused, and the feature register.

The harness replays twelve sequences of 1250 calls recorded from the reference driver and protocol
with the SPI commands, the chip enable pin and the clock stubbed: bind packets with and without both
marks, bind packets that continue after the bind, data packets, gaps that make the receiver hop, a
start with an id setting, a late bind, sparse packets, a start inside the settling time, and four
clocks near their wrap. Every operation, result, channel, hop and address of the 15012 lines replays
exactly.

## D163. Settings table (2026-10-13)

`Adaflight.Settings_Table` contains the command line's 789 settings in the reference's table order:
each one's name, value type, scope (master, PID profile, rate profile, hardware, battery profile)
and mode (a direct value with its range, a lookup, an array, a bit, a text, a serial port
identifier) with its limits, and the parameter group that holds it. The unit also contains the 72
lookup tables of value names. A local tool generates the unit from a settings oracle: the
reference's settings table and parameter group sources built for the host with the option set of an
STM32F405 board and the options of the features adaflight implements beyond it (acro trainer, 3D
speed, chirp, Galileo, gimbal, GPS lap timer, pitot with its MS4525 driver, the flight plan, the MSP
current meter, PID audio, the UPT1 optical flow and two soft serial ports). Names and lookup strings
are verbatim (D2). A lookup entry the build leaves out, a driver compiled away, has an empty name,
which the command line skips. The values, their defaults and the groups' records follow in the next
steps of the configuration layer, and the hardware settings wait for Phase 7. The unit is SPARK at
no cost, and its lookups prove in range.

The harness compares every setting's name, type, scope, mode, limits and group, and every lookup
table's count and names, with the oracle's dump. All 789 settings and 72 tables replay exactly.

## D164. Configuration groups (2026-10-13)

`Adaflight.Config_Groups` contains the configuration as a record per parameter group of the settings
oracle's build (D163): 101 groups, from the system, feature and arming settings through the PID,
rate and battery profiles, the mode and adjustment ranges, the mixers, the OSD, the telemetry and
the flight plan, to the hardware groups of buses, pins and DMA. A local tool generates the 110
record types from the reference's group types as the oracle's debug information describes them. Each
field keeps its C type's width and sign, a union keeps its array member, and a character array is
bytes. The record layout is adaflight's own, and the codecs to the storage image (D158) follow.
`Defaults` holds the reference's reset values, read from the oracle's groups after a reset of all of
them, so the hardware groups hold the values of a board without pins.

`Get` gives a setting's value in a configuration as the reference's command line reads it: the
setting's own type over the field's bytes, a bit setting's bit, an array setting's element, a
profile setting's profile. For 13 settings the setting's type differs from the field's in sign, and
for 7 the field is wider than the setting's type, so only its low bytes are read. No setting's range
holds a value outside the field's type. `Get_Text` gives a text setting's characters before the
first zero. Writing values follows in the next step. The unit is SPARK for the profile and element
indexing.

The harness compares every setting's default through `Get` and `Get_Text` with the oracle's dump.
All 789 settings replay exactly.

## D165. Writing settings (2026-10-13)

`Adaflight.Config_Groups` gains `Set`, which writes a setting's value as the reference's command
line writes it: the value truncated to the setting's type as a C assignment stores it, into the low
bytes alone of a field wider than the type, a bit setting's bit, an array setting's element, a
profile setting's profile. Of the 19 settings whose type and field differ in width in the
reference's structs, the board alignment angles show what the partial write does: a negative angle
stores 65536 minus its size (F149). `Lowest` and `Highest` give the values a setting's type holds,
and a value between them reads back unchanged. The range a setting accepts, the lookup by name and
the texts belong to the command line and the MSP commands that call `Set`. Each group has its own
writer, which keeps each writer's proof small. The unit is SPARK for the indexing of profiles and
elements.

The harness replays four sequences of 1500 writes recorded from the oracle from the reset
configuration, each setting, profile, element and value at random within what the setting's range or
type allows. After each write the setting reads back the written value, and a weighted sum over
every value of every setting but the texts matches the reference's, so no write touches another
setting. All 6000 writes replay exactly.

## D166. Configuration bytes (2026-10-13)

`Adaflight.Config_Codec` contains the configuration as bytes in adaflight's layout: every field of
every parameter group in declaration order, little-endian, without padding, and the groups one after
another, 4591 bytes for the settings oracle's build. `Registry` gives each group's number, version,
offset and size for the storage image (D158), whose image of all groups is 5203 bytes. `Encode`
writes a configuration's bytes and `Decode` reads them back into the groups. A local tool generates
both from the group records of D164. `Groups_Within` proves that every group lies inside the data,
which the storage image's load and save require. The specification is SPARK and the body is not:
every offset is a constant and every encode and decode runs every statement, so the vectors show
what a proof of the body would, and the proof of the PID profile's record alone ran for over 20
minutes without finishing.

The settings oracle lays out the reference's groups the same way, from a leaf table the tool writes
with the unit. The harness compares the reset configuration's bytes with the oracle's in full, then
replays the four sequences of setting writes of D165 and compares an FNV-1a hash of the bytes after
each write. It also takes each configuration through its bytes and back, and the reset
configurations and every 250th write through a saved and loaded storage image as well. All 6004
encodings match, and every configuration comes back equal in every field.

## D167. Configuration fix (2026-10-14)

`Adaflight.Config_Fix` contains the checks a configuration passes after every load and before every
save, in order: unsupported mixer modes to a custom mode, telemetry protocols repeated in a later
slot dropped, conflicting serial ports cleared through the serial feature map (D155), filter cutoffs
past 1000 hertz and notches above their cutoff reset, receiver features reduced to one, linked mode
chains and the GPS rescue mode without GPS taken out, DShot settings the protocol or timers cannot
run reset, PID loop slowed to the motor protocol's update rate, profile selections past their counts
back to the first, rates held to their type's limits, and battery voltages out of order back to
their defaults. `Fix_Gyro` is the gyro's part alone, which also runs once the gyro's sample rate is
known and after the MSP advanced and filter configuration writes.

Hardware inputs: gyro sample rate, motors in use, timer behind each pin and board's serial ports.
The runtime feature mask is a parameter: a load starts it from the configuration's features, a save
passes the running mask, and the ADC's RSSI channel follows it. The results name the serial port the
MSP display port draws over and the GPS port taken out of use, for the caller to apply to the
running ports. A port setting outside the serial map's identifiers stands for a port the board does
not have, and a port setting changes only where the serial check changed it.

Three inputs make the reference read past a table or shift past a word: a mixer mode past 27 (F150),
a rates type past 4 (F151) and an MSP override condition's aux channel past 27 (F152). adaflight
leaves such a mode and such rates as they are and takes such a channel to name no bit (D6). Sensor
alignment codes past the custom one wrap onto the eight standard alignments.

Each check is a procedure over the groups it reads and writes, SPARK for the indexing of the mode
conditions, the shifts of the override mask, the conversions of port settings and of the PID loop
ratio, with postconditions for the filter cutoffs, motor output limit, cell count and battery
voltage order. The body of `Fix` is outside SPARK. It contains only the calls that pass each group
of the configuration to those procedures. gnatwhy3 grew past 2 GB for over three minutes without
starting a prover on a body that passed the whole configuration to five calls. With that body
outside SPARK the unit proves in under a minute.

The harness replays 4000 configurations the oracle runs through the reference's fix: the reset
configuration after up to 40 random setting writes and direct changes to the fields the fix checks,
with a gyro rate from none to 9 kHz, zero to eight motors and a timer kind for each pin. Each input
is decoded from its bytes, fixed, and compared on changed bytes, an FNV-1a hash of the output, MSP
display port and GPS port taken out of use. All 4000 match exactly: 3998 change the configuration,
201 name a display port and 52 take a GPS port out of use.

## D168. Command line get and set (2026-10-14)

`Adaflight.Command_Line` contains the command line's line handling and its `get` and `set` commands
over the configuration's settings. A line keeps its printable characters past the leading spaces, up
to 255 of them, loses a comment from the first number sign and its trailing spaces, and names a
command by its first word without regard to case. `get` lists every setting whose name contains a
fragment without regard to case, with its value, its profile for a profile setting, its allowed
values and its default where the value differs. `set` lists every setting, with each direct
setting's range after an asterisk, or reads a value for the setting named before an equals sign: a
decimal number within the setting's range, a lookup or bit name without regard to case, a serial
port name, numbers between commas for an array, or a text. A value a stored configuration holds
outside its setting's range prints with a corrupted configuration error.

The unit is the core's first generic. Its text goes out through a formal `Put` into a sink, which
the harness points at an unbounded string and a target will point at its serial port.
`Adaflight.Reply_Command_Line` instantiates it over a reply record of 4096 characters, through which
the generic's body is proved. `Adaflight.CLI_Text` contains the decimal numbers as the command
line's C library reads them on a 32-bit target, held at the 32-bit range, the comparisons without
case, and the board's serial port names. `Config_Groups.Set_Text` writes a text setting, and the
settings table's direct limits are bounded to the 32-bit types.

A comment is cut from the line and the buffer behind the cut is cleared, so a command word followed
directly by a comment has no arguments and `get#motor_pwm_rate` prints every setting. The reference
leaves the comment's text behind the terminator, where its command matcher reads it as the arguments
(finding F153, amended 2026-10-26 as declared in D6). On the oracle's 64-bit host the C library
reads a number past the 32-bit range by its low 32 bits, where a 32-bit target holds it at the
range. adaflight follows the target. The recorded numbers stay within the range, where the two
agree.

The harness replays two sequences of command lines, 7582 in all, recorded from the oracle, which
runs the reference's command line over the settings oracle's configuration: get of every setting,
then random gets of name fragments, and sets with values inside, at and past each setting's range,
names in mixed case, array and text values, spacing and comment variations, profile selections and
values stored past their range. Every reply matches the reference's byte for byte, 576301 bytes in
all, and so does the configuration's hash after every command.

## D169. Command line profiles, dump and diff (2026-10-14)

`Adaflight.Command_Line` gains the `profile`, `rateprofile` and `battery_profile` commands and the
profile and rate sections of `dump` and `diff`. A profile command without arguments prints the
selected profile, and with a number in range selects it and reports the runtime work it asks for:
the selected PID, rate or battery profile changed. A number out of range is an error. `dump profile`
and `dump rates` print the selected profile's or rate profile's settings as set lines under a
heading, `diff` prints only those off their default under a heading printed with the first of them,
and the option `defaults` adds each changed setting's default as a commented set line. The other
sections of `dump` and `diff` come with the commands they print.

The line's command words are read from the line buffer by position, and the buffer behind a comment
cut is cleared, so an option a comment cut off does not apply: `dump profile#defaults` dumps without
defaults (finding F153, amended 2026-10-26 as declared in D6).

The harness replays two sequences of 2500 command lines recorded from the oracle: profile
selections in and out of range, dumps and diffs of both sections with their options, sets and gets
of profile settings and values stored past their range. With the get and set sequences of D168,
all 12586 replies match the reference's byte for byte, 2393071 bytes in all, and so does the
configuration's hash after every command.

## D170. Command line features and beepers (2026-10-14)

`Adaflight.Command_Line` gains the `feature`, `beeper` and `beacon` commands. `feature` without
arguments, or with a start of `list`, prints the enabled features, the build's features that are
off, and the features the build lacks. With a name it enables, or after a minus disables, the first
feature in bit order whose name the text starts, in the configuration's feature mask, and prints the
verb with the name. A feature the build lacks is reported unavailable. `beeper` and `beacon` print
the disabled conditions or the available ones, and enable or disable the first allowed condition
whose name the text starts, ALL standing for every allowed one: the beeper's 23 conditions for
`beeper`, RX_LOST and RX_SET for `beacon`. Each beeper table entry's flag comes from its mode, and
ARMING_GPS_NO_FIX sits in the table before its flag's order.

Prefix matching counts the names the text starts, and two or more are the multiple match error,
where the reference takes the first match, so its `feature R` enables RX_PPM and `feature -`
disables it (finding F154, amended 2026-10-25 as declared in D6).

The harness replays two sequences of 2000 feature, beeper and beacon commands recorded from the
oracle: lists, names in mixed case, prefixes, minus forms and names no table holds. With the
sequences of D168 and D169, all 16586 replies match the reference's byte for byte, and so does the
configuration's hash after every command.

## D171. Command line mode conditions (2026-10-14)

`Adaflight.Command_Line` gains the `aux` command. Without arguments it prints every mode condition
whose mode is in the box table as an aux line: index, the mode's permanent id, aux channel, range
ends as channel values, logic, and the linked mode's permanent id or 0. With an index it reads the
condition's mode, aux channel, range ends, logic and link from the arguments that follow, each
argument as `atoi` reads it and each valid one counted: a mode or link by its permanent id, an aux
channel below 14, a range end of any number held to 900 to 2100 microseconds, and a logic of 0 or
1. Four valid arguments take the default logic and no link, five no link, and any other count
clears the condition. The reply is the condition's aux line, and the runtime work it asks for is
the mode conditions changed. An index past the 20 conditions, or below 0 (D6), is the index range
error.

The harness replays two sequences of 2000 aux command lines recorded from the oracle: lists, valid
and invalid indexes, every count of arguments, permanent ids in and out of the table, channels and
range ends in and out of range, and arguments that are not numbers. With the earlier sequences,
all 20586 replies match the reference's byte for byte, and so does the configuration's hash after
every command.

## D172. Command line receiver channels (2026-10-14)

`Adaflight.Command_Line` gains the `map`, `rxrange` and `rxfail` commands.

`map` takes eight characters. It checks each, in upper case, against the channel letters and the
characters after it, then puts each mappable channel it names at that character's position. Other
lengths are the argument count error. The reply writes each mappable channel's letter at its
stored position over the typed text, or over a cleared buffer for a query (D6), and ends at the
first unset position.

`rxrange` without arguments prints the four stick channels' ranges, and `reset` sets them to 1000
to 2000 microseconds without a reply. An index from 0 to 3 and two values from 750 to 2250 set that
channel's range, and the reply is its range line. Fewer than two values are the argument count
error, values past the pulse limits the range error.

`rxfail` without arguments prints the failsafe line of all 18 channels. A channel number below 18,
taken modulo 256, prints that channel's line, after its mode and value are set when a mode letter
follows: `a`, `h` or `s` on the stick channels, `h` or `s` on the aux channels. Another letter, or
a value after `a` or `h`, is the parse error, and `s` without a value the argument count error.
The value is held to 750 to 2250 and stored in 25 microsecond steps from 750, rounded down. A
stored mode past the three letters prints no letter (D6).

The harness replays two sequences of 2000 receiver command lines recorded from the oracle: queries,
orders of the eight mappable channels in mixed case, repeated and unknown characters, wrong
lengths, range resets, indexes and values in and out of range, every mode letter on stick and aux
channels, values past 16 bits, and arguments that are not numbers. With the earlier sequences, all
24586 replies match the reference's byte for byte, and so does the configuration's hash after
every command.

## D173. Command line adjustment ranges (2026-10-14)

`Adaflight.Command_Line` gains the `adjrange` command. Without arguments it prints all 30
adjustment ranges as adjrange lines: index, a 0 in place of the slot, aux channel, range ends as
channel values, function, switch channel, center and scale. With an index it counts a slot argument
of any value, then reads the range's aux channel, range ends, function and switch channel from the
arguments that follow, each argument as `atoi` reads it and each valid one counted: an aux channel
or switch channel below 14, a range end of any number held to 900 to 2100 microseconds, and a
function below 34. Any other count than six clears the range and is the argument count error. Six
valid arguments clear the center and scale and read them from the two optional arguments after,
each taken modulo 65536. The reply is the range's adjrange line, and the runtime work it asks for
is the adjustment ranges changed. An index past the 30 ranges, or below 0 (D6), is the index range
error.

The harness replays two sequences of 2000 adjrange command lines recorded from the oracle: lists,
valid and invalid indexes, every count of arguments, channels, range ends and functions in and out
of range, centers and scales past 16 bits, and arguments that are not numbers. With the earlier
sequences, all 28586 replies match the reference's byte for byte, and so does the configuration's
hash after every command.

## D174. Command line serial ports (2026-10-14)

`Adaflight.Command_Line` gains the `serial` command. Without arguments it prints every claim on the
board's ports, port by port in the board's order: the claim's port setting naming the port, then its
selection setting and its baud setting where each differs from its default. With arguments it reads
the earlier line form, split at each single space, so a doubled space gives an empty argument
(findings F158): a port by its name or number, where numbers below 20 count from UART1, a function
mask, and the msp, gps, telemetry and blackbox baud rates. A rate counts when it is one of the baud
table's rates within its class's range: 9600 to 1000000 for msp, 9600 to 230400 for gps, automatic
or up to 460800 for telemetry, and 19200 to 2470000 for blackbox. A port the board does not have,
or a mask the serial map refuses, is the parse error, and fewer than six counted arguments the
argument count error. Otherwise the mask moves the features onto the port, the four rates go to the
port's features of each class, and the reply is a deprecation line and the port's claims.

`Adaflight.Config_Fix` now gives the serial assignments a configuration's port settings make, and
writes the ports, rates, VTX device, display device and telemetry providers that an assignment
changes back into the configuration (D6).

The harness replays two sequences of 2000 command lines recorded from the oracle: claim lists,
legacy lines with port names and numbers in and out of the board's ports, masks of up to three
functions and masks the map refuses, rates in and out of their classes' ranges, short lines and
doubled spaces, and writes of the port, selection and baud settings between them. With the earlier
sequences, all 32586 replies match the reference's byte for byte, and so does the configuration's
hash after every command.

## D175. Command line mixer and motor mix (2026-10-14)

`Adaflight.Command_Line` gains the `mixer` and `mmix` commands. `mixer` alone prints the mixer
mode's name, `mixer list` and its prefixes print every name, and a name or a prefix of one sets the
first mode it starts, then prints the name. `mmix` alone prints the custom motor mix up to its first
motor without throttle. `mmix reset` clears every motor's throttle. `mmix load` with a name or
prefix clears the throttles, loads the first matching mode's motor table and prints the mix. An
index from 0 to 7 with throttle, roll, pitch and yaw stores each value as it is read, so a line with
fewer values keeps the ones it gave and is the argument count error. The two commands take only the
configuration groups they read or write: the mixer mode and the custom motor mix.

`Adaflight.CLI_Text` gains the reference's float reader and float text. The reader takes digits,
fraction digits and exponent steps in the reference's order, and forms each product exactly in
double precision before one rounding to single precision, to give the reference's single-precision
results bit for bit (D6 at the float range's end). The text rounds half away from zero to
thousandths and converts with the target's saturation at the 32-bit range.

The harness replays two sequences of 2000 command lines recorded from the oracle: mixer queries,
lists, names and prefixes in mixed case and unknown names, motor mix lists, resets, loads of every
table and unknown names, and motor lines with values in plain, fraction and exponent forms, signs,
values that round at the thousandths, and texts that are not numbers. With the earlier sequences,
all 36586 replies match the reference's byte for byte, and so does the configuration's hash after
every command.

## D176. Command line servos (2026-10-14)

`Adaflight.Command_Line` gains the `servo` and `smix` commands. `servo` alone prints every servo's
minimum, maximum, middle, rate and forwarded channel, then a reverse line for each input source a
servo reverses. With arguments it reads six numbers, each wrapped to 16 bits, from a line of numbers
and spaces, where any other character is the parse error (findings F162). A count other than six or
a servo index outside 0 to 7 is the argument count error, and a minimum or maximum outside 500 to
2500, a middle outside them, a rate outside -100 to 100 or a forwarded channel of 18 or more is the
range error. Otherwise the servo takes the values, the channel wrapped to 8 bits, and the reply is
its line.

`smix` alone prints the servo rules up to the first without a rate. `smix reset` clears every rule
and every reversed source. `smix load` with a name or prefix clears each rule's servo, input, rate
and box, loads the first matching mode's rules and prints them. `smix reverse` alone prints the
reversed sources as a table, and with a servo, an input source and `r` or `n` reverses the source or
not, then prints the table. Eight numbers set one rule: index, servo, input source, rate, speed,
range and box, each within its limits.

`Adaflight.Servo_Rules` contains the rules each mixer mode starts from, with the uncommon frames'
rules only in builds with the uncommon mixers, and no rules for the last frame (D6).

Both commands take only the servo parameters and the servo rules, and their listing loops have
loop invariants, so the proof takes each loop one iteration at a time. Unrolled, the servo listing's
8 by 14 loops held 20 gigabytes in one prover process, past a hosted runner's 16. With the
invariants, the unit's largest prover process holds 1.3 gigabytes.

The harness replays two sequences of 2000 command lines recorded from the oracle: servo lists and
lines with values in and out of range, wrapped values, negative forwarded channels, short, long and
malformed lines, rule lists, resets, loads of every frame but the last, reversed source tables and
changes, and rule lines in and out of range. With the earlier sequences, all 40586 replies match the
reference's byte for byte, and so does the configuration's hash after every command.

## D177. Command line LEDs (2026-10-14)

`Adaflight.Command_Line` gains the `led`, `color` and `mode_color` commands. `led` alone prints each
of the 32 LEDs' configuration as text: position, direction letters, function letter with overlay
letters, and color. With an index from 0 to 31 and a text it clears the LED and reads the text with
the LED strip's parser. A text that reads is stored and printed, and asks for the strip's layout. A
text that does not read leaves the LED cleared and is the parse error. `color` alone prints the 16
colors, and with an index and three comma-separated values it reads hue, saturation and value in
turn, each stored as it is read and wrapped to its field (findings F164). A value past its limit or
a missing comma clears the color and is the parse error. `mode_color` alone prints each mode's
direction colors, the special colors and the strip's aux channel, and three numbers set one of them
to a color index below 16.

Each command takes only the LED strip's configuration or the part of it it changes, and the listing
loops have loop invariants (D176).

The harness replays two sequences of 2000 command lines recorded from the oracle: LED lists and
texts with positions, directions, functions, overlays and colors in and out of range, broken
separators and long chunks, color lists and values in and out of range with missing and extra
components, and mode color lists and writes in and out of range. With the earlier sequences, all
44586 replies match the reference's byte for byte, and so does the configuration's hash after every
command.

## D178. Command line VTX settings (2026-10-14)

`Adaflight.Command_Line` gains the `vtx` and `vtxtable` commands. `vtx` alone prints the ten VTX
channel conditions. With an index it reads the condition's aux channel, band, channel, power and
range ends from its arguments, each valid one counted: an aux channel below 14, a band, channel and
power level up to the VTX table's counts, and a range end of any number held to 900 to 2100
microseconds. Any other count than six clears the condition and is the argument count error.

`vtxtable` alone prints the table: the band and channel counts, a line for each band with its name,
letter, factory flag and frequencies, and the power level count with the power values and labels.
Its subcommands set the band count, clearing the bands it drops, the channel count, clearing the
channels it drops in every band, and the power level count, clearing the values and labels it drops.
`powervalues` and `powerlabels` take exactly as many words as power levels. `band` takes a band
number up to the band count, a name of up to 8 characters and a letter, both in upper case, a
factory or custom flag before the first frequency, and exactly as many frequencies as channels. An
error leaves the table as it was.

Both commands take only the VTX conditions and the VTX table, and their listing loops have loop
invariants (D176).

The harness replays two sequences of 2000 command lines recorded from the oracle: condition lists
and writes in and out of the table's counts, table lists, counts in and out of range with the parts
they clear, power values and labels of every count, band lines with names, letters, flags and
frequencies in and out of range, missing parts, and unknown subcommands. With the earlier sequences,
all 48586 replies match the reference's byte for byte, and so does the configuration's hash after
every command.

## D179. Command line flight plan (2026-10-14)

`Adaflight.Command_Line` gains the `waypoint` command over the flight plan. Alone or with `list` it
prints a clear line and an insert line for each waypoint, and `clear` empties the plan. `status`
prints the waypoint count, each waypoint's coordinates, altitude in meters and type, and the flight
plan executor's report: inactive, or its state, current waypoint, distance, bearing, time to the
waypoint and abort reason. `remove` takes a waypoint index and moves the later waypoints down.
`insert` and `update` take an index, latitude and longitude in degrees with up to seven decimals,
altitude in centimeters, speed, type, duration and pattern, with an optional vertical rate and yaw
behaviour. Each number must be the whole word, each name one of its list without regard to case,
and the coordinates within the latitude and longitude ranges. An insert into a full plan of 30
waypoints is refused, and a stored count past 30 is cleared first.

`Process_Line` takes the executor's report from its caller as a `Navigation_Status`. The distance
rounds to centimeters with ties to even, held at the 32-bit range as the target holds it.
`Adaflight.CLI_Text` gains the coordinate reader with its overflow checks, the coordinate text, and
a whole-word number reader that keeps numbers past the 32-bit range apart from those within it.

The harness replays two sequences of command lines, 4360 in all, recorded from the oracle with a stub
executor whose report the `!nav` lines set: lists, clears, status reports over every executor state,
removals, inserts and updates with coordinates, numbers and names in and out of range or malformed,
wrong counts, full plans and unknown operations. With the earlier sequences, all 52946 replies match
the reference's byte for byte, and so does the configuration's hash after every command.

## D180. Command line master dump (2026-10-14)

`Adaflight.Command_Line` gains the master dump and the `version` command. `dump` alone, with
`master`, or with options that name no section prints the version line, the command batch's start,
the board's name and manufacturer, and the craft name, or `-` without one. Each section follows
under its heading: features, mixer with its custom motor mix, servos, servo rules, beepers, beacons,
channel map, LEDs, colors, mode colors, mode conditions, adjustment ranges, channel ranges, VTX
table, VTX conditions, channel failsafe and flight plan. The master and hardware settings follow as
set lines, then the selected PID, rate and battery profiles, then the batch's end. `bare` leaves out
the batch lines. A dump with `defaults`, a diff of the master section, and the `hardware` and `all`
sections stay unknown to `Process_Line`.

Where a listing command prints the same lines as its dump section, the two share one printer. The
dump's version line names the default configuration's board identifier, and `version` names the
stored one.

`Process_Line` takes an `Environment` from its caller in place of the navigation report. It contains
the flight plan executor's report, the firmware's name, the target's name, the version, the build's
date, time and revision, and the board's name and manufacturer.

The harness replays two sequences of 2274 command lines in all, recorded from the oracle: rounds of
the earlier modes' commands, settings in and out of range, profile selections, stored values past
their ranges and craft names, each round ended by a master dump, plain, bare or with an ignored
option, or by a version line, 40 in all. With the earlier sequences, all 55220 replies match the
reference's byte for byte, and so does the configuration's hash after every command.

## D181. Command line master diff (2026-10-14)

`diff` alone, with `master`, or with options that name no section prints the master diff, and `dump`
and `diff` take `hardware` and the options `defaults` and `bare` for the master and hardware
sections. Each section printer takes the defaults, a dump mode and a heading that waits for the
section's first printed line. A diff keeps only the lines off their defaults, and `defaults` prints
each changed line's default first after a number sign. The board's name and manufacturer and the
craft name print in a diff only when set. The hardware dump keeps the board's lines, the features
and the hardware settings under the master heading. The listing commands use the same printers with
no heading.

A diff decides its `mmix reset` and `smix reset` lines from the stored first motor and first rule.
The reference reads the default configuration it has just reset to, so its diff never prints either
line (finding F169, amended 2026-10-26 as declared in D6). The flight plan's heading precedes its
first printed line, and so does the beeper heading a changed condition's default line and the
feature heading a feature's default line, where the reference prints the flight plan lines under the
previous section's heading and those default lines before their headings (findings F170, F171 and
F172, amended 2026-10-25 as declared in D6). A channel failsafe default line takes the format of the
default's mode. The reference formats it by the channel's own mode (finding F173, amended 2026-10-26
as declared in D6). A VTX band compares its name without regard to case, its letter, its factory
flag and its frequencies, and the power values' and labels' default lines list the default level
count. The reference skips the flag and lists all eight entries (finding F174, amended 2026-10-26 as
declared in D6). With the printers in the master dump, the unit's largest prover process holds 3.9
gigabytes, for `Dump_Master`.

The harness replays two sequences of 2350 command lines in all, recorded from the oracle: the dump
mode's rounds, each ended by a master or hardware diff, plain, bare or with defaults, or by a master
or hardware dump with defaults or bare, 40 in all. With the earlier sequences, all 57570 replies
match the reference's byte for byte, and so does the configuration's hash after every command.

## D182. Command line dump of every profile (2026-10-14)

`dump all` and `diff all` print the master dump or diff with every profile: after the master
settings come each PID profile, the selected PID profile restored, each rate profile and each
battery profile, then the selected rate and battery profiles restored and `save` without a line end
in place of the batch's end. Unless bare, the MCU's unique id and the board's signature follow the
board's lines, and a diff of every profile resets the configuration with `defaults nosave` after the
batch's start. `bare` leaves out the batch, the restores, the save, the MCU id and the signature.
The `mcu_id` command prints the MCU's id.

`Environment` gains the MCU's unique id and the board's signature with whether it is set. An unset
signature prints an empty `signature` line.

The harness replays two sequences of 1022 command lines in all, recorded from the oracle with the
MCU id 0, 1 and 2: the dump mode's rounds, each ended by a dump or diff of every profile, plain,
bare or with defaults, or by `mcu_id`, 20 in all. With the earlier sequences, all 58592 replies
match the reference's byte for byte, and so does the configuration's hash after every command.

## D183. Command line board information (2026-10-14)

`Adaflight.Command_Line` gains the `board_name`, `manufacturer_id` and `signature` commands over a
`Board_State` that `Process_Line` takes in and out: the board's name and manufacturer, whether the
stored configuration set them, whether a command changed them, and the same for the signature.
`Init_Board` takes the stored information in as the board starts: the name and manufacturer only
when stored, the signature only when stored.

Each command prints its value, after taking a new one while nothing is stored or the stored value is
empty: up to 20 characters of a name, 4 of a manufacturer, or 64 hexadecimal digits of a signature.
A different value for a stored one is the error. The signature takes a pair only as two hexadecimal
digits, where the reference reads it as the C library reads a number, with spaces and a sign allowed
before the digits and a minus negating the byte (finding F175, amended 2026-10-25 as declared in D6).
A long name or manufacturer keeps its first characters, and a name for a stored one is compared cut
to the stored length, where the reference compares the whole name and refuses the name it stored
(finding F176, amended 2026-10-25 as declared in D6). The dumps and `version` print the board's lines
from this state.

The harness replays two sequences of 800 command lines in all, recorded from the oracle with
`!board` lines that store the board's information: names, manufacturers and signatures of every
length, malformed signature pairs, values for stored information, `version` lines and diffs. With
the earlier sequences, all 59392 replies match the reference's byte for byte, and so does the
configuration's hash after every command.

## D184. Command line simplified tuning (2026-10-14)

`Adaflight.Simplified_Tuning.Stored` applies the simplified tuning to a stored PID profile and the
stored gyro settings, and the command line's `simplified_tuning` applies it to every PID profile
with the gyro settings, or turns every slider off. Any other argument is the parse error. The stored
version reads the sliders, the mode and the lowpass cutoffs from the configuration's fields with no
runtime record between them, so a lowpass minimum above its maximum computes as stored.

`Simplified_Tuning`'s private part contains the arithmetic both versions share: each axis's gains
and D max through the sliders, and the scaled cutoffs. A slider factor reaches 2.55, so a stored
byte past a slider's range computes as stored, and a stored PIDs mode past RPY covers every axis
(D6).

The harness replays two sequences of 1200 command lines in all, recorded from the oracle with the
reference's simplified tuning linked: slider, mode and lowpass settings of every profile and of the
gyro, profile selections, applies and disables, malformed arguments, and gets, profile dumps and
diffs of the results. With the earlier sequences, all 60592 replies match the reference's byte for
byte, and so does the configuration's hash after every command.

## D185. Command line defaults (2026-10-14)

The command line's `defaults` with `nosave` resets the configuration to its defaults, then applies
the simplified tuning to every PID profile. With `group_id` and a number it resets one parameter
group: the reset configuration, tuned, is encoded with `Config_Codec`, and that group's bytes
replace the group in the encoded configuration before it is decoded back. A word with neither
keyword, a missing group or a zero group is the parse error. A word is its whole keyword, in any
case, and a group number outside 1 to 65535 is the parse error, where the reference takes any word
containing the keyword and wraps the number to 16 bits (finding F178, amended 2026-10-25 as declared
in D6).

Without `nosave` the reset is followed by a save and a restart, which wait for the `save` command,
and `Process_Line` returns Known false.

The harness replays two sequences of 1000 command lines in all, recorded from the oracle: settings
of every group, whole and single-group resets with keywords in any case and inside other words,
unknown, wrapped and negative group numbers, malformed resets, profile selections, and diffs and
gets of the results. With the earlier sequences, all 61592 replies match the reference's byte for
byte, and so does the configuration's hash after every command.

## D186. Command line proof context (2026-10-14)

Each section printer of the command line's dump has a `Global => null` contract. Without one,
GNATprove's contextual analysis folds a contract-free local subprogram into every caller, so the
master dump's proof context contained every printer's body, and its largest prover process grew with
each printer: 1.9 gigabytes at the master dump, 3.9 at the diff and 5.3 at the defaults. With the
contracts, each printer is its own proof target and the dump's context contains only their
contracts, so the unit's largest prover process holds 3.2 gigabytes, for the VTX table command. The
listing loops keep their invariants (D176).

## D187. Runtime records from the stored configuration (2026-10-14)

`Adaflight.Config_Runtime` builds the runtime records the control units take from the stored
configuration, starting with `PID_Profile.Profile` from a stored PID profile. The constructor is an
expression function: one aggregate names every field's source, so the mapping is the specification
and a wrong field is a proof failure. Each number is held to its runtime range, each code to its
names, and the level gains come from the fourth PID entry with the angle feedforward in the low byte
of its feedforward gain. The runtime record's predicate, the dynamic lowpass and the notch in order,
comes from the configuration fix: `Config_Fix.Fixed_PID_Profile` states what the profile checks
leave, is their postcondition, and is the constructor's precondition. A field the fix does not
establish is a proof failure at the constructor, so the fix's coverage is checked at proof time.

The stored configuration keeps every value a foreign image can hold, which the command line and MSP
recordings need (D6). The runtime records keep the narrow ranges the control proofs rest on. The
constructor is the one boundary between them. A stored value outside its range is held to the range
there (D6).

`Rate_Profile_Of` builds `Rates.Profile` from a stored rate profile. The rates have no order rule,
so the constructor asks nothing of the fix.

`Gyro_Settings_Of` builds `Gyro_Filters.Settings` from the stored gyro, dynamic notch, RPM filter,
gyro device, board alignment, motor and PID loop groups. What the hardware gives comes in as
parameters: the sample time, whose product with the PID loop ratio is the loop time, the gyro's
scale, the motors in use and whether the gyro protects against overflow.
`Config_Fix.Fixed_Gyro_Filters` is the gyro filter checks' postcondition and the constructor's
precondition in the same way.

`Failsafe_Settings_Of` builds `Failsafe.Settings` from the stored failsafe group and the autopilot's
loss policy. `Receiver_Settings_Of` builds `Receiver.Settings` from the stored receiver, channel
range, channel failsafe, 3D and failsafe groups, the features in use, which name the source in the
order the reference's receiver setup gives them, and the channel count the protocol reports. The
receiver's failsafe throttle takes the full pulse range its setting has, where the port had held it
to 1000 to 2000. An equal channel range is widened by one step, and a zero RSSI frame period reads
as one (D6).

`Arming_Settings_Of` builds `Arming.Settings` from the stored arming, system, receiver, 3D, mixer
and PID loop groups, the current PID profile, the features in use and the sensors found at boot. The
fixed wing flag comes from the mixer mode through `Mixer_Init.Is_Fixed_Wing`. `Conditions_Of` builds
the mode conditions, a condition whose mode is outside the box table never active and a link outside
it no link (D6).

`RC_Config_Of` builds `RC_Command.Config` from the stored receiver, RC controls and PID loop groups
and the current rate profile, through `Rate_Profile_Of`, with the sample time whose product with the
loop ratio is the loop time. The command path's minimum check is held to 1999, below its setting's
2250 (D6). `Adjustment_Settings_Of` builds `Adjustments.Settings` from the stored receiver and
system groups.

`Mixer_Config_Of` builds `Mixer.Config` from the stored mixer, motor, 3D and receiver groups, the
current rate and PID profiles, the custom motor mix, the features in use and the build's mixers. The
output range comes from the protocol family: `DShot.Endpoints` for the DShot family, and
`PWM_Output.Endpoints` for the analog family, which raises the minimum command by a tenth of the
idle setting and brings the maximum throttle down by what the output limit leaves of the span, or in
the two direction mode brings the 3D limits in by half the limited span. The range is then held to
the motor values and at least one step wide, with the disarm output held below its top. A disabled
protocol's range is zero to one. The motors in use and their mix come from
`Mixer_Init.Configure_Output`, over a mode outside the table read as quad X and weights that are not
numbers read as zero. A custom mix without motors reads as one motor with a zero mix (D6).

`Accelerometer_Settings_Of` builds `Accelerometer.Settings` from the stored accelerometer, gyro
device and board alignment groups, with the hardware's sample rate and counts per g. The alignment
is the first gyro's, since the boards use one chip for both. `Attitude_Settings_Of` builds
`Attitude.Settings` from the stored IMU and throttle correction groups, `Barometer_Settings_Of`
builds `Barometer.Settings` from the stored barometer group, with the virtual device from the
hardware code, and `Compass_Settings_Of` builds `Compass.Settings` from the stored compass and board
alignment groups.

`Battery_Settings_Of` builds `Battery.Settings` from the stored battery, voltage meter, current
meter, virtual meter and ESC sensor groups and the current battery profile. `Beeper_Settings_Of`
builds `Beeper.Settings` from the stored beeper group, each sound's flag from the bit below its
code.

`GPS_Link_Settings_Of` builds `GPS_Link.Settings` from the stored GPS and GPS rescue groups, with
whether a serial port has the GPS function. The baud is the user's from the module's table, 230400
for a rate the table lacks, and the custom NMEA commands are the stored text up to its first NUL.
`GPS_Rescue_Settings_Of` builds `GPS_Rescue.Settings` from the stored GPS rescue, autopilot and GPS
groups.

`Position_Control_Settings_Of` builds `Position_Control.Settings` from the stored autopilot and RC
controls groups, with whether the build flies a rescue as a flight plan.
`Position_Estimator_Settings_Of` and `Position_Hold_Settings_Of` build their settings from the
stored position and position hold groups, `Altitude_Control_Settings_Of` and
`Altitude_Hold_Settings_Of` from the stored autopilot, altitude hold and receiver groups, and
`Flight_Plan_Settings_Of` builds `Flight_Plan_Nav.Settings` from the stored autopilot, GPS rescue
and altitude hold groups, with the climb rate the altitude hold flies at, ten times its setting, and
none for a wing.

`Blackbox_Settings_Of` builds `Blackbox.Settings` from the stored blackbox group, with whether the
build is a wing. A serial device runs fast from a megabaud up. `Scheduler_Settings_Of` builds
`Scheduler.Settings` from the stored scheduler group, with the platform's clock, its floor on a
rescheduled period and the gyro's period. `LED_Strip_Settings_Of` builds `LED_Strip.Settings` from
the stored LED strip and status mode groups, the first eight stored special colors being the
strip's. `VTX_Settings_Of`, `Flight_Stats_Settings_Of` and `Lap_Timer_Settings_Of` build their
settings from the stored VTX settings, statistics and lap timer groups.

`Rangefinder_Settings_Of` builds `Rangefinder.Settings` from the stored position group, with the
cone the detected sensor reports. `Optical_Flow_Settings_Of` and `Pitot_Settings_Of` build their
settings from the stored optical flow and pitot groups. `Gimbal_Settings_Of` builds
`Gimbal_Control.Settings` from the stored gimbal tracking and receiver groups, with whether a serial
port has the gimbal function, and `RTC_Settings_Of` builds `RTC.Settings` from the stored time
group.

`OSD_Page_Settings_Of` builds `OSD_Page.Settings` from the stored OSD and OSD element groups, with
whether the display supports a logo. An element is visible when its stored position shows it in the
stored profile. `OSD_Render_Settings_Of` builds `OSD_Render.Settings` from the stored OSD and VTX
settings groups, a profile name being the stored text up to its first NUL. `OSD_Spec_Settings_Of`
builds `OSD_Spec.Settings` from the stored mixer and motor groups and the current rate, PID and
battery profiles. `OSD_Warnings_Settings_Of` builds `OSD_Warnings.Settings` from the stored OSD
group, each warning's flag from its bit, and `OSD_Alarm_Settings_Of` builds the elements' alarm
settings from the stored OSD and GPS rescue groups.

The telemetry constructors build the FrSky hub, GHST, CRSF, HoTT, iBus, Jeti, MAVLink and SRXL
settings from the stored telemetry group, with what the protocols read from outside it: the sensors
found at boot, the features in use, the battery meters configured and the accelerometer's scale. A
sensor's telemetry is on when its bit in the stored disabled mask is clear. The FrSky hub takes the
motor group's pole count, the CRSF configuration the receiver group's negotiated baud and whether
the build sends event driven frames, and Jeti the system group's debug mode.

The receiver link constructors build the ExpressLRS, FrSky SPI, Redpine, SFHSS, FlySky, Spektrum,
Spektrum SPI and SRXL2 settings from the stored SPI receiver, CC2500, ExpressLRS, FlySky, Spektrum
and receiver groups and the features in use. A radio's pins come from the stored pin tags. The FrSky
SPI protocol comes from the SPI protocol code, FrSky D for a code outside the family, the FlySky
variant is AFHDS 2A for its code and AFHDS otherwise, and the Spektrum kind comes from the serial
provider, Spektrum 2048 for a code outside the three (D6).

The harness builds the four PID profiles and the four rate profiles of every fixed configuration in
the configuration fix recordings, 16000 of each, and the gyro settings of each with a running gyro
and motors, 3082, with the preconditions and the predicates checked at run time, and compares the
roll P gain, the roll RC rate and the first lowpass cutoff.

## D188. Failsafe rescue and autopilot stages (2026-10-14)

`Adaflight.Failsafe` gains the GPS rescue procedure and the autopilot stage of the build with the
flight plan, which the failsafe recordings had left out: their oracle compiled the reference's
failsafe without the rescue and flight plan options, so the port had the landing and drop procedures
only. The oracle now builds with them and records the inputs the stages read.

The GPS rescue procedure asks the caller to stage the executor's rescue plan, through the
`Stage_Rescue` output of `Update`, and takes whether a plan is possible as an input. With a possible
plan the failsafe enters the autopilot stage with a grace period of one second for the caller to
engage the plan. Without one it lands. A link loss during a mission enters the autopilot stage at
once when the autopilot's loss policy continues the mission, or lands when the policy lands. The
mission's own throttle keeps the low-throttle shortcut from disarming. In the autopilot stage the
failsafe recovers on stick movement or a switch, lands when disarmed, waits through the grace period
while the plan is not yet engaged, falls back to the configured procedure, auto-landing in place of
the rescue, when the mission ended or never engaged, and sounds the landing tone otherwise. The
plain GPS rescue stage of a build without the flight plan is in the state machine but not entered.

The harness builds the four PID profiles and the four rate profiles of every fixed configuration in
the configuration fix recordings, 16000 of each, the arming, failsafe, receiver, adjustment, mixer,
attitude, barometer, compass, battery, beeper, GPS link, GPS rescue, position control, position
estimator, position hold, altitude control, altitude hold, flight plan, blackbox, scheduler, LED
strip, VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD page, OSD
render, OSD specification, OSD warning, OSD alarm, the eight telemetry and the eight receiver link
settings and the mode conditions of each, 4000 of each, and the gyro, RC command and accelerometer
settings of each with a running gyro and motors, 3082, with the preconditions and the predicates
checked at run time, and compares one field of each. The analog endpoints replay 235 recorded motor
and 3D settings from the DShot oracle bit for bit, 70 of them with an inverted range (findings
F181).

## D189. Command line batches (2026-10-14)

The command line's text goes out through an `Output` record: the sink the instantiation supplies,
and the command batch's state, whether a batch is open and whether a command in it printed an error.
Every error goes through one printer, `Put_Error`, which prints `###ERROR IN ` and the text, and
notes the error when a batch is open. `batch start` opens a batch and clears its error, unless one
is open already, and prints `Command batch started`. `batch end` prints `Command batch ended`, or
the error line `ERRORS WERE DETECTED - PLEASE REVIEW BEFORE CONTINUING` when a command in the batch
printed an error, and closes the batch either way. Any other option is the `Invalid option` error.
An option is its whole word, in any case, and a second start clears the batch's error, where the
reference takes a prefix and keeps the error (finding F180, amended 2026-10-25 as declared in D6). A
`defaults` reset clears the batch's error and leaves the batch open.

A line naming no command gets the reply `ERR_CMD_NA: ` and the line, with its comment and trailing
spaces cut, and no error is noted. This is the reply of the reference's non-interactive stream,
which the oracle records. Its interactive session prints the `UNKNOWN COMMAND, TRY 'HELP'` error
instead, which notes the error (findings F179). That error, the echo and the prompt belong to the
target phase's interactive session. `Process_Line` reports Handled false only for `defaults` without
`nosave`.

The harness replays two sequences of 1019 command lines in all, recorded from the oracle: batch
starts and ends in any case and with trailing text, settings and commands with and without errors
between them, unknown lines, stored values past a setting's range and their gets, diffs and resets
inside batches, and batch commands with bad options. With the earlier sequences, all 62611 replies
match the reference's byte for byte, and so does the configuration's hash after every command.

## D190. Core loop cadence and yaw reset (2026-10-14)

`Adaflight.Core_Loop` holds the core loop's cadence: a counter of gyro samples that starts over at a
multiple of the PID loop ratio and counts from one, with the gyro filtering ready when the count
reaches the ratio and the controller ready halfway through it, the integer half, so a ratio of one
runs both on every sample. The counter is a byte and wraps at 256 should the ratio shrink under it.
`Resets_Yaw` is the stick rule before the RC command: the yaw command is reset while arming by stick
with the throttle at or below the minimum check, both in normalized units, except on a tricopter
whose servo moves when disarmed and on the fixed wings. The subtask sequence over the units, the RC
command, the launch wing, the controller, the mixer with its servos and motors, and the flight log,
is the target phase's main loop.

`Arming.Try_Arm` keeps the gyro's first arming calibration latch: the calibration starts once, and
the status check inside the arming attempt sees it running. A stick calibration earlier in the same
pass is read from the step's state before the pass.

The harness replays the cadence and the yaw rule on every step of the arming recordings, 15000 steps
of one to three samples each over loop ratios of one to eight, and compares the counter, both ready
flags and the yaw reset with the reference's. The recordings hold the calibration state before each
step's commands for the receiver pass and the state after them for the PID loop and the final status
update, which a stick calibration in the same step as an arming attempt tells apart.

## D191. PID loop pass (2026-10-14)

`Adaflight.Main_Loop` is the PID loop's pass over the units in the task's order, a generic whose
procedures are the units: the yaw reset before the RC command, the launch wing in a wing build, the
controller with the runaway check and the PID audio after it, the mix, the servos when the mixer
drives them, the motors, and the flight log outside the command line when a log device is set. The
pass reads those conditions as inputs. `Adaflight.Main_Loop_Shape` instantiates it over counting
units for the proof. The target phase instantiates it over the units' updates with their states.

The harness instantiates the pass over logging units, one letter each, on every step of the arming
recordings, with the runaway check over the arming state, and compares the letters with the order
the reference's loop called its units in, over 15000 steps with the servo, flight log and command
line conditions drawn at random. The recordings hold no PID audio condition.

## D192. Task functions (2026-10-14)

`Adaflight.Task_Functions` is the task functions with a unit or two behind them, a generic whose
procedures are the units: the main task's flash erase, the serial task's MSP pass that evaluates
other data only while disarmed, the battery alerts with the presence check while disarmed, the
accelerometer, the GPS rescue when configured, the barometer, pitot and compass whose updates name
the next period, the position estimator, the rangefinder and optical flow when detected, telemetry
outside the command line with the feature, and the camera control while disarmed. The functions read
those conditions as inputs. A sensor task runs as the scheduler's current task and reschedules it
through `Adaflight.Scheduler.Reschedule` when its update names a period other than zero. The
reschedule's gyro branch stays out of reach, since no realtime task reschedules itself.
`Adaflight.Task_Functions_Shape` instantiates the functions over counting units in the shapes the
units take, for the proof, which covers that a sensor task reschedules only a running task. The
target phase instantiates them over the units' updates with their states.

The harness instantiates the functions over logging units, one letter each, after every step of the
task setup recordings, with the running task set before each sensor task, and compares the letters
with the order the reference's functions called their units in and the barometer, pitot and compass
periods after them, over 4800 steps with the arming flag, command line, rescue configuration and
sensor deadlines drawn at random.

## D193. Menu lines and page layout (2026-10-14)

`Adaflight.Menu` is the menu system's lines and page layout:

- a line's element and flags in the reference's encoding, with the element in the low five bits and
  the guard type standing for every code above the table's
- a menu as a bounded table of up to 192 lines with its count before the end marker
- the screen geometry from the display's size, with the smallest display at eight rows so a page
  holds at least four items
- the page count
- the page selected by number, wrapped within the count, with its top line, its last row from the
  lines left, the items on a page and the row limit, and the lines' flags copied whole for the draw,
  where the reference's byte drops the flags above the dynamic one (finding F183, amended 2026-10-26
  as declared in D6)
- the cursor's absolute row
- the rows the cursor skips, which are labels, strings and the narrow numbers that are dynamic or
  that a slider overrides, where the reference's dynamic test compares the whole flags word with the
  flag and never holds (F182)
- the value text helpers: a value in thousandths with its trailing zeros cut down to the first
  decimal and a leading zero blanked, a value cut to its field and aligned right in it, and the
  display's character set

The proof covers the page arithmetic: the selected page's top line stays within the table and the
flags copy within the page's rows. The menus, their lines' values, the display and the draw stay
with the target or later slices.

The harness replays 1800 menus drawn at random (one to sixty lines, displays of eight to eighty
columns and eight to forty rows, full screen displays among them) through the layout, the page
count, the first page and four page turns, asks every line whether the cursor skips it under random
slider settings, and checks 1800 fixed-point values, right alignments and character set passes each
against the reference's text.

## D194. Menu draw (2026-10-14)

`Adaflight.Menu_Draw` is the menu's draw, a generic whose procedures are the display's writes of a
text and of a character, the text write naming the bytes it takes:

- a page's labels, values and cursor written within the bytes the display has room for, every row
  after the screen was cleared and else the values marked for a print, the dynamic ones every tenth
  of a second
- the cursor moved past the rows it skips and erased from its old row
- each value in its element's form in a field aligned to the right column (a string in twelve
  characters, a function call's text with its arrow, a boolean as YES or NO, a lookup table's text
  in the space its label leaves, the visibility marks of the three OSD profiles with the editing
  cursor's blink, a number or a fixed-point value in five characters)
- the slider mark beside an overridden value
- the page arrows after a clear

The runtime flags keep sixteen bits, so a submenu with an option string shows its line's text before
the arrow, and a lookup table's text longer than its space scrolls: the ticker holds 20 draw cycles
at each end and 3 between steps. The reference's byte of runtime flags leaves both unreachable
(finding F183, amended 2026-10-26 as declared in D6). The byte budget wraps below zero. The menu's
display update hook stays with the target until the menu stack lands. The proof covers the row and
column arithmetic within the page and the display, and the value fields within the text bound, which
every display's layout keeps and the draw requires (a full screen display wider than 32 columns
would overrun the reference's table value buffer, F184). `Adaflight.Menu_Draw_Shape` instantiates
the draw over counting writes for the proof.

The harness instantiates the draw over logging writes that take the bytes the reference's display
reported, and replays 12600 draws over the 1800 random menus, three after each open and one after
each page turn, with random byte budgets, cursor placements, clock readings, editing states and
device types, comparing every display operation with the reference's and the cursor, flags and
tickers after the draw.

## D195. Menu navigation (2026-10-14)

`Adaflight.Menu_Nav` is the menu's navigation, a generic over the menus' hook sets and lines, the
hooks and the target's actions:

- the menu opened from its start menu on the current display, or moved to the next registered
  display while open with the cursor carried as an absolute row and the display's background type
  set
- a change to a menu, which stacks the menu left except on the way to the main menu, loads the new
  menu's lines, asks its enter hook and selects its first page, or restores the page and cursor from
  the absolute row when the menu stays
- the way back, which asks the leave hook, which may refuse it, and restores the stacked menu
- a page selected with the screen cleared
- the draw with its update hook and the way back it may ask for
- the exit by its kind, which asks the current menu's leave hook and, for a popup, the stacked
  menus' hooks, saves, releases the display, and for a reboot writes the notice, redraws, stops and
  shuts down the motors, waits and resets

The display layer's grab, release, clear, layer selection, background type and redraw, the save, the
arming disable flag, the motor stops, the delay and the reset go to the target as actions on a
display. The lines are loaded before the enter hook, as the reference's current menu changes before
it, and a chain back that restores no menu selects the entered menu's first page (D6, F185). The
state holds the current menu with its hooks, the context stack of up to ten menus, the current
menu's lines, the layout and selected page, the draw's context, the save inhibition and the
registered displays with the current one. The proof covers the state's consistency between
operations: every full screen display within the text bound (F184), an open menu on a registered
display whose layout keeps a value's space and fits its rows, and a current menu with at least one
line, its fixed-point values in range, and its selected page within its lines and the layout's
items. `Adaflight.Menu_Draw` gains the display index on its writes and the update hook with the way
back it asks for. `Adaflight.Menu` holds the displays, the menu numbers with their hook sets, the
draw's context and the actions, which the draw and the navigation share. `Adaflight.Menu_Nav_Shape`
instantiates the navigation over counting menus, hooks, actions and writes for the proof. The resume
of the OSD's refresh at the open and the stick scanning stay with the target or later slices.

The harness instantiates the navigation over the recorded menu sets, hooks that answer as the
reference's did, and logging actions and writes, and replays 1800 random menu trees of up to six
menus on two displays of random size: each open, three draws, four page turns with a draw each, six
navigation operations (a change to a submenu, the way back, or a reopen that switches the display)
with a draw each, the skip rule and an exit of a random kind, comparing every display operation,
hook call, context, stack frame, display state and page with the reference's.

## D196. Menu keys (2026-10-14)

`Adaflight.Menu_Nav` gains the key handler:

- the menu key moves the menu to the next display and the escape key ends an edit or takes the way
  back, each with the longer pause
- the save key, unless the save menu is inhibited, ends an edit and changes to the save menu of the
  reboot state
- down moves the cursor a row or to the next page's top
- up moves it a row and over the rows the cursor skips, and from a label or the page's top to the
  previous page's last row
- left and right act on the line under the cursor in its element's form: a submenu entered on the
  right, a function line called on the right with the way back it may ask for and the reboot flag it
  may set, an exit line's exit by its kind, the way back from a back line, a boolean set on the
  right and cleared otherwise, the OSD profile marks edited with the profile cursor, a number
  stepped up on the right within its maximum and down otherwise within its minimum but wrapped in
  its width, and a lookup table's index stepped within its bounds with its text looked up again
- every edit written to the target's value and marked for a print, the reboot flag set when a reboot
  line's value changed, and the line's hook called after

A line's range, step, multiplier and hook join the line record. A number wider than the signed word
is held as the reference's integer conversion and compared unsigned. The target's value store and
the lookup of a table's text come in as procedures, and the reboot flag's set as an action. The
handler keeps two bounds the reference lacks (D6, F186). The proof covers the state's consistency
through every key, the edits within the lines, the widths' wraps and the page requests.

The harness replays twelve random keys per menu tree after the navigation operations, 21600 keys,
with the line under the cursor compared after each, the edits written back to the recorded menus and
the reboot flag followed from the actions.

## D197. Menu update (2026-10-15)

`Adaflight.Menu_Nav` gains the update, one pass of the menu task:

- nothing while a paralyze mode, a camera device menu or a joystick in use holds the menu off
- with the menu closed, the menu opened on the stick gesture (throttle mid, yaw low, pitch high)
  while disarmed and stick commands allowed, with the longer key pause
- with the menu open, a drawing transaction begun on the display, the keys scanned, the draw, the
  display's heartbeat every half second, and the transaction committed, each on the display current
  at that point, since the menu key moves the menu between them

The scan takes an external key first, kept since it was set until a pass reads it and not replaced
while pending. Else the sticks read as a key, in order: the menu gesture while disarmed, then pitch
up or down, roll left or right, yaw left for escape and right for the save menu. A key released
resets the hold count and the repeats, and a key held counts. The delay since the last key runs down
by the pass interval, wrapped in sixteen bits. Once run out, the key is handled as many times as the
repeats say, and left or right held past twenty passes shortens the delay by the hold beyond that,
and below the scheduling interval grows the repeats by a fifth of the hold since the repeats began,
to five. The repeats are kept in one to five where the reference's hold count would wrap after
years. The target's heartbeat and transactions join the actions.

The harness replays forty update passes per menu tree after the exit, 72000 passes, with the sticks
held or redrawn at random, the arming flag, modes, external keys, byte budgets, device types,
editing states and clock readings drawn at random, and compares every display operation, hook call,
context and page with the reference's.

## D198. Command line tasks (2026-10-15)

`tasks` prints the task list: for every queued task, its number in two digits, its name
right-justified in fifteen columns, and its rate in hertz, the nearest integer to ten million over
its average interval in tenths of a microsecond. With `task_statistics` on, each line adds the peak
and average execution times in microseconds, the peak and average loads in tenths of a percent, and
the total execution time in milliseconds. Then come the check functions' line, with their peak and
average times, their load over the time since the last `tasks` and their total, the total load line,
and in the scheduler determinism debug mode the loop start and guard cycles. Each queued task's peak
times reset after its line, the check functions' peak after theirs. The task information comes from
`Adaflight.Scheduler.Info`, the reference's `getTaskInfo`: the moving sums over eight samples give
the averages, and the load products wrap at 32 bits. `Adaflight.Scheduler.Check_Functions` gives the
check functions' summary and `Adaflight.Scheduler.Name` the task names. The system and main tasks
share the name `SYSTEM`.

`Process_Line` takes the scheduler's state, so the command reads it and resets it directly. The
`Environment` gains the clock in microseconds and the running debug mode, and `Output` keeps what
the reference keeps in function statics: the clock at the last `tasks` and the check functions'
total at that time. The reference reads the clock twice, before the list and after it. The port's
one reading stands for both (D6). Counts print as the C library prints a 32-bit pattern with `%d`: a
peak time past 2^31 microseconds prints negative, and the total load, an `int` sum in the reference,
wraps at 32 bits where the reference's addition overflows. The check functions' load is the
reference's float quotient truncated and taken in its low 32 bits, which is what the reference's
conversion of a negative or oversized value to `uint32_t` yields on its targets (findings F187).

The reference prints three more columns, the late count, run count and required time, on the
platforms that keep late task statistics, the STM32 F4 and F7 among them. The port's scheduler keeps
no late task statistics yet (ROADMAP), so the port prints the reference's shorter form, the one its
simulator build prints. The columns come with the scheduler's late statistics.

The harness replays two sequences of 649 lines, recorded from the oracle with the reference's
scheduler and task table linked in and the stack check, BST, DroneCAN and camera control tasks
compiled, so its task ids match the port's table: task statistics stored in the reference's raw
units, realistic or anywhere in the 32-bit range, tasks queued and dequeued, the clock moved
forward, back and past half its range, check function statistics, debug modes and cycle counts, task
statistics switched on and off, and `tasks` commands. All 692842 reply characters match the
reference's, and so does the configuration's hash after every command.

## D199. Command line save and exit (2026-10-15)

`save` prepares the save. Inside a batch that printed an error, it prints the batch warning and the
error lines `ERRORS WERE DETECTED - PLEASE REVIEW BEFORE CONTINUING` and `PLEASE FIX ERRORS THEN
'SAVE'`, closes the batch and stops. Otherwise it stores the board's information in the
configuration when a command updated it, and its signature when a command updated it and none is
stored, and takes both in again. It then marks the configuration configured, asks for its write,
prints `# saving` and asks for the restart, which `noreboot` withholds. `exit` prints `# leaving CLI
mode, unsaved changes lost`, or `# leaving CLI mode, no reboot` after `noreboot`, asks for the
command line's end and, without `noreboot`, for the restart. `defaults` without `nosave` resets as
with it, prepares the save the same way, and asks for the write and the restart. The restart prints
`Rebooting` after an empty line. The requests are the `Effects` fields `Save`, `Reboot` and `Leave`.
`Process_Line` loses `Handled`, since every line is handled now.

The reference's write runs its configuration fix before storing. In adaflight the fix belongs to the
storage layer (D158, D167), which runs it on the `Save` request with the hardware facts the command
line does not hold, so the command line's configuration keeps the unfixed values until the runtime
answers the request. The oracle's write is a stub for the same reason, and the recorded hashes
contain no fix.

A reset keeps the board's information. The board group's reset writes the information and the
signature the board has taken in back into the reset group, in `Reset_Board_Config`, so `defaults`
after a save keeps them, and so does a reset of that group alone. The earlier `defaults` left them
out, which the save vectors found: no earlier sequence had saved board information before a reset.

The harness replays two sequences of 500 lines: saves and exits with and without `noreboot`, resets
with and without `nosave` and by group, board names, manufacturers and signatures before saves,
batches with and without errors before saves, settings and diffs. All 52799 reply characters match
the reference's, and so do the configuration's hash after every command and the write, restart and
leave requests of every line.

## D200. Scheduler late task statistics (2026-10-15)

The STM32 builds of the reference keep the late task statistics, which the simulator build the
scheduler was first recorded from leaves out. Each task now counts its runs and its runs that ended
past their anticipated end, and keeps the execution time anticipated for its latest selection. The
scheduler counts, over a timing window of one second from the first realtime pass after the last
window's end, the tasks run from the selection, the late ones among them, the serial task excepted,
and the cycles they ran late by. At the window's end it keeps their share in tenths of a percent,
`CPU_Percentage_Late`, which the arming check compares with `cpu_late_limit_permille` (the check
comes with the arming port, ROADMAP). The reference measures the gyro cycle time's mean and
deviation and the extremes of the gyro interrupt period in the same block, for its debug values
alone. adaflight keeps no debug values, so these stay out, and so does the per-task debug output of
the task the `scheduler_debug_task` setting names.

The first window of a boot ends on the first realtime pass, before any task ran from the selection,
so the reference divides the late count by zero there. Its Cortex-M targets run with the
divide-by-zero trap off and take a zero quotient. adaflight gives zero for a window without a run,
and the oracle, whose host traps the division, steps over it with a zero quotient (findings F188).

The oracle compiles the reference's scheduler with the statistics and records three more fields per
task and five more per pass. All 8 sequences of 2500 passes replay exactly, the new fields with the
old.

## D201. Tasks command late columns (2026-10-15)

With the scheduler's late task statistics (D200), `tasks` prints the full form: after the total
time, each queued task's late run count, its run count and the execution time anticipated for its
latest selection, under the header's `late`, `run` and `reqd/us`. The reset after each line clears
the two counts with the peak times. The shorter form of D198 was the simulator build's. The STM32
builds print this one.

The harness replays the two sequences of D198 recorded again with the late statistics compiled into
the oracle and three more raw fields per task line. All 985116 reply characters match the
reference's, and so does the configuration's hash after every command.

## D202. Arming load check (2026-10-15)

With the scheduler's late task statistics, the arming status update sets the `LOAD` disable reason
while the scheduler's late task share of its last timing window, in tenths of a percent, is above
`cpu_late_limit_permille`, and clears it otherwise, between the angle and the calibration reasons.
The share reaches the arming logic as the input `Late_Permille`, which the runtime takes from
`Scheduler.CPU_Percentage_Late`, and the limit through the arming settings, which
`Config_Runtime.Arming_Settings_Of` now reads from the scheduler group.

The arming oracle compiles the reference's status update with the statistics, scripts the share per
step with values below, at and above the limit and past the signed range, and scripts the limit at
its default or anywhere in its range. All 30 sequences replay exactly.

## D203. MSP tuning writes (2026-10-15)

`Adaflight.MSP_Tuning_In` contains the MSP in messages that write the tuning to the stored
configuration: the PID gains, the rate tuning, the arming configuration, the PID controller, the
accelerometer trims, the 3D throttle, the deadbands, the reset of the current PID profile, and the
sensor and board alignments. The gains and the PID reset act on the PID profile the configuration's
system group selects, and the rates on its rate profile.

Each message reads its fields in the message's order into a list of setting writes, checks every
write against its setting's range, and makes the writes only when all pass, so a request with one
field outside its range is an error that changes nothing (D6). The range is the setting's bounds for
a direct setting and a named value of its table for a lookup setting, from
`Adaflight.Settings_Table`, and `Config_Groups.Set` makes each write as the command line does. The
heading item's three gains and the gyros in use have no setting, so any byte goes to them. A request
reads zero past its end and its remaining length stops at zero. The rate tuning with fewer than ten
bytes is an error, and its optional fields follow from the remaining length. The pitch rate and expo
take the roll's new value while they equal the roll's. The PID reset restores the profile's
defaults. `Effects` asks the runtime to take the PID settings in again after the gains, and to set
up the stick processing again after the rate tuning.

The command line oracle hands the reference's MSP processor each request through a directive and
puts the configuration back after a request outside the ranges, which the generator marks by
decoding the request as the reference reads it. The harness replays two sequences of 600 lines, 1036
requests among profile selections, stored roll and pitch values and resets: 882 within their ranges,
whose results, runtime work and configuration hashes all match the reference's, 10 short rate
tunings that both reject, and 144 outside the ranges, each an error that leaves the configuration
unchanged.

## D204. MSP filter and advanced writes (2026-10-15)

`Adaflight.MSP_Tuning_In` gains the advanced configuration, filter configuration and advanced PID in
messages, under the same whole-request range check as D203. The advanced configuration writes the
PID loop's divider, the motor update mode, protocol, rate, idle value and inversion, the gyro's
range, calibration and overflow settings, and the debug mode. The filter configuration writes the
gyro's and the D term's lowpasses and notches, the dynamic lowpasses, the dynamic notch, and the RPM
filter with its fade range, Q and harmonic weights. The advanced PID message writes the feedforward,
acceleration limit, angle limit, anti gravity, I term relax, throttle boost, acro trainer, D max,
motor output limit, profile cell count, dynamic idle, feedforward smoothing, sag compensation,
thrust linearization and TPA settings. Each reads its optional groups as the remaining length
reaches them, and the filter message's first gyro lowpass arrives in one byte before its later
16-bit value.

The reference's own limits count as ranges: an RPM filter weight above 100 is outside its range,
though the weights' setting has none, and a dynamic notch count above seven, an RPM filter Q or fade
range outside its limits or a feedforward averaging above three already are outside their settings'
ranges. The TPA rate is held at 100, so it never makes a request an error. The advanced
configuration and the filter configuration end with the gyro's checks of the configuration fix
(D167), which read the gyro's sample rate the caller passes in. `Effects` asks the runtime to set up
the gyro's and the PID controller's filters again after the filters, and to take the PID settings in
again with the motor output endpoints and the mixer's profile after the advanced PID message.

The command line oracle links the reference's motor source for the protocol check of the fix and
gains a directive that sets the gyro's sample rate. The harness replays two sequences of 700 lines,
1210 requests among sample rates, stored motor protocols, bidirectional DShot, profile selections
and resets: 944 within their ranges, whose results, runtime work and configuration hashes all match
the reference's, and 266 outside them, each an error that leaves the configuration unchanged, 11 of
them ones the reference also rejects after its partial writes.

## D205. MSP receiver writes (2026-10-15)

`Adaflight.MSP_Receiver_In` contains the MSP in messages that write the receiver's configuration: a
mode range, the receiver settings, the RSSI channel, an adjustment range, the channel map, the
failsafe settings and a channel's failsafe value. `Adaflight.MSP_Write_Plans` now contains the
request readers, the write plans and the range check that the tuning writes and these share.

The receiver and failsafe settings, the RSSI channel and the ExpressLRS id and model go through
setting writes checked as a whole (D6). The air mode threshold arrives as a pulse and is stored as a
tenth of the pulse past 1000, in integer division. The stick smoothing factor is held to its bounds.
The SPI receiver's id and channel count have no setting, so any value goes to them. A change to a
stick smoothing cutoff, factor or switch asks for a restart in `Effects`.

Mode ranges, adjustment ranges, channel failsafe values and the channel map have no settings, so
their fields take the bounds of the command line commands that write them: an aux channel below 14,
steps up to 48, mode logic OR or AND, an adjustment function below 34, a failsafe mode of automatic
or hold for a stick and hold or set for an aux channel, and a channel map that is a permutation of
the eight channels. A slot or channel past its count and an unknown mode are errors in the reference
as well. The mode and the linked mode come by permanent id from the box table (D89). A channel's
failsafe value is stored as a step from its pulse held to the pulse limits. `Effects` asks the
runtime to take the mode conditions in again after a mode range and to clear the active adjustment
ranges after an adjustment range.

The harness replays two sequences of 700 lines from the command line oracle, 1265 requests among
resets and listings: 983 within their ranges, whose results, runtime work and configuration hashes
all match the reference's, 39 that both reject before writing, and 243 outside the ranges, each an
error that leaves the configuration unchanged, 4 of them ones the reference rejects after writing.

## D206. MSP hardware writes (2026-10-15)

`Adaflight.MSP_Hardware_In` contains the MSP in messages that write the mixer type with the yaw
motor reversal, the sensor hardware selections, the motor limits, pole count, bidirectional DShot
and motor KV, the GPS link, the compass declination, and the GPS rescue with its autopilot limits
and controller gains, under the same whole-request range check as D203. Each optional group is read
whole when the bytes remaining at its position cover it and skipped otherwise, so a later group can
follow a skipped one at the same position. The mixer type has no setting and takes the command line
mixer's bounds, one of the 27 named mixers. Gains and angles that arrive as 16-bit values for 8-bit
fields are checked as they arrive. None of these messages asks the runtime for work. The mixer and
the sensors take a new value at the next start.

The harness replays two sequences of 600 lines from the command line oracle, 1108 requests among
resets and listings: 895 within their ranges, whose results and configuration hashes all match the
reference's, and 213 outside them, each an error that leaves the configuration unchanged.

## D207. MSP battery writes (2026-10-15)

`Adaflight.MSP_Battery_In` contains the MSP in messages that write the battery meter's scale,
divider and multiplier, the battery and virtual current meters' scale and offset, and the battery's
cell voltages, capacity and meter sources, under the same whole-request range check as D203. The
meter messages name their meter by id, battery 10 or virtual 80. Another id writes nothing and is
not an error, since this build has no other ADC meters. The battery message needs seven bytes, takes
the cell voltages in tenths of a volt or, when six more bytes follow, in hundredths, and puts them
and the capacity into the current battery profile. Cell voltages out of order, a minimum above the
warning or a warning above the maximum, are an error, checked with the ranges before any write.

The command line oracle now enters the reference's MSP processor through its common in-command
handler, which holds these messages and hands the rest to the flight controller's. The earlier MSP
recordings replay unchanged. The harness replays two sequences of 600 lines, 1083 requests among
battery profile selections, resets and listings: 812 within their ranges, whose results and
configuration hashes all match the reference's, 38 short battery requests that both reject, and 233
outside the ranges, each an error that leaves the configuration unchanged, 24 of them ones the
reference rejects after writing the meter sources.

## D208. MSP feature writes (2026-10-15)

`Adaflight.MSP_Feature_In` contains the MSP in messages that replace the features in use, write the
beeper conditions with the DShot beacon's tone and conditions, and write the motor output order,
under the same whole-request check as D203. The feature mask may hold only the features the command
line's feature command names, and the beeper and beacon masks only the conditions its beeper and
beacon commands switch. The beacon's tone takes its setting's range and arrives when a byte remains,
the beacon conditions when four more remain. The motor order message names a count and that many
positions up to eight, and the motors past the count keep their own place. A request without the
count or with fewer positions than it names is an error, in the reference as well. The order's
setting has no range, so any position goes in, and the storage layer's fix checks it at the save
(D199).

The harness replays two sequences of 600 lines from the command line oracle, 1090 requests among
resets and listings: 957 within their ranges, whose results and configuration hashes all match the
reference's, 70 short motor order requests that both reject, and 63 outside the ranges, each an
error that leaves the configuration unchanged.

## D209. MSP blackbox write (2026-10-15)

`Adaflight.MSP_Blackbox_In` contains the MSP in message that writes the flight log's device, sample
rate and fields left out, under the same whole-request check as D203. A log past its stopped state
takes no change and the message succeeds. The sample rate comes from its own byte held at 1/16 when
the bytes reach it, or else from the intra to delta frame ratio: given when two bytes remain after
the legacy rate, or else from the legacy rate's numerator and denominator through
`Blackbox.P_Denominator`, cut to 16 bits, and turned into a rate for the PID loop time by
`Blackbox.Sample_Rate_For`. The fields left out arrive when four bytes remain and may hold only the
bits the disable settings name. The message reads the recorder's state and intra frame interval and
the loop time from its caller.

The command line oracle copies the reference's blackbox object with the log state and the intra
frame interval made global and sets them, with the loop time, from a directive. The harness replays
two sequences of 700 lines, 1111 requests among log states, intervals, loop times and resets: 1020
within their ranges, whose results and configuration hashes all match the reference's, and 91
outside them, each an error that leaves the configuration unchanged.

## D210. MSP servo writes (2026-10-15)

`Adaflight.MSP_Servo_In` contains the MSP in messages that write a servo's parameters and a servo
mix rule. Neither has settings, so their fields take the bounds of the command line's servo and smix
commands (D6, D203): pulses from 500 to 2500 with the middle between the minimum and the maximum, a
rate within 100 either way, a forwarded channel below 18, where a negative one turns forwarding off,
reversed sources among the 14 inputs, and for a rule a range within 0 to 100 with its minimum below
its maximum and a box up to 3. A servo parameter request of other than thirteen bytes, a servo or
rule past its count, and a target or input past its count are errors in the reference as well.
`Effects` asks the runtime to load the servo mixer's rules again after a rule.

The harness replays two sequences of 600 lines from the command line oracle, 1082 requests among
resets and listings: 767 within their bounds, whose results, runtime work and configuration hashes
all match the reference's, 149 that both reject before writing, and 166 outside the bounds, each an
error that leaves the configuration unchanged.

## D211. MSP LED writes (2026-10-15)

`Adaflight.MSP_LED_In` contains the MSP in messages that write the LED strip's sixteen colors, one
LED's packed configuration and a mode color. Their fields have no settings and take the bounds of
the command line's color, led and mode_color commands (D6, D203):

- a hue up to 359
- a configuration whose function is one of the ten and whose overlays are among the seven, in a
  request of five bytes, or six with the strip's profile within its setting's range, for a LED below
  32
- a mode up to 5 with a direction up to 5, the special colors with an index up to 10, or the aux
  channel with index 0, with a color below 16

The reference rejects a LED configuration of other than five bytes, so the profile byte never
arrives there (finding F192), and a mode color outside those cases as well. `Effects` asks the
runtime to evaluate the strip's layout again after a LED configuration.

The harness replays two sequences of 600 lines from the command line oracle, 1083 requests among
resets and listings: 859 within their bounds, whose results, runtime work and configuration hashes
all match the reference's, 106 that both reject before writing, and 118 outside the bounds, each an
error that leaves the configuration unchanged.

## D212. MSP text writes (2026-10-15)

`Adaflight.MSP_Text_In` contains the MSP in messages that write the craft name, a text by its type,
the LED strip's brightness and rainbow, and a battery profile. The name message clears the craft
name and takes up to 16 of the request's bytes. The text message takes a type, then a length byte
cut at the text's room: 16 for the pilot name, the craft name and the four custom messages, 8 for
the current PID, rate and battery profile names. It writes the text and a zero after it and leaves
the bytes after that zero as they were. A type outside those is an error. Texts take any bytes,
since they have no range. `Effects` asks the runtime to analyze the OSD's active elements again
after a craft or pilot name.

The LED strip values and the battery profile take the whole-request check of D203. The battery
profile message needs at least thirteen bytes, a profile below 3, the minimum, warning, full and
maximum cell voltages in that order, at most 24 cells and at most 100 percent. Each voltage must
then lie within 1.00 V to 5.00 V and the capacity within 20000 mAh, as their settings hold them. The
reference stores a brightness past 100, which its LED driver wraps (findings F193), and a maximum
cell voltage of zero, which its cell count detection divides by (findings F194).

The harness replays two sequences of 600 lines from the command line oracle, 1045 requests among
profile selections, resets, name sets and listings: 810 within their bounds, whose results, runtime
work and configuration hashes all match the reference's, 163 that both reject before writing, and 72
outside the bounds, each an error that leaves the configuration unchanged.

## D213. MSP peripheral writes (2026-10-15)

`Adaflight.MSP_Peripheral_In` contains the MSP in messages that write the wing's tuning and the race
transponder's configuration. The wing message needs 45 bytes and writes the current PID profile's S
gains, setpoint attenuation centers, widths and modes, TPA curve and speed settings, yaw type and
angle pitch offset. These fields have settings only in builds with the wing options, which this
settings table leaves out, so any value goes to them (D203). `Effects` asks the runtime to take the
PID settings in again after the wing's tuning.

The transponder message takes a provider up to the three and, for one of them, exactly its data's
length: 6 bytes for ILAP, 9 for ARCITIMER and 1 for ERLT. The stored data is cleared before the
request's is written, and `Effects` asks the runtime to encode the transponder's data again. A
request without a provider, a provider past the three or data of another length is an error that
changes nothing (D6). The reference stores the provider before it checks the length, and its stop of
the repeating transmission on a provider change never runs (findings F195). `Effects` has no stop
request, so a provider change leaves the transmission repeating in adaflight as well.

The harness replays two sequences of 600 lines from the command line oracle, 1053 requests among
profile selections, resets, transponder sets and listings: 878 within their bounds, whose results,
runtime work and configuration hashes all match the reference's, 117 that both reject before
writing, and 58 transponder requests the reference rejects after storing the provider, each an error
that leaves the configuration unchanged.

## D214. MSP VTX table writes (2026-10-15)

`Adaflight.MSP_Peripheral_In` gains the MSP in messages that write a VTX table band and a VTX table
power level. A band write takes a band, a name whose first eight bytes are kept in upper case, a
letter in upper case, a factory flag, and a count with that many 16-bit frequencies. A request
shorter than its name, its three fixed bytes or its frequencies is an error, and so is a band past
the table's band count. The band's frequencies up to the table's channels come from the request,
zero past those it gives, and its name is kept to its first zero byte and padded with spaces to
eight. When the band is the VTX's, the VTX frequency follows the VTX channel. That write takes the
whole-request check of D203, so a frequency past the setting's 5999 MHz is an error. A power level
write takes a level within the table's count, a value, and a label kept to three bytes in upper
case. Names, letters, factory flags and table frequencies take any byte or value, as texts do in
D212. `Effects` asks the runtime to set the VTX table up again at the next configuration write and
to mark the MSP transmitter ready for the requesting link.

The command line oracle defines the reference's MSP transmitter ready call, which its build makes
but did not link, and reads the table's pending setup from the MSP source. The harness replays two
sequences of 600 lines, 993 requests among table counts, VTX band and channel sets and listings: 797
within their bounds, whose results, runtime work and configuration hashes all match the reference's,
181 that both reject before writing, and 15 band writes whose VTX frequency is outside its range,
each an error that leaves the configuration unchanged.

## D215. MSP control writes (2026-10-15)

`Adaflight.MSP_Control_In` contains the MSP in messages that act on the board: the flash erase, the
arming switch of the MSP links, the accelerometer and compass calibrations, and the configuration
write. They read the board through `Board`: armed, the SPI receiver running, and the request's link
with whether it is the telemetry link. The arming switch keeps a bit per link in `Link_State`. A
nonzero command byte sets the request's link's bit and the MSP arming reason, disarms an armed
board, and turns the runaway takeoff prevention's temporary disable off. A zero byte clears the
link's bit. Once no link holds arming off, it clears the reason and sets the temporary disable to
the request's second byte. A calibration starts only while disarmed. The configuration write is an
error while armed. Otherwise it has the scheduler ignore the current task's state time, and either
marks the configuration configured and asks for it to be written and read back, or, for a request
over the telemetry link with the SPI receiver running, asks for the same after a delay. `Effects`
hands each request to the runtime. No field has a setting to check.

The command line oracle defines the arming flags, the arming reason setters, the telemetry link's
descriptor, the delayed dispatch and the flash erase, which the reference's MSP code calls and the
oracle did not link, and counts the calibrations, the scheduler call, the configuration read, the
disarm and the runaway takeoff call. A directive sets the armed flag and the request's and the
telemetry link's descriptors, and takes the configured features in as the running ones, as at boot,
since the delayed write reads the running SPI receiver feature. The harness replays two sequences of
600 lines, 919 requests among those directives, SPI receiver feature commands and resets: every
result, runtime request, MSP arming reason and configuration hash matches the reference's, with 69
configuration writes while armed rejected by both.

## D216. MSP OSD writes (2026-10-15)

`Adaflight.MSP_OSD_In` contains the MSP in messages that write the OSD's configuration and its
canvas, under the whole-request check of D203. The configuration message's first byte picks its
part. Byte 255 writes the general settings: the video system, the units and the RSSI, capacity and
altitude alarms, then while bytes remain the warnings in 16 and then 32 bits, a profile, the stick
overlay, the camera frame and the link quality and RSSI dBm alarms. A video system that switches to
HD takes the HD canvas and the MSP display port, and one that leaves HD takes the SD canvas for its
system and the automatic display port. A profile up to the three is taken up, with the OSD's
elements analyzed again. A profile byte past three changes nothing, and profile 0 lies outside its
setting's range. Byte 254 writes a timer, within the two. The reference also accepts index 2 and
writes past its timers (findings F196). Any other byte is an element: a statistic's switch on the
post flight screen 0, or an element's position on a flight screen, with its elements analyzed again.
The canvas message writes the canvas size and, for a board not yet in HD with the MSP display port,
switches to both, marks the configuration configured, and asks for a write and a restart.

The command line oracle now counts the OSD element analyses through a weakened copy of the
reference's OSD object, since the profile change calls the analysis from inside it, and counts the
profile changes with their value. The harness replays two sequences of 600 lines, 1054 requests
among video system sets, resets and listings: 776 within their bounds, whose results, runtime work
and configuration hashes all match the reference's, 66 that both reject before writing, and 212
outside the bounds, each an error that leaves the configuration unchanged.

## D217. MSP profile writes (2026-10-15)

`Adaflight.MSP_Profile_In` contains the MSP in messages that select a profile and copy one profile
over another. The selection byte names a battery profile when its battery bit is set, else a PID
profile when its rate bit is clear, else a rate profile. An index past its list selects the first. A
PID profile is selected only while the board is disarmed. `Effects` asks the runtime to take the
selected profile up: for a PID profile the PID settings, motor output endpoints, mixer profile and a
confirmation beep per profile number, for a rate profile the stick processing, and for a battery
profile its thresholds. The copy message copies a whole PID profile for kind 0 or rate profile for
kind 1, name included, from a source onto a different destination, both within their list, and asks
the runtime for nothing. Every request succeeds.

The command line oracle links the reference's PID profile copy, which it had not linked, with the
PID initializations the oracle stubs left weak in that object, and counts the profile changes
through wraps that call the reference's functions. The harness replays two sequences of 600 lines,
770 requests among armed and disarmed directives, profile selections, PID and rate settings and
names, and resets: every result, runtime request and configuration hash matches the reference's.

## D218. MSP VTX configuration write (2026-10-15)

`Adaflight.MSP_VTX_In` contains the MSP in message that writes the video transmitter's settings,
under the whole-request check of D203. Its first 16-bit field up to 63 encodes a band and channel,
whose frequency comes from the running table when a transmitter is present. Up to 5999 it is a
frequency with no band. Past that it writes nothing. While bytes remain the message then takes the
power with a pit mode, the low power while disarmed, the pit mode frequency, the band, channel and
frequency again, the frequency again from the running table for a nonzero band, and the table's
band, channel and power level counts, up to eight each, with a byte that clears the table. A
transmitter of a known type whose pit mode differs from the request's is asked for the request's pit
mode, and every accepted request marks the MSP transmitter ready. The reference makes its writes and
the pit mode call before it checks the table counts (findings F197).

`Adaflight.VTX_Table_Store` contains the clearing of the stored table's bands, channels, power
values and power labels, and the running table taken from the stored one, as at boot. The command
line uses the same clearing.

The command line oracle links the reference's transmitter interface and scripts a transmitter, its
type and its pit mode with a directive that can also take the stored table in as the running one.
The harness replays two sequences of 600 lines, 943 requests among transmitter scripts, table
commands, listings and resets: 754 within their bounds, whose results, runtime work and
configuration hashes all match the reference's, and 189 outside them, 22 of them table counts past
eight, each an error that leaves the configuration unchanged.

## D219. MSP runtime writes (2026-10-15)

`Adaflight.MSP_Runtime_In` contains the MSP in messages that hand the board running values: the
receiver's channels, a GPS solution, the transmitter's RSSI and the clock. None writes the
configuration. The raw receiver message takes as many 16-bit channels as the request holds whole, up
to eighteen, and is an error past them. `Effects` hands the frame on with zero for the channels it
leaves out, for `MSP_Receiver.Frame_Receive`. The raw GPS message gives the fix, the satellites, the
latitude and longitude as signed 32-bit values, the altitude in meters scaled to centimeters and the
ground speed, as an MSP update. The transmitter information message gives the RSSI byte, and the
clock message gives seconds as a signed 32-bit value and milliseconds, combined into milliseconds
since the epoch.

The command line oracle records the frame, the GPS solution with its fix and update flag, the clock
and the RSSI the reference hands on, through stubs for the functions it did not link and wraps for
the rest. The harness replays two sequences of 600 requests: every result and handed-on value
matches the reference's, with 41 frames of more than eighteen channels rejected by both.

## D220. MSP board writes (2026-10-15)

`Adaflight.MSP_Board_In` contains the MSP in messages that set the board's information and its
signature and reset the configuration. Board information is a name and a manufacturer, each a length
byte and that many bytes, kept to their first 20 and 4 bytes and to their first zero byte. A board
that holds its information already, or a request shorter than its declared lengths, makes it an
error. A signature is 32 bytes, zero past the request's end, and a board that holds one already
makes it an error. Each is stored and taken in again through `Board_Info`. The reset, while
disarmed, gives the reset configuration of `Config_Reset`, asks for the configuration's write and a
restart after the reply, and answers 1. Armed, it changes nothing and answers 0.

`Adaflight.Board_Info` contains the board's information as the board holds it: the name and
manufacturer, the signature, whether the stored configuration set each, and whether a command
changed them, with how the board takes them in at start, stores and persists them, and writes them
back into a reset configuration. `Adaflight.Config_Reset` contains the configuration reset: the
defaults, the simplified tuning applied to every PID profile, and the board's information kept. The
command line uses both, and the stored VTX table clearing of `Adaflight.VTX_Table_Store` (D218), in
place of its own copies. Its names for the moved types stay as subtypes and renamings. We moved them
out of the generic command line, whose types exist once per instance, so these messages can share
them.

The command line oracle hands the reset to the reference's out command processor and records its
reply byte and the restart it schedules. The harness replays two sequences of 600 lines, 829
requests among board stores, armed and disarmed directives, board commands, saves and resets: every
result, reply, runtime request and configuration hash matches the reference's, with 525 requests for
information or a signature the board already holds, or shorter than declared, rejected by both.

## D221. MSP motor test (2026-10-15)

`Adaflight.MSP_Motor_In` contains the MSP in message that sets the motors' values while disarmed,
which a configurator's motor test sends. It takes a 16-bit value per motor of the mixer and is an
error when the request holds fewer. Bytes past them are ignored. Each value converts for the motor
protocol: unchanged for analog pulses, through `DShot.From_External` with the running 3D feature for
DShot, and zero without a motor device. `Effects` hands the values on for the mixer's disarmed
outputs.

The command line oracle links the reference's DShot source with its unit-test definitions, scripts
the motor device's kind and the mixer's motor count with a directive, and reads the disarmed motor
values after each request. The harness replays two sequences of 600 lines, 1049 requests among
device scripts and 3D feature changes: every result and all 8392 disarmed values match the
reference's bit for bit, with 105 requests short of the motor count rejected by both.

## D222. MSP OSD font character write (2026-10-15)

`Adaflight.MSP_Font_In` contains the MSP in message that writes an OSD font character, which a
configurator's font manager sends. The request's length picks the form: from 66 bytes a 16-bit
address and the full 64-byte character, at 65 an 8-bit address and the full character, from 56 a
16-bit address and the 54 visible bytes, and below that an 8-bit address and the visible bytes, read
as zero past the request's end. Without an OSD display port the message is an error. `Effects` hands
the character to the display port, whose answer decides the message's result, and a character the
port takes marks the font updated for the next restart. The bytes a visible-only character leaves
out are zero, where the reference sends whatever its stack holds (findings F198).

The command line oracle links the reference's display driver and scripts the OSD display port,
whether it is present and whether it takes a character, with a directive. The harness replays two
sequences of 600 lines, 1079 requests among port scripts: every result, address, font update flag
and all 51884 character bytes the requests give match the reference's, with 337 requests rejected by
both, for a missing port or one that refuses the character.

## D223. MSP restart and DShot commands (2026-10-15)

`Adaflight.MSP_Control_In` gains the MSP messages that restart the board into a mode and send DShot
commands to the motors. The restart, an error while armed, takes a mode below five, the firmware
when the request leaves it out, and answers it back. For mass storage the file system's readiness
follows in the reply, and only a ready one restarts. The restart waits out a delay over the
telemetry link with the SPI receiver running, as the configuration write does. The mass storage mode
with UTC time takes the same check, where the reference restarts without it (finding F199, amended
2026-10-25 as declared in D6). The DShot command message, while disarmed, takes a command type, a
motor, a count and that many commands, and is an error when the request holds fewer. Armed, it does
nothing. `Effects` contains the restart with its mode, the reply, and the commands for the motor
command queue, with the motors switched off around blocking ones. `Board` gains the mass storage
readiness.

The command line oracle routes the restart through the reference's out command processor, records
the DShot command calls and the motor switching, and scripts the mass storage readiness with a
directive. The harness replays two sequences of 600 lines, 907 requests among armed, link, feature,
mass storage and motor scripts: every result, reply, restart, delay and DShot command matches the
reference's, with 159 rejected by both. The MSP device vectors, which hold the restart requests with
the readiness scripted either way, were regenerated on 2026-10-25 against the reference's restart
message with the same check.

## D224. MSP GPS sensor (2026-10-15)

`Adaflight.MSP_Runtime_In` gains the MSP GPS sensor message. It gives the time of week, the fix, the
satellites, the horizontal, vertical and speed accuracies scaled from centimeters to millimeters,
the dilution of precision, the position, the altitude in centimeters, the ground speed as the length
of the north and east velocities, and the ground course within a turn in tenths of a degree, as an
MSP update. The instance, the week, the down velocity, the yaw and the date and time are read and
left. `Effects` says whether the sensor fields came, since the raw GPS message leaves the time, the
accuracies, the dilution and the course as they were.

One guard covers the reference's undefined behavior: the squares of the velocities are summed in 64
bits and the speed saturates at 65535 cm/s, where the reference's 32-bit signed sum overflows past
46340 cm/s and for a velocity read in part from a short request (finding F201). No recorded vector
reaches the guard.

The command line oracle records the time, the accuracies, the dilution and the course beside the
solution. The harness replays two sequences of 600 requests, 925 sensor messages of every length
around their 52 bytes and 275 raw GPS messages: every handed-on value matches the reference's.

## D225. MT rangefinder and optical flow bridge (2026-10-15)

`Adaflight.MT_Sensor` contains the bridge an MT device uses to send its distance and its flow over
MSP, and `Adaflight.MSP_Runtime_In` gains the two messages, which hand on the distance in
millimeters and the flow's quality and motion. Both read zero past a short request's end, where the
reference reads past the payload (finding F200). The configured rangefinder hardware picks the
device: MTF01, MTF02, MTF01P or MTF02P with its delay and range, none otherwise. A distance is new
until a read takes it, which gives the distance in centimeters or out of range for a negative one,
and no new data after. A flow message stamps its sample, and the interval since the last sample,
valid within a second, turns the motion into rates and the quality into percent. The distance gives
the range validity at 80 mm or more and no older than five of the device's delays, and an invalid
range or a stale distance replaces the quality with its code. The distance's time starts at the no
new data code (finding F202), and the 80 mm minimum is the one the reference also gives the device
as centimeters (finding F203). The unit is SPARK for the interval's division and the bounds it hands
on.

A flow message before an MT device is detected changes nothing, where the reference reads the
missing device's delay through a null pointer (finding F200). A read holds a distance at the
rangefinder readings' bound of 40000 cm, and a flow sample holds its rates at the optical flow
readings' bound of 1e6 rad/s. No recorded vector reaches these guards.

The command line oracle compiles the reference driver in, scripts the detection and the rangefinder
read with directives, and records the driver's state after each and after each message. The harness
replays two sequences of 600 lines among clock steps, detections, reads and messages of every
length: in 820 records every distance, read, time stamp, quality, rate and validity matches the
reference's.

## D226. CRSF device frames and link type (2026-10-15)

`Adaflight.CRSF` hands on the frames the CRSF telemetry and the menu system take from the receiver:
a ping asks for the device information reply, a device information frame goes to the telemetry from
its payload, and a display port command and an MSP request or write go on from the byte after the
destination and origin, the MSP frame when its length is four or more. `Adaflight.CRSF_Telemetry`
gains the link type. While no device information reply has named the link, the negotiation pass
pings the receiver at most every quarter second, after a pending speed reply, a speed change and a
heartbeat. A reply whose serial number after the name is ELRS marks an ExpressLRS link and sets the
display port's chunk interval to 75 ms, which a later reply naming another link keeps. A telemetry
init leaves the link type, the ping time and the interval as they were. The full build compiles
these in with the menu system over CRSF.

One guard covers a reply without the name's end or four bytes after it: it marks a link other than
ExpressLRS, where the reference reads on past the frame (finding F204). No recorded vector reaches
the guard.

The receiver oracle counts the new frames with the first byte each handler takes, and the telemetry
oracle builds with the menu system's CRSF telemetry, an idle display port and a device information
reply now and then. The harness replays 6000 receiver steps and 6576 telemetry passes with 93872
frames, 41 of them pings: every output, link type and interval matches the reference's.

## D227. CRSF display port (2026-10-15)

`Adaflight.CRSF_Display_Port` contains the screen the menu system draws for the transmitter over
CRSF: up to nine rows of 32 characters, a write past the rows or columns dropped and one past the
last column cut, and the screen marked updated when a write changes it. A character write takes a
zero as nothing. A clear blanks the screen, marks it for a clear frame and holds the transfer back
45 ms. Registration takes the largest screen and clears it, at every CRSF telemetry init. The
transmitter's display port commands set the rows and columns and open the menu, leave it, or poll
it: a poll marks an open menu's screen for a clear frame and a full transfer, and opens the menu
otherwise. The menu opens while disarmed when none is open and the menu system can select this
display, and the caller sets the 400 ms delay after the menu's own clear.

`Adaflight.CRSF_Telemetry` sends the screen. With the event-driven gate open, a cleared screen gets
the clear frame. Once the delay has passed while the menu runs on this display, an updated screen
starts a batch over its rows and columns with the next of 63 batch numbers, and each pass past the
chunk interval sends a chunk: the batch, its index with the first and last chunk marked, and up to
50 bytes of the screen with a run of a repeated character as the character with its top bit set and
the run's length, 256 as zero. Each frame sent restarts the telemetry's cycle time. Readiness
compares the millisecond clock with the delay through the wrapping difference, where the reference
compares them directly (finding F205, D6). The units are SPARK for the screen's index bounds and the
chunk's room in its frame.

The CRSF telemetry oracle compiles the reference display port in, with the menu system's state, its
selection and its open and leave calls scripted. The harness replays 2123 display operations with
the 288 bytes of the screen after each, and 4451 telemetry passes with 116 chunks, eight of them
with a full 256-character run, and 479 clear frames: every screen, delay, request and frame matches
the reference's.

## D228. HoTT text mode (2026-10-15)

`Adaflight.HoTT_Telemetry` gains the text mode, which the full build compiles in with the menu
system. A request with the text mode id starts it: the telemetry task runs at 1 kHz with its period
kept for the return, a request is taken after 5 ms instead of 4 ms, and the bytes go out 1 ms apart
instead of 3 ms. A request for the text sensor answers with the screen, 172 bytes with the start,
escape and stop bytes, and turns the transmitter's button into a menu key: decrease up, increase
down, next right, previous left, and set leaves an open menu with a save. While the screen's escape
byte is clear the request opens the menu on this display when none is open. A request with the
escape byte set leaves the menu as it is, except that the previous button opens it, and the next
request clears the byte first. A binary request stops the text mode and restores the period and the
timings.

`Adaflight.HoTT_Display_Port` contains the menu system's side: characters within eight rows of 21,
strings a character at a time with the column stepping as a byte, a clear in spaces, the grab that
marks the screen as the menu's, the release that clears it and sets the escape byte, and a heartbeat
that leaves the menu with a save once the text mode has stopped. Its first registration clears a
display of no rows or columns, so the screen holds zeros until the menu's first clear. The units are
SPARK for the screen's indexes and the send position.

The HoTT oracle compiles the reference text mode and display port in, with the menu system and the
scheduler as counting stubs, and draws, clears, grabs, releases, heartbeats and changes their state
between task calls. The harness replays 15000 task calls: every byte sent, timing, period, menu
call, key and screen byte matches the reference's.

## D229. SRXL display port (2026-10-15)

`Adaflight.SRXL_Display_Port` contains the menu system's side of the Spektrum text generator: a
character goes to the text buffer through `Put_Char`, a string a character at a time with the column
stepping as a byte, and a clear writes spaces over the nine rows of twelve characters, then the
firmware's name at the top. While the menu does not hold the display, the clear adds the three lines
that tell how to open it. The release clears, and the registration at every SRXL telemetry init
releases and clears, so the generator shows the name and the three lines from the start. The caller
gives the name, which keeps it out of the code. The unit is SPARK for the column stepping.

The SRXL telemetry oracle compiles the reference display port in and draws, clears, grabs and
releases between task calls. The harness replays 12000 task calls: every text byte, line flag and
frame byte matches the reference's.

## D230. OSD navigation map (2026-10-15)

`Adaflight.OSD_Nav_Map` contains the map element of the full build's flight plan OSD: fourteen by
eight characters with home, the flight plan's waypoints and the flown trail, one row per call. A
frame is prepared at its first row. The craft and the waypoints are placed east and north of home
through the longitude difference folded across the antimeridian and the cosine of home's latitude.
The view is centred on home or on the craft, and with a position and the heading-up setting it turns
with the craft's heading through the approximate sine and cosine. The width comes from a table of
steps from 20 m to 51.2 km and is at least the configured minimum. It grows at once to fit the craft
and the first nine positional waypoints, and shrinks only once the required width is under eight
tenths of the smaller step. The border shows the up mark and, for 24 frames after a change of width
(18 for the first), the width in the selected unit, pulsing outward when the map zoomed out and
inward when it zoomed in.

Without home the map shows SET HOME or WAIT GPS. With home it draws, lowest first:

- a range ring of ticks at the largest round radius that fits
- the trail as one bar glyph per column for a shallow segment and one vertical bar per row for a
  steep one, clipped to the view, skipping a column whose bar sits within a row of the one already
  there
- the waypoint numbers with the executor's waypoint blinking
- home as a flag, or as an arrow on the nearest edge pointing to it
- the craft as an arrow, or within a cell of home as the over-home ring, or NO GPS without a fix

A row past the screen's bottom or right edge ends the frame, and a row is cut at the right edge.

The latitude difference wraps in 32 bits, and the longitude difference is taken in 64 bits and
folded across the antimeridian, as the GPS link's are (finding F58, D6). Rounding follows the C
library's ties to even, exact past 2 ** 24. The unit is SPARK for the float bounds of the projection
and the clipping, and the cell indexes. Its place in the OSD's item list comes with the flight plan
items.

The oracle compiles the reference element in with the reference OSD helpers and GPS module, and sets
the trail, the flight plan, the executor's waypoint and the craft per frame. The harness replays
1200 frames in 8183 rows: every row's text, offset, flags, width and frame state matches the
reference's.

## D231. OSD flight plan items (2026-10-15)

The OSD units first followed a build without flight plan, navigation map and pitot, with 89 items
(D102). The full build has 99, and the stored configuration, the settings and the MSP OSD writes
already contain their positions. `Adaflight.OSD_Elements` gains the eight waypoint items and the map
before position hold ready, and the airspeed after it, in the reference's order, which moves
position hold ready from 88 to 97. While a GPS is present the active list adds the waypoint items
and the map after the efficiency item, and it adds the airspeed last. With every item visible the
adds reach 101 against the reference's array of 99 (finding F106), and the list is sized to 101. The
MSP OSD replies send the 99 positions.

`Adaflight.OSD_Render` renders the new items. Without a stored plan the waypoint number, next
number, coordinates and altitude show a hyphen, and an executor's waypoint past the plan's end is
held to the last. The number shows as WP with the waypoint's number and the plan's count, and the
next number as NEXT with the following waypoint's number, or a hyphen at the last. Coordinates print
in degrees with seven decimals. The altitude goes through the altitude formatter as a value above
mean sea level, which is how a waypoint stores it: the sea-level variants show it as stored and the
launch point variants show it less the launch point's altitude above sea level, the craft's altitude
above sea level less its estimated altitude. The reference's formatter replaces the altitude its
sea-level variants are given with the craft's altitude above sea level, so those variants show the
craft's altitude, and its launch point variants show the stored sea-level value (finding F206,
amended 2026-10-26 as declared in D6). A stored waypoint altitude can take any 32-bit value, so the
float printer now takes values to 2e9 after scaling: past 2 ** 24 the scaled value is whole and is
taken without rounding. The executor's distance, bearing and time to the waypoint show a hyphen when
the executor gives none. The distance rounds to whole metres with ties to even, the bearing less the
heading gives the direction arrow, and the time prints as minutes and seconds. The airspeed shows
the pitot's speed in the selected unit, or a hyphen without the sensor. The map draws through
`Adaflight.OSD_Nav_Map` (D230) with its settings from the stored configuration.

The OSD oracles now compile the reference with flight plan, map and pitot. The element, render,
draw, task and MSP OSD recordings change with the item list and are recorded again, and the other
OSD recordings do not change. A new waypoint oracle renders the nine items with random plans,
executor values, units, headings and airspeeds. The harness replays 3000 renders: every text byte
and draw flag matches the reference's, with 14 waypoint altitudes past 400 km.

## D232. OSD flight plan warnings (2026-10-15)

`Adaflight.OSD_Warnings` gains the full build's flight plan cues in the reference's order. The
rescue failure also shows while the flight plan's rescue descent is active. The position hold
failure gives way to a mission abort, and below it the autopilot mode with an abort reason shows WP
GPS LOST, WP STALLED, WP FLYAWAY, WP HEADING or WP MAG FAULT, critical and blinking. Next the line
reads the waypoint capture message and shows it at the info level until it expires. In the autopilot
mode the landing then shows WP LANDING, and the completed plan WP COMPLETE blinking, both at the
info level.

A read of the capture message clears an expired message, which changes the capture's state. The line
reads a copy and reports the read, and the target then reads the message itself, as it clears the
visual beeper the line reports shown. The capture's step clears an expired message too, so a message
the line has not read cannot count as unexpired again 2 ** 31 µs past its expiry. The reference
clears it only at a read, where such a message shows for up to another 35.8 minutes (finding F207,
amended 2026-10-26 as declared in D6). The draw cycle does not yet pass the reports on.

The warnings oracles now compile the reference with the flight plan and the rescue plan, include the
capture module as source, and script the executor's abort reason and state, the rescue descent and
the capture message per step, with three precedence levels for the new cues. The harness replays
12000 line renders and 3000 element renders: every text byte, blink, severity and report matches the
reference's, and so does the capture message's validity after the target's read.

## D233. OSD warnings reports through the draw cycle (2026-10-15)

`Adaflight.OSD_Draw` passes the warnings line's reports on with the call's display operations, and
`Adaflight.OSD_Task` merges them into its call's operations. The target then clears the visual
beeper the line showed and reads the waypoint capture message when the line read it (D232). Before
this change the draw cycle dropped the reports, which left the target no signal to clear the visual
beeper.

The draw oracle now enables the visual beeper warning, turns the beeper on at random before a draw,
and records per call the capture message reads and whether the line cleared the beeper. The harness
replays the 3612 calls of the six sequences: every return, flag, blink bit, craft name byte, report
and display operation matches the reference's, with 25 draws that render the warnings line, 19 of
them clearing the beeper. The task oracle does not draw the warnings element, so the task's merge
rests on the draw vectors' reports and its proof.

## D234. Menu hook effects (2026-10-15)

`Adaflight.Menu_Nav`'s enter hooks and line functions answer with what they did inside the call: a
change to a menu, or for a function an exit by a kind, as the reference's content menus call the
change and the exit themselves before they return. The main menu's enter hook opens the setup popup,
function lines open the save menu, the VTX device's menu and the accelerometer calibration menu, and
the battery restore exits. The navigation runs a change made in an enter hook inside the change that
asked the hook, then the rest of that change on the current menu. It runs a function's change or
exit after the call, then the way back when the function asks for it and the menu is still open. A
function that exits and asks for the way back would make the reference read the closed menu, and no
reference function does, so the port leaves that way back out. No recorded vector reaches the guard.

An exit line now calls its function too. The target answers the exit by the line's kind, or with the
change or exit its own function made, as the SmartAudio and Tramp commit lines do. A change nested
in enter hooks past 21 levels is left out, since the menu stack's limit ends any nesting before
that. After a lookup table line's function changed the menu, the reboot check compares the edited
line's variable, not the new menu's line. `Adaflight.Menu` contains the exit kinds and the answer.

The menu oracle's hooks now change the menu and exit at random inside themselves, and some exit
lines get a function of the menu's own. The harness replays the six sequences' 179171 lines, with
408 changes in enter hooks and 154 changes and 114 exits in functions: every display operation, hook
call, context, stack frame, display state and page matches the reference's.

## D235. Menu line refresh (2026-10-15)

The reference reads a line's variable each time it draws the line's value or handles a key on it, so
a value a hook or a function changed shows at the next draw. `Adaflight.Menu_Draw` and
`Adaflight.Menu_Nav` gain the target's refresh of the current menu's lines: the draw refreshes them
after the display update hook and before it writes the lines, and the key handler before it reads
the line under the cursor. A refresh updates the lines' texts, values and value texts, and the proof
keeps the line count and the fixed-point values' range through it. Lines loaded before an enter hook
show the values the hook set from the next draw on.

The menu oracle's enter and display update hooks now give a random line's variable a new value
within its type, and the harness's value store takes it from the hook log. The harness replays the
six sequences' 179025 lines with 2900 such changes: every display operation, hook call, line value
and page matches the reference's. Without the refresh, drawn values and edits differ.

## D236. Menu target state (2026-10-15)

`Adaflight.Menu_Nav` and `Adaflight.Menu_Draw` gain a formal type for the target's state, passed in
out through every operation that reaches a hook: open, change, way back, draw, keys, exit and
update. The loading, the hooks, the value store, the refresh and the lookup take it, so the menus
can read and write the configuration, the readings and their own temporary values in the target's
state. The reference's menus keep these in their files' statics and the parameter groups. The core
keeps no package state, so the menus' state stays with the target. The hook sets and the target's
actions take no state. The proof shapes count the hook calls in the state, and the harness passes an
empty state over its value store. Every recorded menu line replays as before.

## D237. Menu contents: quick, main, features, setup and save menus (2026-10-15)

`Adaflight.Menu_Content` contains the reference's menus over the target's state of D236: the
configuration, the readings the setup popup shows, the quick menu's copies of the profiles it edits,
the setup popup's lines and the requests to the runtime. Every menu has a number, and the menus of
later slices have one empty line until they come. The menu system opens on the quick menu when the
OSD's setting asks for it, as by default, else on the main menu.

The quick menu copies the current rate profile, the active battery profile and the current PID
profile's motor output limit on entry, edits the throttle limit type and percentage, the motor
output limit and the forced cell count, and writes them back on the way back or a save, with a
request for the PID controller's setup. Its main menu line opens the main menu without stacking the
quick menu. The main menu's entry builds the setup popup: a line for the accelerometer calibration
when arming waits for it, one for the battery restore when charge was drawn, and the exit, and opens
it when a line came in besides the exit. The popup's display update sets the calibration status and
the restore text, and the restore asks the runtime to set the charge drawn back to the stored value,
clears the stored value and exits. The main menu's save line opens the save menu by the reboot flag.
The restore label is cut to the reference's 18-byte buffer, which a stored charge of 100000 mAh or
more overruns there (finding F208). `Adaflight.Menu_Content_Shape` instantiates the navigation over
the menus for the proof.

The menu contents oracle (`settings/cms_oracle.c`) links the reference's menu system and all its
menus over the settings oracle's configuration, scripts the popup's readings, the reboot flag and
the quick menu's profiles, and presses random keys with a draw after each, replacing a right key
that would enter a menu of a later slice with a down key. The harness replays 240 sessions with
11960 keys and 11960 draws: every display operation, menu context, page, request and configuration
hash matches the reference's, over 51 battery restores and 739 quick menu write backs.

## D238. Power, failsafe and RPM limit menus (2026-10-15)

`Adaflight.Menu_Content` gains three menus that copy their settings on entry and write them back on
the way back or a save. The power menu edits the voltage and current meter sources, which ask for a
reboot when changed, the active battery profile's minimum, maximum and warning cell voltages, the
voltage meter's scale, and the current meter's and the virtual current meter's scales and offsets.
The failsafe menu edits the procedure, the guard time as tenths of a second, the landing time and
the stage 2 throttle, each asking for a reboot when changed. This build has no GPS rescue line in
it. The RPM limit menu, reached from the quick menu, switches the limit, edits its value in steps of
100 and the motors' KV, and has its own save and reboot line. The menus' copies stay in the target's
state between openings.

The menu contents oracle now draws these menus' settings at random, within and past their ranges,
and walks deeper with fewer escape and save keys. The harness replays 240 sessions with 19513 keys
and 19513 draws, 962 of their states in the power menu, 320 in the failsafe menu and 3772 in the RPM
limit menu: every display operation, menu context, page, request and configuration hash matches the
reference's.

## D239. Misc, RC preview and persistent statistics menus (2026-10-15)

A hook's answer in `Adaflight.Menu` gains the display operations the hook made, up to six clears
that wait, texts and redraws, and the save menu's inhibition. The navigation performs them after the
hook returns and before the menu change or exit the hook made, in the order the hook made them. The
proof shape's hooks answer with operations of every kind.

`Adaflight.Menu_Content` gains the misc menu, which copies the motor idle offset in tens, cut to a
byte, the camera angle and the crash flip rate, with lines into the RC preview and into the GPS lap
timer of a later slice. The RC preview inhibits the save menu on entry, rounds the eight channels to
whole numbers with ties to even at each display update, shows them as values the keys leave alone,
and lets the way back through only from its back line. Its lines list the throttle before the yaw,
while the channels come yaw first. The persistent statistics menu copies the flight, time and
distance totals and the minimum armed time, and its reset line zeroes the totals and clears and
redraws the display.

The menu contents oracle draws the new settings, and eight channel readings with quarter fractions
at every draw. The harness replays 240 sessions with 19788 keys and 19788 draws, 1722 of their
states in the misc menu, 1076 in the RC preview and 274 in the persistent statistics menu: every
display operation, menu context, page, request and configuration hash matches the reference's.

## D240. Firmware and calibration menus (2026-10-15)

`Adaflight.Menu_Content` gains the firmware menu, the calibration menu and the accelerometer
calibration menu. The target gains the firmware's identity, which the build sets, and the readings
these menus show: gyro and barometer presence with their calibrations, and the board's manufacturer
and name from the board information. The firmware menu shows the identifier, version, source
revision and target, copies the manufacturer cut to four characters and the board name cut to twenty
on entry, and leads into the calibration menu.

At each display update the calibration menu sets a status per sensor: dashes for a missing sensor,
WAIT while its calibration runs, OK once done, and NOK for an accelerometer without a stored
calibration. Its gyro and barometer lines request a calibration when the sensor is present. Its
accelerometer line, like the setup popup's, opens the accelerometer calibration menu when an
accelerometer is present. That menu's start line requests the calibration when the accelerometer is
present and goes back in every case.

The menu contents oracle builds the reference's firmware menu with a neutral identifier and version,
scripts gyro and barometer readings, gives manufacturer and board names longer than their copies,
and counts calibration requests. The harness replays 240 sessions with 19889 keys and 19889 draws,
702 of their states in the firmware menu, 744 in the calibration menu and 500 in the accelerometer
calibration menu, with 42 gyro, 59 accelerometer and 3 barometer calibration requests: every display
operation, menu context, page, request and configuration hash matches the reference's.

## D241. GPS lap timer menus (2026-10-15)

`Adaflight.Menu_Content` gains the GPS lap timer menu, which the misc menu leads to, and its set
gate menu. The lap timer menu copies the gate radius and the minimum lap time on entry and stores
them on the way out. Entering the set gate menu asks the runtime to start setting the gate, and
leaving it asks the runtime to end, for `Adaflight.GPS_Lap_Timer.Start_Set_Gate` and `End_Set_Gate`.
The set gate menu shows the readings taken and the distance to the gate as dynamic values with a
zero step, which the keys leave unchanged.

The reference's SET POSITION line is a function call line that changes to the set gate menu and
draws the menu structure's first bytes, its hook addresses, as the line's value (F209). adaflight's
line is a submenu line to the same menu, with `>` alone as its value: a deviation from the
reference.

The menu contents oracle builds the reference's lap timer menu with that line typed as a submenu
line, scripts gate readings and distances at every draw, and counts the gate setting requests. It
now also changes now and then to a random menu other than the setup popup, as a submenu line would,
which the harness repeats through `Change`. The harness replays 240 sessions with 19491 keys, 773
menu changes and 20264 draws, 386 of their states in the lap timer menu and 522 in the set gate
menu, with 69 gate setting starts and 44 ends: every display operation, menu context, page, request
and configuration hash matches the reference's.

## D242. LED strip menu (2026-10-15)

`Adaflight.Menu_Content` gains the LED strip menu. The target gains the features active at run time.
On entry the menu copies whether the strip's feature is active, the profile, the race and beacon
colors, the beacon's period, on share and armed-only switch, and the visual beeper with its color.
On the way out an enabled strip sets the feature in both the configured and the active features and
asks the runtime to turn the strip on. A disabled strip asks the runtime to turn it off, then clears
the feature in both. The profile is stored only when it is one of the three, and the other copies
are stored as they are.

The menu contents oracle scripts the strip's feature, configured and active apart now and then, and
the strip's settings, and counts the strip's enables and disables. The harness now starts each
sequence's first session from a fresh target, as the oracle runs each sequence in a new process
whose menu copies start at zero. It replays 240 sessions with 18990 keys, 797 menu changes and 19787
draws, 1002 of their states in the LED strip menu, with 48 enables and 25 disables: every display
operation, menu context, page, request, active feature set and configuration hash matches the
reference's.

## D243. Blackbox menu (2026-10-15)

`Adaflight.Menu_Content` gains the blackbox menu with its erase and mass storage confirmations, for
a build with flash, SD card and mass storage support. The target gains the readings the menu shows:
whether the flight recorder lets its configuration change, the PID loop's frequency as a float, the
SD card's presence, function, file system state, contiguous free bytes and size in blocks, the
flash's support, partition sectors, sector size and write offset, and whether mass storage is ready.

On entry the menu sets the device's status and its used and free space from the configured device,
copies the device, sample rate and debug mode, and sets the frequency's text, truncated to whole
hertz as the reference casts it (F210). The counts print as a signed 32-bit number with their unit,
and each text is cut to the reference's seven characters (F211). The debug mode names come from the
command line's table, which holds the reference's names. On the way out the device is stored only
while the recorder lets its configuration change, with a device other than flash, SD card or serial
port stored as none. The sample rate and debug mode are stored as they are.

The erase confirmation, with flash support, clears the display, writes `ERASING FLASH...`, redraws,
asks the runtime to erase the flash and to beep when done, clears and redraws again, sets the status
again with the flash's offset at zero, and goes back. The reference's erase blocks until the flash
is ready, so its status shows the erased flash. The mass storage confirmation, when the file system
is ready, clears the display, writes its two lines, redraws and asks the runtime to reset into mass
storage with the time zone offset. Otherwise it writes its failure line, redraws and goes back.

The menu contents oracle scripts the readings, the configured device, sample rate, debug mode and
time zone, completes an erase at once, and counts the erases, beeps and resets. The harness sets the
flash's offset to zero after an erase, as the runtime does. It replays 240 sessions with 19366 keys,
808 menu changes and 20174 draws, 1694 of their states in the blackbox menu, 214 in the erase
confirmation and 288 in the mass storage confirmation, with 9 erases and 15 resets: every display
operation, menu context, page, request and configuration hash matches the reference's.

## D244. OSD menus (2026-10-16)

A hook's answer in `Adaflight.Menu` gains a fourth display operation, a background type set, with
the type in the operation's attribute. The navigation hands it to the display as the background
action.

The content's loading splits into one loader per menu group, main, settings, system and OSD, each
with the fixed-point bound as its postcondition. A single loader over every menu took the provers
past their time and memory limits on that bound.

`Adaflight.Menu_Content` gains the OSD menu with its active elements, timers and alarms menus, for a
build with OSD profiles, the extended menus and the MAX7456 display. The OSD menu copies the OSD
profile, the display's inversion and black and white brightness, and the menu background on entry
(F214). Its inversion and brightness lines store all three copies and clear the display after each
change. Its background line stores the background and sets the display's background type. On the way
out it asks the runtime to change the OSD profile to its copy, which it stores when the copy is at
most three.

The active elements menu copies every element's position and profile flags, shows 77 elements as
visibility lines, and on the way out stores the copies and asks the runtime to analyze the active
elements again. The timers menu splits each timer into source, precision and alarm and joins them
again on the way out. Tenths, the third precision, show an empty name where the reference reads past
its two names (F212). The alarms menu copies the RSSI, link quality, RSSI dBm, signal to noise,
capacity, altitude and distance alarms and the battery voltage durations, with the ranges of the
reference's lines, except the RSSI dBm line, which ends at 0 like its setting where the reference's
runs to 20 (F213).

The menu contents oracle scripts the element positions, the alarms, the timers, the background and
the display settings, counts the analyses and profile changes, and keeps timer precisions to the two
named ones. The harness replays 240 sessions with 19242 keys, 813 menu changes and 20055 draws, 692
of their states in the OSD menu, 672 in the active elements menu, 446 in the timers menu and 284 in
the alarms menu, with 68 profile changes and 32 analyses: every display operation, menu context,
page, request and configuration hash matches the reference's.

## D245. VTX selection (2026-10-16)

`Adaflight.Menu_Content` gains the VTX selection behind the quick and features menus' VTX lines, and
the VTX error menu. The target gains the VTX device's presence and its type in the reference's
numbering. The selection changes to the device's menu for an RTC6705, SmartAudio, Tramp or MSP
device, and to the error menu for no device or any other type. The device menus have their numbers
and wait for later slices. On entry the error menu sets its two status lines: VTX NOT RESPONDING and
OR NOT CONFIGURED without a device, UNSUPPORTED VTX TYPE for the unsupported type, and UNKNOWN VTX
TYPE otherwise. Its lines show them after empty labels.

The menu contents oracle scripts the device's presence and type, builds the reference's selection
with its error menu reachable, and replaces a right key on a VTX line with a down key while the
device has a menu adaflight does not have yet. The harness replays 240 sessions with 19324 keys, 801
menu changes and 20125 draws, 340 of their states in the error menu, entered 20 times from the quick
menu and 41 times from the features menu: every display operation, menu context, page, request and
configuration hash matches the reference's.

## D246. Profile, PID and rate menus (2026-10-16)

`Adaflight.Menu_Content` gains the profile menu with its PID and rate menus. The profile menu's
other submenus have their numbers and wait for later slices. On entry the profile menu names every
PID and rate profile by its number from one and its name in upper case in parentheses, and copies
the current PID and rate profiles. Its two profile lines change the profile at once on each step,
and its way out changes both again: a change counts as a request to the runtime, stored when the
profile exists.

The PID menu copies each axis's P, I and D gains and feedforward from the profile the profile menu
last selected, names the current profile in its title, and on the way out stores the copies into the
current profile and asks for the PID controller's setup from it. The read profile and the written
one differ when the selection changed in between, in the reference as well. Its lines have the roll
and pitch and the yaw slider flags. The rate menu copies the whole rate profile, shows its rates,
super rates and expos as tenths, its throttle middle, expo and hover and its throttle limit, and
stores the whole copy back on the way out.

The harness now hands the navigation the slider settings of the current profile and the gyro's
filter slider, which skip the overridden rows and mark them. The menu contents oracle scripts the
profiles' names, gains, rates and slider settings and counts the profile changes. The harness
replays 240 sessions with 19458 keys, 773 menu changes and 20231 draws, 2768 of their states in the
profile menu, 910 in the PID menu and 280 in the rate menu, with 435 PID and 214 rate profile
changes and 1396 slider marks drawn: every display operation, menu context, page, request and
configuration hash matches the reference's.

## D247. Simplified tuning, misc and launch control menus (2026-10-16)

`Adaflight.Menu_Content` gains the profile menu's simplified tuning and misc menus and the misc
menu's launch control menu. Their names for lookup values come from the command line's tables
through one helper, which the debug mode and background names now share.

The simplified tuning menu copies the PID tuning mode, the sliders and the filter switches with
their multipliers from the profile the profile menu selected and from the gyro configuration. On the
way out it compares the copies with the current profile and the gyro configuration, and when any
differs it stores them and applies simplified tuning through
`Adaflight.Simplified_Tuning.Stored.Apply`, which recomputes the gains and filters.

The misc menu shows the profile's text, copies the feedforward, angle and horizon, anti gravity,
throttle boost and linearization, I term relax, motor output limit, cell count, D max, battery sag
and attenuation settings, and the landing disarm threshold. The angle feedforward copy is a byte. On
the way out it stores the copies into the selected profile, then asks for the PID controller's setup
and the motors' output range again. The caller runs the setup after the stores, so it sees the
stored values, where the reference sets up the controller before it stores (F216). Its feedforward
averaging line runs to index 4 past the table's four names, where adaflight shows an empty name
(F215). The launch control menu copies and stores the selected profile's launch control settings.

The menu contents oracle scripts the profiles' settings, links the reference's simplified tuning,
counts the output range requests, and keeps the averaging to its named values. The harness replays
240 sessions with 19477 keys, 792 menu changes and 20269 draws, 606 of their states in the
simplified tuning menu, 454 in the misc menu and 294 in the launch control menu, with 23 tuning
changes applied and 23 output range requests: every display operation, menu context, page, request
and configuration hash matches the reference's.

## D248. Filter and profile copy menus (2026-10-16)

`Adaflight.Menu_Content` gains the profile menu's filter menus and its profile copy menu. The
profile filter menu copies the D term lowpass and notch filters and the yaw lowpass from the profile
the profile menu selected, and stores them into the current profile. The global filter menu copies
and stores the gyro lowpass and notch filters. The dynamic filter menu copies the dynamic notch's
count, Q and range, the gyro's dynamic lowpass range and expo, and the selected profile's D term
dynamic lowpass, and stores the last into the current profile. The profile copy menu starts both
destinations at none, and its copy lines copy the current PID or rate profile over the chosen one
when it is another profile.

The content's proof had grown to 57 minutes. gnatprove analyzes each subprogram separately and in
parallel, but proves a helper without a contract inside every caller, so the helpers now have a data
contract and are proved once. The menus now load in one procedure each and store their copies in one
procedure each, and the stores that change a PID profile or the gyro configuration change a local
copy of the record and store it whole. With the filter menus, the content and its navigation
instance prove in 22 minutes, of which about 9 are the analysis of the project before proof.

The menu contents oracle scripts the filter settings and links the reference's profile copy. The
harness replays 240 sessions with 19378 keys, 789 menu changes and 20167 draws, 306 of their states
in the profile filter menu, 266 in the global filter menu, 204 in the dynamic filter menu and 302 in
the profile copy menu: every display operation, menu context, page, request and configuration hash
matches the reference's.

## D249. MSP device in the VTX control layer (2026-10-16)

`Adaflight.VTX_Settings` contains the transmitter settings that `Adaflight.VTX` and
`Adaflight.VTX_MSP` both read. They moved out of `Adaflight.VTX`, which keeps them as subtypes, so
the control layer can hold the MSP driver without a circular dependency.

`Adaflight.VTX` now drives an MSP device too. The control layer passes the band and channel it sets
to the device, to a SmartAudio device only for a factory band, and a band not from the factory also
as its frequency. The MSP driver takes the power index, pit mode and frequency, its getters answer
the control layer's queries, and the Spektrum power steps give it no index. The frequency getter
answers the frequency the driver was given while no band is set, and the table's frequency of its
band and channel otherwise. The reference's getter answers the table's frequency in both cases, so
in user frequency mode the control layer's frequency step sets the frequency again at every pass and
reports an update pending (finding F218). A task call that runs the device runs the driver's cycle,
and the events return the configuration frame to push with a flag for the MSP menu's status line,
set at every cycle while the transmitter is offline and after each frame sent.

The driver converts each power level to milliwatts as a 16-bit integer, which C leaves undefined
from level 49 (F217). adaflight saturates at 65535, as in D93 and D103.

The control oracle adds four sequences over an MSP device: tables of four and five power levels with
a zero and a repeated value, a table without power levels that never comes ready, and a device
without a port. At random the transmitter answers on its own link or on another. Every recorded
vector replays exactly, 3600 of the 12600 steps over the MSP device.

## D250. MSP VTX menu (2026-10-16)

`Adaflight.Menu_Content` gains the MSP VTX menu with its confirmation. The target now contains the
VTX layer's state with the MSP driver, the running VTX table and the menu's status line, which the
target updates through `Update_MSP_Status` when the VTX layer's events ask: a request to set the
table up while it has no bands or no power levels, else the band's letter and the channel's name or
U F, the frequency in four places and the power, each as dashes while the device does not know it.

On entry the menu reads the band and channel, the pit mode and the power index from the device
through the common layer, which `Adaflight.VTX` now exports, and without a device it goes back. The
pit mode line sets the device's pit mode, the band, channel and power lines step from none to the
first, and the confirmation sends the band, channel and power to the device, stores them with the
frequency of the band and channel, and saves the configuration, a new hook operation, before going
back. The MSP driver reads its frequency back from the one it was given at band 0 (D249). A save
stores band, channel and frequency only while the menu holds a band and a channel, so a save in user
frequency mode keeps the configured frequency. The reference stores band 0, channel 0 and the
table's frequency at band 0, which is 0, and the next configuration frame sends 0 MHz (finding
F219).

The menu contents oracle wraps the reference's VTX common layer, MSP driver and MSP VTX menu. Per
session it scripts a VTX table and the driver's state and registers the MSP driver for the MSP type
or a stand-in that answers nothing for any other type, and it updates the status line at the start
and at each change of the readings. The harness replays 240 sessions with 19636 keys, 792 menu
changes and 20428 draws, 708 of their states in the MSP VTX menu and 114 in its confirmation: every
display operation, menu context, page, request, driver state, menu copy and configuration hash
matches the reference's.

Amended 2026-10-25: the band, channel and power names of the four VTX menus are blank above the
table's counts, as declared in D6 (finding F287). The reference draws the name at the line's value.
The SmartAudio driver's band is the device's channel divided by the table's channel count, so a
channel outside the table gives a band above the eight slots, which reads past the name array, and
the other device menus copy that band through the common layer when opened with the SmartAudio
device. The menu contents oracle compiles the reference menu system with the bound, which changes 14
draws in 240 sessions.

## D251. Tramp VTX menu (2026-10-16)

`Adaflight.Menu_Content` gains the Tramp VTX menu with its confirmation, over helpers the MSP VTX
menu now shares: the first seven lines, the copies read from the device on entry, the steps of the
pit mode, band, channel and power lines, and the save. The Tramp menu adds the transmitter's
temperature, and its confirmation sends and stores the settings, saves, and leaves the menu system.
Its status line shows the actual power, marked when it differs from the configured level's value,
and the target updates it with `Update_Tramp_Status` after every Tramp cycle, which the VTX layer's
events now flag as they flag the MSP driver's. The Tramp driver reports no band or channel, so the
menu reads them only through the common layer's selection. A save stores band, channel and frequency
only while the menu holds both, as the MSP menu does. The reference stores zeros here too in user
frequency mode, which the Tramp driver refuses as a frequency, so the stored frequency is lost while
the transmitter keeps its own (F219).

The menu contents oracle wraps the reference's Tramp driver and menu beside the MSP ones and scripts
the Tramp driver's state per session. The harness replays 240 sessions with 19368 keys, 803 menu
changes and 20171 draws, 648 of their states in the Tramp VTX menu and 96 in its confirmation: every
display operation, menu context, page, request, driver state, menu copy and configuration hash
matches the reference's. The VTX control vectors replay exactly with the status flag over both
devices.

## D252. GPS rescue menus (2026-10-16)

`Adaflight.Menu_Content` gains the GPS rescue menu and its PID menu, reached from a GPS RESCUE line
of the failsafe menu. The rescue menu copies the start distance, the altitude mode, the climb, the
return and descent settings, the throttle limits, the satellites required and the arming without a
fix from the GPS rescue and autopilot groups on entry, and stores them on leaving. The PID menu does
the same for the altitude, yaw and position gains and the position smoothing. Every value line asks
for a reboot.

The reference's build headers leave both menus out of a target that derives the rescue from GPS
(F220), the menu oracle's own build included. The oracle now builds the menus as a build that
defines the rescue in its options does, so the failsafe menu's vectors gain the GPS RESCUE line. The
wing variant waits for a wing build of the oracle. The harness replays 240 sessions with 19399 keys,
842 menu changes and 20241 draws, 274 of their states in the rescue menu and 204 in its PID menu:
every display operation, menu context, page, request and configuration hash matches the reference's.

## D253. SmartAudio menu state in the VTX layer (2026-10-16)

`Adaflight.SmartAudio` now receives the line one byte at a time through `Receive_Byte`, which
reports each response it takes in and whether the response changed the device's report against the
report before it, and sends through `Process_Line`. `Process` runs both as before. `Adaflight.VTX`
keeps the SmartAudio menu's state and updates it after each response: a changed report starts the
menu's operating model over, a menu without a model takes it from the device's boot pit mode, with
the frequency selection, band, channel, frequency and power from the device and the settings, and
once the device's version is known the menu takes the version, the first pit and user frequencies,
the pit mode's kind and the status line. Two responses in one task call update the menu twice, each
after its own response. The status line contains all 31 bytes with their nulls, since its updates
write some places and leave others. `Adaflight.Number_Text` now contains the decimal text that both
the menus and the status line print.

The VTX control oracle links the reference's SmartAudio menu code in place of its stubs and records
the menu's state at every step: every recorded vector replays exactly, the SmartAudio vectors
unchanged.

## D254. SmartAudio VTX menus (2026-10-16)

`Adaflight.Menu_Content` gains the SmartAudio VTX menu with its configuration, statistics, pit and
user frequency and confirmation menus, over the SmartAudio menu state the VTX layer keeps (D253). On
entry the menu chooses its lines from that state: offline lines while the device's version is
unknown, else lines by band and channel or by frequency. The configuration menu's frequency
selection chooses them again. The menu navigation now loads a menu's lines after its entry hook,
since this entry hook decides which lines the menu has. The band, channel, power and pit mode lines
step from none and keep their values until the save, the configuration lines send the pit mode
ranges to the device, the pit and user frequency menus copy and store their frequencies, and the
confirmation stores the settings, saving the configuration only when they changed, and leaves the
menu system. The pit mode kind line reaches out-of-range pit mode, POR, at its third value and sends
it to the device. The reference's line stops at the second value, so POR is never shown or sent
(finding F221). The frequency submenus show their frequencies as option strings in four characters
(F183, D194).

The menu contents oracle wraps the reference's SmartAudio driver and menu beside the other VTX
devices, scripts the device's report, statistics and line rate and the VTX settings per session, and
hands the menu a response of the device at the start and at changes of the readings. The harness
replays 240 sessions with 19174 keys, 834 menu changes and 20008 draws, 336 of their states in the
SmartAudio menu, 182 in its configuration, 432 in its statistics, 180 and 220 in the pit and user
frequency menus and 58 in the confirmation: every display operation, menu context, page, request,
driver state, queued frame, menu state and configuration hash matches the reference's.

## D255. Command line information commands (2026-10-16)

`Adaflight.Command_Line` gains vtx_info and rc_smoothing_info. vtx_info lists each power level the
video transmitter reports, in dBm with its power in mW, or prints the error for no transmitter or no
levels. rc_smoothing_info prints the receiver's frame rate rounded to the nearest whole Hz with ties
to even, or no signal, then whether RC smoothing is on in the configuration, and when it is, the
setpoint and throttle cutoffs with whether a setting fixed each. Both report from outside the
configuration, so the environment gains the transmitter's presence and power levels and the running
smoothing's rate and cutoffs. The cutoffs come from the running smoothing, not from settings a set
command changed since its start.

The command line oracle scripts the transmitter's power levels and the receiver's rate and running
cutoffs, and switches RC smoothing between the commands. Two runs of 600 lines, rates from 15 to
1250 Hz with halves, replay exactly.

## D256. Motor and play_sound commands (2026-10-16)

`Adaflight.Command_Line` gains motor and play_sound. motor reads its words between spaces as the C
library's atoi reads them. The first names the output and prints it, or every output at 255, or
prints the error for an output past the motors. With exactly two words and a value from 1000 to 2000
it sets that motor's disarmed value, or every motor's, to the value converted for the motor protocol
and truncated to a whole number, and prints it. The conversion is the MSP motor test's (D221), now
in the spec of `Adaflight.MSP_Motor_In`. play_sound plays the beeper table's entry at the given
index, or without one the entry after the one played last, the first after the last entry, and
prints its name. An index without an entry prints that line. Every entry of the table has a name, so
the search for a named entry stops at the first index it tries. The command line keeps the index
played last in its output record and hands the motor values and the sound to its caller as effects,
with the beeper silenced before the sound.

The command line oracle prints the disarmed motor values and the beeper requests at read-out lines,
and the harness keeps both from the effects. Two runs of 600 lines, with motor devices, motor counts
and the 3D feature switched between them, replay exactly.

## D257. sensor_hardware command (2026-10-16)

`Adaflight.Command_Line` gains sensor_hardware. Without an argument it lists the seven sensor types,
each with the hardware it can be, skipping hardware the build lacks. With a type's name, in any
case, it lists that type's hardware and prints a lacking entry as an empty name between commas
(F222). Any other argument prints the error. The gyro's names are a table of their own, since no
setting takes them. The other types' names are their hardware settings' values.

The command line oracle runs the command with every type in several cases and with other arguments.
Two runs of 200 lines replay exactly.

## D258. MSP command line setting message (2026-10-16)

`Adaflight.MSP_CLI_Setting` answers the MSP2 command line setting message. A request is text up to
its first zero byte. Without an equals sign it names a setting, without regard to case, and the
reply is the setting's name, " = " and its value as the command line prints it. No such setting, or
a lookup or port value without a name, is an error. With an equals sign the request writes the value
through the reference's setting writer, which is stricter than the set command:

- a number is whole with nothing after it, read as the C library's strto functions read it with
  white space and a sign before it, and an unsigned one must not start with a minus
- lookup and bit values match a name without regard to case
- an array takes exactly its elements between commas, each within its element type
- a write-once text takes only its stored value

A value that does not parse is an error that writes nothing. One that parses is written and echoed
as a read is, and a write whose echo has no text still acknowledges. The echo reads the profiles the
configuration selects after the write, and adaflight skips it should a write leave them outside the
profiles, which no setting does.

The value text repeats the command line's rather than sharing it, since the command line prints
through its generic output. Both replay against the reference. The reply is bounded at 256
characters, past the longest setting's 225. An unsigned array element read after white space and a
minus is rejected as the 64-bit host's strtoul rejects it. No setting has an array of 32-bit
unsigned elements, the one type where a 32-bit target would differ.

The settings oracle routes the message through the reference's MSP handler with its reply buffer of
4112 bytes and prints the whole reply. Two runs of 600 requests, with names in several cases and
with stray characters, values of every mode, white space around the value and zero bytes inside the
text, replay exactly, with the configuration hash after each.

## D259. MSP command line setting information message (2026-10-16)

`Adaflight.MSP_CLI_Setting` gains the MSP2 setting information message. A request names a setting up
to a zero byte, with a 16-bit offset in the two bytes after it when they are there. The reply is the
length of the setting's description, then the description from the offset: the parameter group, the
type with its range for a number, its names for a lookup or a port, its length for an array or its
lengths for a text, each on a line, then the default without a line end, at most 255 characters of
it. An empty request or one past 128 bytes is an error without a reply. A request naming no setting
is an error whose reply is a zero length, since the length goes out before the name lookup and the
serial port sends the reply with an error too. The longest description, the debug mode's, is 1440
bytes, so the window is the description from the offset. The reply holds 2048 bytes.

The default comes from the stored defaults at the profile the configuration selects. For the OSD stats
bitmask the reference reads zero instead (F223), a declared deviation (D6).

The settings oracle routes the message through the reference's MSP handler. Two runs of 600 requests, with
names in several cases, offsets from zero past the end, short and long tails after the zero byte and names
past 128 bytes, replay exactly but for the stats bitmask's default.


## D260. Receiver bind (2026-10-16)

`Adaflight.RX_Bind` decides the receiver bind. The CRSF and SRXL2 serial receivers take one, as do
the SPI receivers of the FrSky D and X, Redpine, S-FHSS, FlySky, Spektrum and ExpressLRS protocols.
No other receiver does. The receiver and its serial protocol are the board's from its start and the
SPI protocol is the configuration's at the request. The command line's bind_rx starts the bind with
"Binding..." or prints the error for a receiver without one, and the MSP bind message starts it or
answers an error. Both hand the bind to their caller as an effect. The board information's bind
capability is the same decision.

The command line oracle links the reference's bind module with its three bind calls counted, scripts the
receiver the board took at its start and switches the SPI protocol between the requests. Two runs of 600
lines replay exactly.

## D261. RTC6705 video transmitter (2026-10-16)

`Adaflight.VTX_RTC6705` drives the RTC6705 over soft SPI. A frequency from 5600 to 5950 MHz writes
400 to the reference divider register, then the frequency's divider register: its steps of 40 kHz,
the multiple of 64 shifted above the remainder. A power index with a table value writes the power
amplifier register, cut to the value's low 8 bits, held from one to two, full power at two. Pit mode
switches the power pin off. Leaving it switches the pin on, waits the 350 ms boot delay and writes
the stored power and frequency. The writes, the pin and the waits leave as operations in their order
for the board to carry out over its pins. The reference bit-bangs each write with a millisecond per
clock edge, which the board's driver need not copy.

`Adaflight.VTX` gains the RTC6705 as a device kind: bands and channels reach it only as frequencies, its
readings are its own, and the Spektrum power steps map to its two levels. The pit mode setter takes the
table, which the RTC6705 reads on leaving pit mode. A task call hands the operations out with its events,
and a caller that sets the device outside one takes them after. The start leaves the transmitter
unpowered, and the device's process powers it on with the boot delay and the stored power and frequency
once the pit mode is off and it has not been powered since the start. The reference powers it on only
when a pit mode cycle ends, so a board with a power pin never transmits until the pilot cycles pit mode
(finding F224, D6).

The VTX control oracle adds two RTC6705 sequences: the reference's soft SPI driver and device layer as
source over stand-in pins, with the register writes decoded from the chip select, clock and data edges and
the power pin and the waits outside a write recorded. Every step's frequency, power index, pit mode and
operations replay exactly, and the fourteen earlier sequences stay byte for byte.

## D262. RTC6705 VTX menu (2026-10-16)

The RTC6705 menu has a label line, band, channel, power and pit mode lines over the VTX table, and a
back line. Entering it reads the device's band and channel, power index and status into the menu's
copies, which start at zero and keep their values between visits. A line that shows none steps to
the first when changed. The exit sets the device's pit mode from the pit line, stores the band,
channel and power with the band and channel's frequency, and saves. The menu's leave hook gains a
save output for this, and the navigation saves after the hook returns.

The common pit mode setter now takes the reference's byte. The MSP and Tramp devices store it as given,
and the SmartAudio and RTC6705 devices test it for zero. The other callers pass 0 or 1. The reference
menu passes the pit line's value, so its exit turns pit mode on whatever the line shows (F225), and the
exit can store band 0, channel 0 and frequency 0 (F226).

The menu oracle adds the RTC6705 from the D261 source over stand-in pins. It opens the menu in RTC6705
sessions and, through direct jumps, with the other devices, and records the RTC6705's frequency, power
index, pit mode and operations after every step. Six runs with 240 sessions in all replay exactly, with 37
jumps to the menu and 12 RTC6705 sessions.

Amended 2026-10-24: the exit turns pit mode on only for the ON line, and stores the band, channel and
frequency only while both band and channel are set, as declared in D6. The power is stored either way. The
menu contents oracle now compiles the reference menu with the same two changes, which alter 2003 lines in
16 of the 240 sessions. Those sessions replay exactly with the fix, and reverting either half of it fails
them.

## D263. DShot telemetry information command (2026-10-16)

`Adaflight.Command_Line` gains dshot_telemetry_info. It prints the driver's read and invalid reply counts and
its direction change time in cycles and microseconds, then a line per motor of the mixer, then the decoder's
last 22 edge times and the steps between them. A motor's line has its reply kinds, eRPM, RPM and Hz, the
invalid share over the last second or NO DATA without an eRPM reply, and its temperature, voltage, current,
state events and debug values. The RPM is rounded with ties to even and cut to its low 16 bits. The cycles
are the 32-bit difference of two cycle counter readings, and the microseconds their unsigned quotient by the
clock's cycles per microsecond, the STM32 conversion. The environment gains the motors' DShot telemetry with
their reply quality, the driver's counts, the cycle counter readings, the clock rate and the edge times.

The command line oracle defines what the reference's driver and system code leave out of the build: the
telemetry flag, the cycle counter readings, the STM32 conversion and each motor's RPM, and scripts them with
the driver's counts, the motors' replies and reply counts, and the edge times. Two runs of 600 lines replay
exactly.

## D264. Scheduler debug values (2026-10-16)

`Adaflight.Scheduler` gains the eight debug values of its four debug modes, kept in its state and set only
in the running mode, which the settings name with the debug task. The scheduler mode reports the pass's time
less its tasks' run times. The determinism mode reports the gyro cycle time, the latest late task with its
lateness, the gyro skew and the range of gyro periods over each lock, and the gyro cycle deviation over each
timing window. The timing accuracy mode reports the load, and over each window the late tasks, their
lateness, the tasks run, the late share and the cycle deviation. The task mode reports the debug task's
number, rate, peak, average, anticipated and latest run times, the anticipated less the latest, and its late
runs. Each value keeps its low 16 bits. The cycle conversions wrap their products at 32 bits and truncate
their signed quotients, and the deviation squares wrap at 32 bits (F227). Task numbers count adaflight's
full task table, as the tasks command does. The gyro status gains whether its driver syncs to a short
period, and the settings bridge takes the debug task from the stored scheduler group and the running debug
mode from its caller.

The scheduler oracle runs each of its eight sequences in the four modes, with a debug task among the core
tasks, a short gyro period on odd sequences, 1250 passes and an idle gap of up to 40M cycles before one pass
in fifty so that timing windows close. Every pass's values replay exactly. The harness compares the task
numbers through the oracle build's task list, which leaves out some of the full table.

## D265. Autopilot modes in the rate loop (2026-10-16)

`Adaflight.PID_Controller` takes the GPS rescue, altitude hold and position hold modes with the autopilot's
roll and pitch angles, its largest angle, and whether it holds the position itself. GPS rescue levels the
craft as angle mode does. The three modes are requests from outside the sticks: level race mode then levels
both axes, and the start of a request restarts the second of level mode before crash detection. In GPS
rescue the angle target is the autopilot's, held to its largest angle, without the angle feedforward. In
position hold the feedforward drops, the target is the autopilot's while it holds the position, held to 85
degrees, and the limit never passes its largest angle. GPS rescue and altitude hold take the full earth
reference on roll and pitch, GPS rescue also on yaw, and GPS rescue runs the crash detection whatever the
crash recovery setting.

The PID oracle now builds with the F405 build's GPS rescue, altitude hold and position hold, and the
existing PID vectors stay byte for byte. New runs switch the three modes over acro, angle and horizon every
sixty loops, with the autopilot's angles, largest angle and position control scripted, the craft armed
through the crash phases, and the clock stepping 10 ms a loop so that the second of level mode can pass.
They replay exactly.

## D266. Mixer flight modes (2026-10-16)

`Adaflight.Mixer` takes launch control, GPS rescue, altitude hold and position hold with the autopilot's
throttle. Launch control counts as airmode, mixes through the launch table in pitch-only launches, and holds
the throttle at zero. The configuration builds the launch table with every motor that pitches the nose up
held at zero. Altitude hold and then GPS rescue replace the throttle with the autopilot's when it has one,
after the throttle limit, the boost and the thrust compensation. GPS rescue, altitude hold and position hold
keep motor stop off.

The PID oracle's new mixer runs script launch control, the three modes, the autopilot's throttle, the motor
stop feature and a minimum check for each run, which the oracle's zero-filled receiver group otherwise
leaves at 0, so that motor stop occurs. They replay exactly, and the existing mixer vectors stay byte for
byte.

## D267. Yaw spin recovery (2026-10-16)

`Adaflight.PID_Controller` and `Adaflight.Mixer` take the gyro's yaw spin detection. The controller drops
the yaw setpoint to zero before the error rate, clears every I term, and holds the roll and pitch P, D and F
terms at zero after the F term. The mixer lifts the yaw sum limit to 1000 and, without airmode or launch
control, sets the throttle to half ahead of the launch control and autopilot throttles.

The PID oracle builds with the F405 build's yaw spin recovery, and the existing vectors stay byte for byte.
New mixer runs switch the detection every eight loops, with launch control in one window in four. They
replay exactly.

## D268. Landing disarm (2026-10-16)

`Adaflight.PID_Controller` requests the landing disarm when the landing threshold is set. Once the throttle
has risen, with the sticks centred and the RC throttle under 5 percent, or below the landing altitude while
altitude hold or GPS rescue owns the throttle, a jerk past ten times the threshold requests the disarm, and
below that altitude under the autopilot the jerk counts half again. The caller carries out the request as
the arm switch disable and the disarm with the landing reason. The check runs after the I term rotation.

The PID oracle's new runs script the throttle-raised flag, altitude hold or GPS rescue, the landing altitude,
the stick deflection, the RC throttle and the jerk, with a threshold in seven sequences of eight, and read
back the disarm and the arm switch disable after each step. They replay exactly. The oracle's disarm stub
now counts landing disarms apart from crash disarms, and the earlier vectors stay byte for byte.

## D269. RPM limiter (2026-10-16)

`Adaflight.Mixer` gains the RPM limiter. With the limit on, DShot telemetry running and the craft armed, it
runs after the thrust compensation: a PID on the averaged RPM over the limit, whose positive output comes off
the throttle, and a throttle scale that falls while the RPM is over the limit below the maximum check, and
rises while the output is below -400 times the loop period at the maximum check with no motor at the
maximum throttle. A filtered offset follows the limit over the motors' estimated top RPM from the KV and the
battery voltage. With the limit on, the throttle limit stays off. The mixer's profile sets the gains from
the settings and the loop time, and arming resets the I term and the scale. The I term is held under 1e30,
which no flight reaches, so that the prover can bound it.

The PID oracle builds with the F405 build's RPM limiter, and the existing vectors stay byte for
byte. New mixer runs switch the limit on in seven runs of eight and script its settings, the KV, the
maximum throttle and the maximum check, which the oracle's zero-filled motor and receiver groups
otherwise leave at 0. They reset the limiter as at arming and feed the averaged RPM and the battery
voltage every loop. They replay exactly.

## D270. Crash flip mixing (2026-10-16)

`Adaflight.Mixer` gains the crash flip. While the mode is on, the mixer takes the throttle as before,
then drives the motors itself and leaves out the throttle-side updates and the mix. The direction comes
from the stick deflections the controller reads, smoothed with RC smoothing on, and the strength from
the magnitudes of the raw deflections. The yaw stick leads when its deflection exceeds both roll and
pitch. Otherwise the roll and pitch vector leads, and more than 30 degrees off the diagonal it keeps
only its larger axis. A strength at or below 0.15 gives no drive. With a crash flip rate set, the drive
falls off past half the rate limit in roll or pitch rate and, with the accelerometer, as the cosine of
the tilt moves more than 0.5 from its value where the flip started. Each motor takes its share from its
mix weights, the motors on the far side at the set percentage of their reversed share, and a drive under
2 percent gives the disarm output. The reference's flip success flag is written and read nowhere, and is
not kept.

The cosine of the stick's angle from the diagonal is taken above a length of 1e-30, where the reference
takes it above zero, so that the prover can bound the quotient. A roll and pitch length is zero or above
the root of the smallest float, about 3.7e-23, and a leading yaw stick has already cleared the signs this
cosine can clear, so the two agree. The motor output is the low end plus the drive's share of the range
without a clamp, as in the reference, which can land one rounding above the high end. The mixer's
postcondition bounds the motors by the high end outside the flip and by the motor value range during
it.

The PID oracle's mixer runs script the flip in twenty-loop blocks, the crash flip rate and motor
percentage, the accelerometer flag around the mixer, the tilt, and the raw and smoothed deflections, with
anti-gravity off (D6). The existing vectors stay byte for byte, and the new runs replay exactly.

## D271. DShot failsafe floor (2026-10-16)

`Adaflight.Mixer` gains the DShot floor of the failsafe mixing. With a DShot protocol, a motor output below
the low end of the range during failsafe is the disarm output, before the clamp to the disarm output and
the high end, so that no value reaches the protocol's command range. The low end with DShot is the idle, so
an output between the command range and the idle stops the motor as well. The mixer configuration takes
the protocol from the stored motor configuration.

The PID oracle now builds with DShot, as the F405 build does, and the existing vectors stay byte for byte.
New mixer runs script the failsafe in ten-loop blocks and the protocol, each protocol with DShot and PWM
endpoints, and the DShot low end at an idle of 3 to 10 percent. They are the first runs to check the
failsafe mixing, and they replay exactly.

## D272. Battery sag filter (2026-10-16)

`Adaflight.Battery` gains the voltage meter's sag filter. The sag compensation is on when a stored PID
profile asks for it with the RPM limit off. Then the voltage task runs at 200 Hz, the display filter takes
that rate, and the analog sample also goes through a sag filter of its own period, by default 0.2 s, to a
sag-filtered voltage. The sag cell voltage divides it by the cell count, or is 0 before the count is known.
The ESC sensor's voltage leaves it as it was, and the meter without a source resets it to zero.

The battery oracle builds with the F405 build's sag compensation and RPM limit, and the existing vectors
stay byte for byte. New runs script every profile's sag compensation, the RPM limit and the sag filter's
period. They check the flag, the sag-filtered voltage and its cell voltage at every step, and replay
exactly.

## D273. Mixer sag compensation (2026-10-16)

`Adaflight.Mixer` gains the battery sag compensation. With the PID profile's compensation above zero, the
RPM limit off and a warning cell voltage below 4.20 V, the top of the motor range comes down from the high
end by an attenuation of the output range. The attenuation is the range from 4.20 V down to the warning
voltage over 4.20 V, times how full the sag cell voltage puts the pack within that range, times the
compensation. The crash flip keeps the high end. The failsafe clamp takes the reference's form, which
admits a disarm output above the lowered top. The mixer configuration takes the compensation from the PID
profile and the warning voltage from the battery profile.

The PID oracle builds with the F405 build's sag compensation, and the existing vectors stay byte for byte.
New mixer runs script the compensation, the RPM limit, the warning voltage and a falling sag cell voltage,
with the crash flip in some blocks. They check the factor and the range against the reference's and replay
exactly.

## D274. DShot arming checks (2026-10-16)

`Adaflight.Arming` gains the DShot side of arming. With a DShot protocol the boot grace time holds until the
DShot command stream runs. Arming is disabled while the DShot telemetry setting is on and a motor does not
report, and while the bitbang driver runs without its status OK. An arming within 1.2 s of a DShot beacon
command waits, and the attempt stays pending, as a normal arming or one into launch control, until it arms,
the pilot lets go of the switch or the sticks, or a disabled arming clears it. A pending launch control
arming arms into launch control, and a pending stick arming repeats. At arming with DShot, the DShot
telemetry data clears and the extended telemetry turns on where the telemetry setting is on without the ESC
sensor feature, and the motors' spin direction is set to normal, as at every disarm. Arming resets the RPM
limiter. The settings bridge takes the protocol and the extended telemetry setting from the stored motor
group and the ESC sensor from the features.

The arming oracle builds with the F405 build's DShot, DShot telemetry, bitbang, ESC sensor and RPM limit, and
the existing vectors stay byte for byte: their runs keep the protocol off and no beacon in the guard time.
New DShot sequences run the same scenarios with the protocol in seven of eight, the settings, the command
stream's start, recent beacons, and the telemetry and bitbang states scripted, and the blockers outside the
DShot side clear. The crash flip box gives way to the failsafe box, since the crash flip's arming state is
not yet in. The sequences replay exactly.

## D275. Crash flip arming (2026-10-16)

`Adaflight.Arming` gains the crash flip's arming state. Arming with a DShot protocol starts the crash flip
when its switch is on, which sets the motors' spin direction reversed and keeps launch control off. While it
runs, the runaway takeoff check stays off and every modes pass asks for the crash flip tone. Turning the
switch off while armed returns to normal flight with the spin direction normal when the auto rearm setting is
on. Otherwise it disarms with the crash flip reason and blocks arming until the pilot disarms. A disarm ends
the crash flip, and a disarm during it leaves the was-ever-armed flag as it was. The settings bridge takes
the auto rearm setting from the stored mixer group.

The arming oracle's crash flip sequences run the DShot scenarios with the protocol on, the crash flip box
left in place, a crash flip switch of its own flipped now and then, and the auto rearm setting drawn per
sequence. They replay exactly, and the earlier arming vectors stay byte for byte.

## D276. Flight modes and GPS arming checks (2026-10-16)

`Adaflight.Arming` gains the flight modes the default build selects in the modes pass besides angle and
horizon, and the GPS side of arming. Angle mode also follows altitude and position hold. Armed, GPS rescue
mode follows its switch, or failsafe with the GPS rescue procedure, when the procedure or the box configures
GPS rescue. Altitude hold follows its switch, failsafe or the autopilot mode, armed outside GPS rescue and the
launch mode, with the accelerometer, the platform's altitude control law, a valid altitude estimate and the
throttle raised. Position hold follows the same with its switch and the position control law, without the
altitude estimate.

With GPS rescue configured, arming is disabled without a fix and enough satellites, unless allowed without a
fix, armed before, or with the crash flip switch on, and while the rescue switch is on. Arming with the GPS
feature resets the GPS home, stops the use of the GPS course for the heading, and sounds the GPS fix or no-fix
arming tone, and the gyro calibration stick command resets the home as well. An OSD element that needs the
accelerometer and the GPS rescue failsafe procedure count among the uses of an uncalibrated accelerometer.
Headfree mode turns off for the flying wing and airplane mixers only. It turned off for the custom airplane
too before. The settings bridge takes the GPS rescue, failsafe and feature settings from the stored
configuration, with the multirotor's control laws.

The arming oracle builds with the default build's GPS, GPS rescue, altitude and position hold, and OSD, and
the existing vectors stay byte for byte: their runs model a build without GPS rescue and the control laws.
New GPS sequences script the features, the failsafe procedure, the rescue's arming settings, a hold and a
rescue switch, airplanes with a headfree switch, and the GPS fix, satellites and altitude estimate. They
replay exactly.

## D277. Battery presence hooks (2026-10-16)

`Adaflight.Battery` reports what a pack's connection asks of the other units. The presence check returns the
connection, which resets the RPM limiter, and the detected cell count where the count is detected rather
than forced, which chooses a PID profile first. `Adaflight.Config_Runtime.Profile_For_Cells` makes the
choice. The current profile stays where it names the count or stays with any count. Otherwise the next
profile after it that names the count wins, else the first after it that stays, else the current one.

The battery oracle adds sequences that plug and pull a pack of a fresh cell count every two seconds, with
short display filters, and record the connection's calls. A new oracle includes the reference's
configuration source and runs its profile choice on 2000 random profile sets with the profile change's other
calls stubbed. Both replay exactly, and the earlier battery vectors stay byte for byte.

## D278. Arming statistics events (2026-10-16)

`Adaflight.Arming` reports the statistics calls of arming and disarming. Every arming asks the persistent
statistics to start a flight and the OSD to show its statistics screen at the next disarm. A disarm asks the
persistent statistics to end the flight unless the crash flip was running, and suppresses the OSD statistics
screen while the crash flip switch is on or launch control is active.

The arming oracle builds with the persistent statistics, and the existing vectors stay byte for byte. New stats
sequences run the crash flip scenario on fresh draws with launch control switched in every sequence, and record
the statistics and OSD calls. They replay exactly.

## D279. Modes pass hooks (2026-10-16)

`Adaflight.Arming` gains the rest of the default build's modes pass. Stick commands are left out while the
OSD menu is open. The pass reports whether the in-flight adjustments run, which they do outside the command
line unless the board is paralyzed while disarmed, and whether the attitude task runs fast for a level mode.
With the telemetry feature it releases the shared serial ports to telemetry while armed, or while the
telemetry switch is on where one is configured, and gives them back to MSP when that ends. It asks the VTX to
update its activated channel every pass and to check its control button when the VTX is ready for an update.
The VTX band and channel stick commands join the stick commands while disarmed.

The arming oracle builds with the default build's VTX control, and the existing vectors stay byte for byte.
New hooks sequences script the telemetry feature and switch, the OSD menu, the VTX's readiness and held VTX
stick commands, and record the pass's calls. They replay exactly.

## D280. Wing TPA (2026-10-16)

A wing build's PID controller takes its TPA argument from an airspeed model when the mixer flies a fixed
wing. `PID_Config.Configure` takes the build and airframe as a `Wing_Setup` and derives the model from the
profile. The basic model takes the thrust to weight ratio from the gravity share and the drag from the
delay. The advanced model takes both from the mass, drag and thrust, limits the thrust by the propeller's
pitch speed from the prop pitch, the motor KV and the battery's full voltage, and takes the top speed from
a fall and a powered dive. Each loop the mixer's throttle-side update integrates the airspeed from the
motors' RMS output times the battery's share of its full voltage, less the drag, plus gravity along the
pitch the offset corrects. The TPA argument is the airspeed over the top speed. A multirotor in a wing
build keeps the throttle. `Reset_TPA_Speed` returns the airspeed to rest as the wing launch arms.

A wing build also keeps a yaw TPA factor for the yaw axis's P and D terms: the classic curve's factor with
differential thrust, the TPA factor with a rudder. P takes the TPA in the PDS mode too, and stored codes
past PDS act as D. The S term's factor per axis follows the TPA factor and, on the hyperbolic curve, is
scaled so that it times the S gain stays within one. Outside the level modes each setpoint is scaled by the
S factor over the TPA factor, except yaw with differential thrust. The S term is the unscaled setpoint over
the axis's largest rate times the S gain, times its factor in the PDS mode. The sum takes it, as zero
outside a wing build. The reference's wing builds leave out yaw spin recovery, launch control and runaway
takeoff prevention, so a wing target keeps those inputs off (F230).

The mixer's state contains the motors' RMS output, which the next wing increment computes after the
motors. The vectors script it. The airspeed holds below 10^10 m/s and the scaled setpoint within the rate
bound, and both holds are inert. The TPA low rate reaches -128, as a wing build's settings allow. The PID
oracle's wing build runs 37 sequences over a quad, a flying wing and an airplane with both yaw controls,
both models, the three TPA modes and both curves, and every step replays exactly. Nine tampered paths each
fail the vectors.

## D281. Wing setpoint attenuation (2026-10-16)

A wing build's controller attenuates its terms by the setpoint, the setpoint PID attenuation (SPA). Each
loop it takes each axis's attenuation as one minus the smooth step of the setpoint's magnitude over the
profile's window, from its center and width. Outside the off mode the I term's change takes the attenuation.
After the S term the PID mode scales P, D and I, the I mode scales the I term, and the PD mode with the I
frozen scales P and D. An axis in a level mode skips that scaling and keeps the I change's attenuation.
Stored mode codes past the last act as the I freeze mode.

A wing build adds the profile's pitch offset to the pitch angle target in the level modes and leaves out
position hold's autopilot angle. A fixed wing in passthrough drops every term, as with the controller off.

The PID oracle's wing build runs 37 level mode sequences of 240 loops over a quad, a flying wing and an
airplane with the five attenuation modes, pitch offsets, passthrough and the hold modes, and every step
replays exactly. Six tampered paths each fail the vectors.

## D282. Wing mixer outputs (2026-10-16)

A wing build's mixer computes the motors' RMS output, which the airspeed TPA reads in the next loop (D280).
After it writes the motors, it takes each enabled motor's external value, the DShot conversion or the PWM
value truncated, scales it from the 1000 to 2000 range onto zero to one, and takes the root of the mean square
over every motor. The 3D feature is not ported, so the DShot conversion takes its one-direction range. A
motor stop sets the RMS output to zero, and the crash flip leaves it as it was. In the launch mode a valid
launch throttle blends into the throttle by the handover, and the motors do not stop. The blend is held
within plus and minus one, which it never leaves.

The PID oracle's wing build runs 37 mixer sequences over a quad, a flying wing and an airplane with DShot and
PWM motors, launch throttles and handovers, motor stop and disarmed blocks, and every step replays exactly.
The controller runs with the launch mode off there, as its launch handling is the next increment. Four
tampered paths each fail the vectors.

## D283. Wing launch level mode (2026-10-16)

A wing build's controller flies the wing launch through the level modes. The launch mode turns levelling on
and counts as an autopilot's request, so race mode leaves its pitch levelled and the crash detection's guard
time restarts. Each level axis's target blends from the launch's angle, with the pitch offset on pitch, to the
pilot's by the handover, the angle limit widens to the launch's angle, and the angle feedforward scales by the
handover. The setpoint takes the levelled rate, as in angle mode.

A launch's climb angle with the pitch offset reaches past ninety degrees, so the angle targets widen to 3600
degrees and the autopilot's angles take their own type within the launch's 255. The launch's target and blend
are small functions with contracts, and the level setpoint has a data contract, so each is proved on its own
and the controller's loop proves within its time.

The PID oracle's wing build runs 37 level mode sequences with launch blocks, climb angles and scripted
handovers among the other modes, and every step replays exactly. Seven tampered paths each fail the vectors.

## D284. Wing launch arming (2026-10-16)

A wing build with the launch assist runs the launch's lifecycle through `Adaflight.Arming`, whose state
contains the launch. Arming latches it, with the launch switch on, a fixed wing, an accelerometer and the
airframe at rest, and asks the controller to reset its airspeed. Disarming resets it. The modes pass turns
the launch mode on while armed with the launch latched, its switch on, an accelerometer, no failsafe and the
launch not over. Leaving it switches the launch off, and leaving it with the switch before the throw disarms
for the launch abort and, without stick arming, blocks arming until the switch cycles. The launch mode
levels the craft from the next pass, and the hold modes stay off while it lasts. The I term stays reset until
the launch spins up, and with a fixed wing the launch switch makes an uncalibrated accelerometer block
arming. The launch's flight runs in the PID loop's pass on the state arming contains.

The arming oracle gains a wing build with the reference's launch source, without launch control or runaway
takeoff prevention, as a wing build compiles them out. Its sequences script a launch switch, whether the
airframe is at rest and, now and then, the launch state the pass sets, and the earlier arming vectors stay
byte for byte. Every step replays exactly, and eight tampered paths each fail the vectors.

## D285. In-flight accelerometer calibration arming (2026-10-16)

`Adaflight.Acc_Inflight` contains the in-flight accelerometer calibration's state, which the arming logic and
the accelerometer share: armed, measurement done, save pending, active, and the samples left. With the
in-flight calibration feature, the disarmed stick command with the throttle and yaw low and the pitch and
roll high saves a finished measurement, or else toggles the calibration's arming with its tone or its
failure tone. Each modes pass checks the calibration between the stick commands and the mode update. Armed
for it, flying with the throttle above the minimum check and the arm switch off, the 50-sample measurement
starts. The calibration switch starts it once and keeps it active. Disarmed after a measurement, the save is
set. The arming state contains the calibration, and the accelerometer's measurement and save are the next
increment.

The arming oracle gains in-flight calibration sequences with the feature, a calibration switch and the stick
command held more often, and scripts the accelerometer's end of a measurement and its save. Every step
replays exactly, the earlier arming vectors stay byte for byte, and six tampered paths each fail the vectors.

## D286. In-flight accelerometer calibration measurement (2026-10-16)

With the in-flight calibration feature, `Accelerometer.Update` runs the calibration the arming logic
starts (D285), after the power-on calibration and before the offsets apply. As a measurement starts
it keeps the zero offsets and the angle trims. For 50 samples it adds each aligned sample to a
whole-number total, the float sum truncated at each addition, and holds the output and the offsets
at zero. At the end it restores the kept values, sets the measurement done and the update's end
flag, which sounds the calibration tone. When the arming logic asks for the save, the offsets take
the totals' averages, the vertical one less a g, the angle trims clear, and the update's save flag
asks the target to save the configuration as calibrated. The settings take the feature from the
stored features.

The accelerometer oracle gains in-flight sequences that start measurements, turn the calibration switch on,
ask for saves and set angle trims, and every step replays exactly. A tone check that took the done flag's
rise failed five steps, where a measurement ends while the previous one is still done, so the update reports
the end itself. Six tampered paths each fail the vectors.

## D287. Dynamic idle (2026-10-17)

`Adaflight.Mixer` gains the dynamic idle, which raises the low end of the motor range to keep the slowest
motor above a target frequency. `Init_Dyn_Idle` sets it up as the mixer's profile does: off without DShot
telemetry, the target in revolutions per second from the setting in hundreds of RPM, the P, I and D gains
from the settings and the loop time, the largest increase, the motor idle as the limit before takeoff, a
delay on the motor frequency of about 20 ms, and the motor range's low end at the DShot minimum while it
runs. Each mixer pass, before the motor range, a PID on the slowest motor's frequency below its target sets
the increase: the P term on the error, the I term on the error held above -0.1 and kept between zero and
the limit, the D term on the delayed frequency, and their sum held to the same limit. The limit is the
largest increase once the throttle has risen since arming and the motor idle before. The low end of the
range rises by the increase times the range, and the throttle stays at or above 1 percent while it runs.
The raised end would fall back to the low end if it reached the top, and a share of at most 0.26 keeps it
far below. The delayed frequency is held to the signal bound. Its delay factor passes two only for a loop
slower than 20 Hz, where the reference's delayed frequency diverges, and the PID loop runs far faster.

The PID oracle builds with dynamic idle, and every earlier PID and mixer vector stays byte for byte. New
mixer runs script DShot telemetry, the settings, the motor idle, the slowest motor's frequency and the
throttle's rise, and every step replays exactly. Six tampered paths each fail the vectors.

## D288. Low voltage cutoff and 3D throttle (2026-10-17)

`RC_Command.Update_Commands` takes the battery's low voltage cutoff and the 3D throttle. With the 3D
feature the throttle takes the whole stick from 1000 to 2000 and leaves out the minimum check. With
the cutoff on, the stick's share scales by the cutoff's percentage in whole numbers before the
throttle curve. With the 3D feature and no failsafe, the 3D switch maps the curve's output from the
middle stick up to the top. In the switched 3D mode the switch reverses the motors and maps the
output from the middle down to the bottom, and with the switch off the output maps from the middle
up to the top. The mapping takes the output above 1000 as a twelve-bit share of 1000, times the
span, rounded down. The settings take the 3D feature from the stored features and the switched mode
from the 3D settings. The mixer does not read the reversal yet.

The RC oracle gains throttle sequences that script the 3D feature, its switched mode, the middle stick, the
3D switch, the cutoff with its percentage and failsafe, with the feedforward averaging off (D6). Every step
replays exactly, and the earlier RC vectors stay byte for byte. Seven tampered paths each fail the vectors.

## D289. Headfree attitude (2026-10-17)

`Adaflight.Attitude` gains the headfree frame. `Set_Headfree_Offset` keeps the current heading as a turn
about the vertical when roll and pitch are both within 45 degrees, and reports whether it did.
`Headfree_To_Body` turns an earth frame vector into the headfree frame: it multiplies the offset by the
estimate, keeps the product as the headfree attitude, and rotates the vector by it. In headfree mode the
Euler angles come from the headfree attitude kept by the last turn rather than from the rotation matrix
(F234), and the reported quaternion that MSP and the flight log read is the headfree one.
The headfree attitude's components are held to the estimator's bound of two (D17), which a product of two
unit quaternions does not reach.

The attitude oracle gains headfree sequences that toggle headfree mode, ask for the offset and turn random
vectors before the updates. Every offset, turn, angle and reported quaternion replays exactly, and the
earlier attitude vectors stay byte for byte. Seven tampered paths each fail the vectors.

## D290. Motor stop on the receiver's throttle (2026-10-17)

`Mixer.Inputs` gains the receiver's throttle channel, and the motor stop compares it with the minimum check
where the mixer compared the command throttle. The two differ near the minimum check. Just above it the
throttle curve's output can still sit below it, so the mixer stopped the motors where the reference mixes
them. With a minimum check of 1000, a receiver throttle below 1000 stops the motors while the command
throttle does not. The mixer oracle gains runs where the receiver's throttle moves apart from the command
throttle, one step in ten exactly at the minimum check and a minimum check of 1000 in one run in four. The
mixer failed 64 cases of these runs before the change, and every step replays exactly after it. The earlier
mixer vectors stay byte for byte. Comparing the command throttle again, or comparing at or below the minimum
check, fails the vectors.

## D291. Mixer 3D (2026-10-17)

With the 3D feature, `Adaflight.Mixer.Update` takes the 3D throttle and motor range in place of the dynamic
idle, the sag compensation and the throttle angle correction. A throttle deadband sits around the middle
stick, the 3D throttle setting wide on each side, or half the minimum check's distance above 1000 with the
3D switch on or in switched mode. Past the deadband the throttle is its distance from the edge over the stick
range on that side. Above it the motors run from the high edge of their own 3D deadband to the high end.
Below it they run between the low end and the deadband's low edge with the mix's sign negative, from the
deadband edge down with an analog protocol. Inside the deadband the throttle is zero on the side the stick
last left from, on the reversed side while the RC command reverses the motors, and on the upper side after a
disarm. A change of side starts a 250 ms window that holds the I terms at zero, and the crash flip runs on the
reversed side. The motor stop is off with 3D, the dynamic idle no longer lowers the motor range's low end,
and the wing RMS output reads the motors as 3D values. The settings take the 3D feature, its switched mode,
the middle stick, the 3D throttle deadband and the protocol's 3D deadband edges from the stored
configuration.

The PID oracle gains 3D runs over DShot and analog endpoints with the switch, the reversal, disarms, failsafe
and the crash flip, and one run in five takes a minimum check from 1600 to 2000. Every step replays exactly,
and the earlier PID and mixer vectors stay byte for byte. The runs do not cover a wing build. Nine
tampered paths each fail the vectors.

## D292. Compass read cycle (2026-10-17)

`Compass.Read_Cycle` is one call of the compass task. With the bus busy it makes no read and comes back in
500 us, and without new data from the device it comes back in 1 ms. With new data it reads the sample through
`Update` and comes back after the read interval. Init sets the read interval from the device's output data
rate: the period less two 1 ms rechecks and a twentieth of the period, or the 40 Hz task period for a device
without a rate. The rate's subtype holds the drivers' rates, from 16 Hz, where the reference's 16-bit period
still fits, to 400 Hz, where the interval stays positive. A call without a read clears the beep and save
requests. Every call ignores the task's execution rate, which the caller applies to the scheduler. The
settings take the rate from the detected device.

The compass oracle gains read cycle runs over the drivers' rates and no rate, with a busy bus in one call in
six and no new data in one in four. Every period, read interval and step replays exactly, and the earlier
compass vectors stay byte for byte. Six tampered paths each fail the vectors.

## D293. Multiple gyros (2026-10-17)

`Adaflight.Gyro_Filters` takes up to four sensors. Each sensor keeps its own alignment, zero offset,
calibration with its remaining cycles, and last zeroed and aligned counts. `Accumulate` takes one sample and a
data-ready flag from each sensor. An enabled sensor with new data runs a calibration cycle while its
calibration runs, else takes its new counts, and a sensor without new data keeps its last counts. The rate is
the average of the scaled counts over the enabled sensors that finished calibrating, summed in sensor order
from zero, and keeps its last value while none has. A sensor whose calibration ends on a sample joins that
sample's average with the counts it held before the calibration. A calibration starts on every enabled sensor
and completes when all have. The sensors share the scale and the sample time, since the reference enables
only sensors that agree on both. The settings take the first sensor's alignment from the stored configuration
and enable it alone, until the sensor selection at startup is ported.

The gyro oracle gains a four-sensor build that reads each sensor through the oracle's own read function, with
random enabled sets including all four and none, which enables the first, per-sensor alignments, missing data
in one sample of ten, and a movement burst on one sensor during calibration. Every step replays exactly, and
the earlier gyro vectors stay byte for byte. Seven tampered paths each fail the vectors.

## D294. Gyro selection at startup (2026-10-17)

`Adaflight.Gyro_Selection.Choose` picks the gyro sensors at startup. It scans the stored detected flags, or
every sensor when they are zero, together with the enabled setting and every sensor with a configured bus,
and the detected sensors are the scanned ones that answer. Without one it stores nothing and reports a scale
of one and a 1 kHz sample rate. Otherwise the stored flags become the detected ones with a configuration
write whenever the detected set differs from them, where the reference compares the scanned set, which a
configured sensor that never answers keeps different at every boot, so it writes at every boot (F236). The enabled sensors are the detected ones in the enabled setting, or the lowest detected
one, and only the lowest enabled one when the enabled sensors disagree on sample rate or scale. The enabled
setting takes the result with a write when it changes. The overflow protection holds only when every enabled
sensor has it, and the scale and sample rate are the first enabled sensor's. The caller hands the enabled
sensors and the scale to the gyro unit (D293).

The gyro selection oracle builds the reference's initialization for four sensors with its detection
weakened, so the oracle answers per sensor with a hardware type, the detection result that sets the
sample rate, and a scale, and runs three boots per sequence, each keeping the stored settings of the
boot before. Every boot replays exactly. Seven tampered paths each fail the vectors.

## D295. PPM and PWM receiver inputs (2026-10-17)

`Adaflight.RX_PWM` decodes the pulse receivers' timer captures. The PPM decoder rebuilds each edge's
time from the 16-bit capture, the overflows counted since the start and a wrap since the last edge,
divides it by the count divisor that a shared motor timer sets, and takes the time since the
previous edge in 32-bit arithmetic that wraps. A gap longer than 2.7 ms ends a frame. After 25
frames with the same pulse count, from 4 to 12, that count becomes the frame size. Each frame with
that many pulses while tracking hands its pulses over as the channels, times out the rest and counts
the frame. A pulse outside 0.75 to 2.25 ms stops the tracking until the next sync and clears the
pulses. The parallel PWM decoder times each of eight channels from its rising to its falling edge in
16-bit arithmetic, tells the caller which edge to look for next, and times a channel out after ten
overflows without an edge. The receiving checks are whether a PPM frame arrived since the last check
and whether any channel holds a pulse.

The pulse oracle includes the reference's decoder source with the timer and pin drivers stubbed and calls its
handlers directly: PPM signals with changing channel counts, stray pulses and count divisors over a 16-bit
timer whose overflow comes before the edge at the wrap, and PWM edges and overflows on random channels. Every
event replays exactly. Nine tampered paths each fail the vectors.

## D296. Telemetry port sharing (2026-10-17)

`Adaflight.Serial_Feature_Map` gains the port queries the receivers and telemetry protocols ask. `Port_Sharing`
says from the port's function bits whether a port has a function, and whether alone or with others.
`Port_Shared_With` says whether a port has the shared function and one of a mask's functions, with the mask
taken to 16 bits, the width of the reference's parameter. Every caller there passes functions below bit 16.
`Telemetry_Shares_RX_Port` exposes the receiver sharing check the configuration check already used.
`Provider_Port` and `Provider_Baud` find a telemetry protocol's port and baud rate in the build's telemetry
slots. `Telemetry_Enabled` runs telemetry on a port of its own, and on a shared port while the telemetry mode is
on, or while armed where no telemetry mode is set up. `Sensor_Enabled` checks a sensor bit against the
disabled mask.

The serial map oracle gains a sharing run in both of its builds that queries every port, function, protocol,
mode and sensor over drawn assignments. Every query replays exactly. Six tampered paths each fail the vectors.

## D297. SD card file system: sector cache, volume and FAT entries (2026-10-17)

`Adaflight.FAT` contains the on-disk side of the FAT file system the flight log writes to on an SD card, and its
sector cache. The partition table gives the first partition of a FAT16 or FAT32 type, or their LBA types, with
a start sector above zero, when the sector ends in the boot signature. The volume ID sector must have 512-byte
sectors, two FATs, the boot signature and a cluster of 1 to 128 sectors that is a power of two. The clusters
after the reserved area, the two FATs and the FAT16 root directory make the volume FAT12, which is refused,
FAT16 up to 65524 clusters, or FAT32. A refused sector keeps the fields set before the check that refused it,
and the sizes wrap in 32 bits on a damaged sector. The 8.3 names take eight characters of the base name and
three of the extension in upper case, and a base name longer than eight runs on into the extension.

The cache contains eleven 512-byte sectors. Each entry keeps its sector number, its state (empty, in sync,
reading, writing, dirty), access and write timestamps from one counter, a lock, a 6-bit retain count that
wraps, a discard hint and the run of sectors the card may erase ahead of a multi-block write, set from four
up. A sector takes its own entry, else an empty one, a synced discardable one or the synced one used longest
ago, never a locked or retained one. A sector past the volume, or a write to the partition table, marks the
file system fatal. The flush writes the unlocked dirty sector that turned dirty first. FAT entries are read
from either FAT and written to the first, 16 bits on FAT16 and the whole word on FAT32, where a read keeps
the low 28 bits.

`Adaflight.FAT_FS` is generic over the card, in the pattern of the menu units: a read the card accepts or
refuses, a write with the card's answer (in progress, busy, done, failed), and the start of a multi-block
write. The card reports a completion through `Read_Complete` or `Write_Complete` with the buffer the
operation used. The reference hands the card the cache buffer's memory and the card fills or sends it in the
background. The port copies a sector to the card at the write call and into the buffer at a read's
completion, so a sector changed while its write is in flight goes out as it stood at the call. The count of
dirty entries stops at the ends of a 32-bit integer, where the reference's count is undefined. The units are
SPARK for the cache indices, the entry offsets within a FAT sector and the sector field reads.

The FAT oracle includes the reference's file system source over a stub card. The card keeps written sectors
in a table, makes up the rest from the sector number, accepts or refuses each operation from a scripted draw,
and completes accepted ones at later steps, now and then into another buffer. The harness replays 3664 helper
records (chain markers, powers of two, rounding, 8.3 names, entry markers, FAT positions for every volume
type), 1500 partition table and volume ID parses with mutated fields and the cluster counts at the FAT12,
FAT16 and FAT32 boundaries, and 28 sequences of 700 cache and FAT entry calls. Half of the sequences stay
inside the volume, and four retain two sectors past the 6-bit count. Every call, card operation, result,
cache entry and the hash of the cache memory replays exactly. Twenty-six tampered paths each fail the
vectors. Two timestamp comparisons cannot tie, since every timestamp comes from one counter.

## D298. SD card file system: clusters and the file cursor (2026-10-17)

`Adaflight.FAT` gains the file handles: three open files, the free-space file and the working directory. Each
handle keeps its cursor's offset, cluster and previous cluster, the size written and the size of its
clusters, its mode bits, the cache sectors it holds at the cursor, its directory entry's place, and the
operation queued on it (a seek, a free cluster or supercluster append, or the lock a contiguous file puts on
the free-space file). `Adaflight.FAT_FS` gains the operations on them. The cluster search finds a free
cluster, a free cluster at the start of a FAT sector, or a taken one, and skips the free-space file without
moving its FAT sector (F237). A FAT fill chains, chains and ends, or frees a run of entries, and reads a
sector first only where the fill leaves part of it. A directory entry takes the size of the file's clusters
while the file is open and the size written on a close or a delete, with the deleted mark, and a directory's
entry keeps no size.

A regular file appends the next free cluster from the last one allocated, ends it in the FAT, links it
after the file's last cluster and saves the entry. A contiguous file takes the free-space file's first
supercluster: the free-space file's entry first, then the FAT, then the file's entry, and the volume is full
once the free-space file is shorter than a supercluster. The cursor sector is retained for a read and locked
for a write, read first when the write leaves part of it, and for a contiguous file that appends, with the
rest of the supercluster to erase ahead. A seek that waits for at most one FAT read completes at once, and a
longer one queues on the file. A seek from the current position forward moves by the target position
(F238). Writes and reads go sector by sector until the cache or the card makes one wait. The free-space
search looks for the longest run of free clusters that starts a FAT sector, each run capped at the largest
file size. A cluster size of zero, which a parsed volume cannot have, divides to zero as the Cortex-M divide
does, and a fill on a volume neither FAT16 nor FAT32 writes nothing where the reference writes past the
sector. The units are SPARK for the copies' offsets within a sector and the entry offsets.

The FAT oracle gains a file run: a FAT region that follows a run list of chains, a fragmented chain, made-up
values and a free-space file aligned to a FAT sector, three open files of the flight log's kinds, and 32
sequences of writes, bytes, reads, seeks from each origin, tells, polls, flushes, cluster searches from the
free-space file's start and the last allocation, entry saves, FAT fills, the free-space search and operation
steps. Some sequences start with a one-cluster free-space file and fill the volume, some run the search to
its end, and two large cards with 64 KB clusters cap a free run at 65535 clusters. Every card operation,
result, byte read, file handle, cache entry and the hash of the cache memory of the 23000 steps replays
exactly. Twenty tampered paths each fail the vectors, among them the two corrections of F237 and F238. Three
are equivalent: a contiguous file never seeks past the free-space file's start, the single-byte write takes
the same locked sector either way, and a contiguous file's cursor stays below the free-space file. The
working directory's step in the poll waits for the directory operations.

## D299. SD card file system: files and directories (2026-10-17)

`Adaflight.FAT_FS` gains the file and directory operations. A directory walk reads a directory entry by
entry and moves to the next sector after sixteen entries, until the end of the directory's clusters. A file
opens by name in the working directory: the search skips volume labels and refuses a file opened as a
directory or the other way round. When the mode creates, the new entry takes the first free or deleted
entry, and a full subdirectory first grows by a zeroed cluster, with the "." and ".." entries in a new
subdirectory's first sector. The FAT16 root directory cannot grow. A new entry takes the name, the
attributes and the local date and time when the clock is set, else 2015-12-01 at midnight. An opened file
then seeks to its start. A new contiguous file locks the free-space file once nothing else holds it, an
existing file in append mode seeks to its end, and an existing file opened only to write is truncated. "."
opens the working directory again.

A truncation saves the entry first, then frees the chain from the first cluster to its end mark (F239), or
gives a contiguous file's clusters back to the start of the free-space file. A delete is a truncation that
marks the entry deleted, then a close. A close saves the entry with the size written, except for
directories and files opened only to read, lets go of the retained entry sector, the held cursor sectors and
the free-space file's lock, and frees the handle. The working directory is a copy of an open directory's
handle, or the root.

The reference calls the caller's callbacks inside the operations, with the file or none. The port records
each as a notice, the caller's number and the handle, in a list of sixteen that the caller takes after each
call. The clock comes in through the instantiation and is read when a new entry takes its date and time. A
handle never set up holds cache index 0, as a zeroed one does, so a misuse of such a handle behaves the
same. The units are SPARK for the entry offsets within a directory sector and the handle references.

The FAT oracle gains a directory run: cards whose root directory contains a label, a long-name piece, the
free-space file, a deleted entry, log files, a LOGS subdirectory with its own entries and a text file, in a
drawn order and now and then with leftovers after the end mark, FAT16 roots of 16, 32 and 512 entries, and
26 sequences of opens in every mode, directory makes and changes, closes, deletes, truncations, walks,
writes, reads and seeks, with the clock never set, set, or set now and then. In two sequences the label has
the name of a directory the sequences make. Each step runs first in a child process, and a step that would
not return ends its sequence (F239). Every card operation, clock read, result, entry read, file handle,
finder, notice, cache entry and the hash of the cache memory of the 18200 steps replays exactly.
Thirty-one tampered paths each fail the vectors. In twelve of them the port does not return from a step the
reference returns from.

Amended 2026-10-24: the truncation's chain walk stops at a reserved cluster, so an empty file frees
nothing, as declared in D6 (F239). The FAT oracle compiles the reference source with the same change,
which alters 3392 of the directory run's 18200 steps. They replay exactly, and dropping the stop fails
them.

Amended 2026-10-24: the cluster search recomputes its FAT sector and entry index after it skips the
free-space file, as declared in D6 (F237). The FAT oracle compiles the reference source with the
same change, which alters 11096 of the file run's 23000 steps, 1490 of the directory run's 18200 and
154 of the initialization run's 40200. They replay exactly. Keeping the sector fails them, and so
does a position taken before the cluster rounds up to the jump.

Amended 2026-10-24: a seek from the current position moves by the offset, bounded by the bytes left
in the file, as declared in D6 (F238). The FAT oracle compiles the reference source with the same
change, which alters 11362 of the file run's 23000 steps. They replay exactly. Seeking by the target
position fails them, as does dropping the bound or bounding by the file size.

## D300. SD card file system: initialization and shutdown (2026-10-17)

`Adaflight.FAT_FS` gains the initialization, the poll and the shutdown. The initialization reads the
partition table and the volume ID, sets the root as the working directory, and opens the free-space file,
"FREESPAC.E", making it when it does not exist. A free-space file of any size ends the initialization. An
empty one takes the longest free run that starts a FAT sector, less 100 clusters, cut to one more than whole
superclusters, when more than a supercluster is left. Its chain is written, then its entry. A broken
partition table, volume ID or free-space file leaves the file system fatal with the error. The free-space
file's callback runs inside the operation, as the file system's own notice number 15. The poll runs when the
card's own poll found it ready: it flushes the dirty sector written first, then continues the initialization
or the files' operations. The shutdown closes every file and flushes the cache, or skips both when dirty,
then zeroes the file system and keeps its pending notices. A start sets only the state, the step and the
allocation start, so a start after a shutdown begins from a zeroed file system.

The FAT oracle gains an initialization run on thirteen kinds of card: FAT16 and FAT32 cards without a
free-space file, one with a free-space file that has clusters, one whose free-space file is empty, one whose
free-space file has one byte, a partition table without its signature, one without a FAT partition, a volume
ID with one FAT, a full FAT16 card, a FAT16 root directory with no room, a FAT32 root directory that grows
by a cluster, and FAT16 and FAT32 cards whose one free run starts a FAT sector and is 100 clusters longer
than whole superclusters. Each sequence polls to the end of the initialization, then opens, writes and
closes log files, makes and enters a directory, shuts the file system down, dirty or not, and starts it
again. Every card operation, result, step, search state, file handle, notice, cache entry and the hash of
the cache memory of the 40200 steps replays exactly. Fourteen tampered paths each fail the vectors, and
three are equivalent. The cut leaves one more than whole superclusters, so the length left never equals a
supercluster. Every failure of the cache passes through its assertion, which has already made the file
system fatal with the generic error. A shutdown that zeroes the file system has no file open, so its poll
raises no notice to keep.

## D301. Flight log on SD card (2026-10-17)

`Adaflight.Blackbox_SD` contains the flight log's SD card device over `Adaflight.FAT_FS`. A log start makes
or opens the "logs" directory, reads every name in it, and keeps the largest number of the names that start
with "LOG" and end in "BFL". The number is the five characters between, read as C reads an integer: leading
blanks, a sign, then digits. The start then enters the directory, closes the directory's handle, and opens
the next number's file, "LOG", five digits and ".BFL", to append to a contiguous file. A failed directory
open starts over, and a failed file open tries the same name again. The number grows when the file opens,
and a sixth digit drops off the name (F240). A log end closes the file, or deletes it when the log is not
kept, and is done once the close or delete is queued. Bytes and texts go to the open file, and a text counts
its whole length whatever the file takes. The flush starts the write of the oldest dirty sector that is not
locked, and is done when there is none. The forced flush is done once no sector is being written and no
unlocked sector is dirty, and starts a flush otherwise. The device opens while the file system is neither
fatal nor unknown and not full, and works while the card is inserted and functional and the file system is
ready. The log file number is the largest number cut to 8 bits while a log is open, else -1.

The file system reports the two opens as notices. The unit takes them after each call it makes and after the
main task's poll, which `Adaflight.Task_Functions` now runs before the flash erase. The unit is SPARK for
the log state, the bounds of the name number and the handles it passes on.

The flight log oracle runs the reference's flight log device layer and file system on the FAT oracle's stub
card: 22 sequences on FAT16 and FAT32 cards, most with a LOGS directory of drawn log names, and six built
for one path each: a log named with a sign, a tab before a number, a file named LOGS that makes the
directory fail, a next number that wraps to a directory named LOG00000.BFL, names that put a larger number
after the largest log and larger ones in names that are not logs, and a file system shut down dirty and
started again while the device is queried. Each sequence runs device opens and queries, log starts and ends,
bytes, texts, flushes, the header budget and the main task's poll between them. Every card operation,
result, log state, file handle, notice, cache entry and the hash of the cache memory of the 42800 steps
replays exactly. Thirty-two tampered paths each fail the vectors. One is equivalent: the end of the name
walk lets go of the directory's held sector, which the directory's close later in the same call lets go of
anyway. The task function oracle now builds with the SD card, and its 4800 main task runs poll the file
system before the flash erase.

## D302. SPI receiver selection (2026-10-17)

`Adaflight.RX_SPI` maps the setting's SPI protocol numbers to the receiver families: V202 at both rates,
SYMA X and X5C, CX10 and CX10A, H8_3D, the acknowledgment payload protocol, the five FrSky protocols, FlySky
and FlySky 2A, SFHSS, Spektrum DSM, Redpine and ExpressLRS. No build compiles the KN receiver, so its
number, like any number past the last, has no family. `Adaflight.RX_SPI_Provider` is the SPI receiver layer
that the receiver core takes as its provider, a generic whose procedures are the SPI device, the interrupt,
the dispatcher and the families' start, packet check, frame processing, channel setting and stop. The start
fails without the device or a family. Otherwise it starts the family, then the interrupt when one is
configured, clears the packet flag, hands the receiver core the layer's functions, enables the dispatcher,
and answers with the family's start. A frame check asks the family for a packet. A packet with data marks a
new packet and takes the interrupt's time as the frame time, and the family's processing request passes
through. Only FrSky processes frames, and only ExpressLRS stops. A channel read outside the receiver's
channel count reads 0 and leaves a new packet waiting. Otherwise the first read after a new packet takes the
family's channels. The unit is SPARK for the channel index and the family each step calls.

The SPI receiver oracle runs the reference's SPI receiver layer with every protocol a build compiles, and
with the device, the interrupt, the dispatcher and each family's procedures answering by a draw and
recording their calls: 60 sequences, one start for each protocol number, a second with failing devices and
starts, and a third with a device that never starts, then 300 steps each of frame checks, frame processing,
channel reads inside and outside the count, stops and interrupt enables. Every start answer, call, frame
report, frame time, packet flag and channel replays exactly over the 18000 steps. Twenty-three tampered
paths each fail the vectors. One is equivalent: the start clears a packet flag that a start, run once on a
new state, always finds clear.

## D303. Storage information commands (2026-10-17)

`Adaflight.Command_Line` gains sd_info and flash_info over the SD card's and the flash chip's states in its
environment. sd_info reports an SD card mode of none as not configured, a missing card as none inserted, and
a card that does not work or did not finish its start as a failed start. Otherwise it prints the card's
manufacturer in hex, its size in kB as half its block count, its production month and year with zeros to two
and four digits, its revision, an opening quote and the five bytes of the card's name as they are, null
bytes included, and the file system's state: ready, initializing, or fatal with the reason for a partition
table without a FAT partition or a bad volume ID. The quote stays open (F242). flash_info prints the chip's
geometry with its JEDEC id in eight hex digits, the partition table's entries with their kind names, and the
flash file system's size and use. The size comes from the first flash file system partition in the whole
table: its last sector plus one less its first, times the sector size in unsigned 32-bit arithmetic, so a
partition whose first sector lies past its last gives a wrapped size. Without such a partition the size
reads 0 (F241). The partition listing loop has a loop invariant, like every listing loop in the command
line, so the proof does not unroll it.

The command line oracle gains a storage mode: sd_info and flash_info between SD card mode settings,
"!sdcard" lines with cards inserted or not, working or not, every file system state and error, and names
with null and high bytes, and "!flash" lines with chips of several geometries, a missing chip, and partition
tables of one to five entries of every kind, some with a first sector past the last. The flash chip answers
through the reference's flash driver, so the partition lookups and kind names are its own. Every reply to
the 1502 lines replays exactly. Seventeen tampered paths each fail the vectors.

## D304. Restart commands (2026-10-17)

`Adaflight.Command_Line` gains bl and msc, which restart the board into another mode through a new restart
field of the command's effects. bl, with no option or one that starts with rom in any case, prints the
restart line and asks for a restart into the ROM bootloader. Any other option is an error, since the builds
the port follows have no flash bootloader. msc, while the mass storage is ready, prints its restart line and
asks for a restart into mass storage with the stored timezone offset, or with an offset read from its
argument as C's atoi reads it: blanks, a sign and the digits up to the first other character. The offset
must lie within 780 minutes either way. An argument without digits reads 0, so msc abc restarts with no
offset. Without the mass storage, msc prints that the storage is missing. Neither command asks for the plain
restart that save and exit ask for.

The command line oracle prints a restart into the bootloader or into mass storage after its line, with the
restart's kind and offset, and gains a restart mode: bl and msc with options and offsets of every kind
between mass storage readiness lines and timezone settings. Every reply, restart and offset of the 1200
lines replays exactly. Fifteen tampered paths each fail the vectors.

## D305. Help command (2026-10-17)

`Adaflight.Command_Line` gains help, which lists the commands of the build in the order of its command
table: each command's name, its description after a dash, and its arguments on the next line after a tab.
The table is that of the build the command line oracle compiles, so it names commands the port does not have
yet, such as status and the flash tools, whose lines answer ERR_CMD_NA. A search keeps the commands whose
name or description holds it without regard to case, and a search that keeps none prints the no-match error
with the search in quotes. A command without a description prints no dash, one without arguments no second
line, and the arguments of vtxtable end with their own line end, so an empty line follows its entry.

The command line oracle gains a help mode: help alone and with searches that match names, descriptions,
parts of words in any case, several commands or none. Every reply of the 400 lines replays exactly. Thirteen
tampered paths each fail the vectors.

## D306. DShot programming command (2026-10-17)

`Adaflight.Command_Line` gains dshotprog, and its generic gains the board's DShot programming as procedures:
a command written to one ESC or to all, the motors switched off and on, an ESC information read started and
its bytes taken, and a wait. `Adaflight.Reply_Command_Line` takes them from `Adaflight.CLI_Board_Steps`,
which does nothing, for the proof. Without the DShot protocol or arguments the command is the parse error.
Its first word names the output, read as C's atoi reads it: an output below the motor count, or 255 for all
of them, else the output error, after which nothing more happens. Each later word up to 47 switches the
motors off before the first such command, writes the command, and prints that it was sent. The ESC
information command instead reads the information of the output's ESC, or of every ESC in turn, when the ESC
sensor feature runs, and prints that it is not supported otherwise. A word past 47 is the command error. The
motors switch back on at the end.

An ESC information read prints its heading, starts the read, writes the information command, waits 10 ms and
takes the bytes. `Adaflight.ESC_Info` reads the frame. The byte at 12 gives BLHeli_32 for 254, KISS v2 for
255 and KISS v1 otherwise, with frames of 64, 21 and 15 bytes. A read of the kind's length with the KISS
checksum in its last byte prints the ESC type, the MCU serial number, the firmware version and, for the
later kinds, the rotation direction and 3D, with the voltage and current limits and the four LEDs of
BLHeli_32. A bad checksum is the checksum error, and any other length prints that no information came. The
BLHeli_32 type is the text from byte 31, up to 32 characters ended at a zero byte. The reference writes that
zero over the checksum byte, after the check. Its BLHeli_32 version format ends in a lone percent sign,
which its printf drops.

The command line oracle gains lines that set the DShot protocol and queue ESC information replies, and
records each line's DShot commands with their motors, the ESC information read starts in their order, and
the motor switches. Its dshotprog mode drives outputs and commands of every kind with the ESC sensor on and
off, and KISS v1, KISS v2 and BLHeli_32 frames with good and bad checksums and reads of other lengths. Every
reply, command and switch of the 1575 lines replays exactly. Twenty-nine tampered paths each fail the
vectors, one by stopping the harness with a range error. One is equivalent: no frame is 12 bytes long, so
reading the version byte from a read of 12 bytes as well changes nothing.

## D307. Options command (2026-10-17)

`Adaflight.Command_Line` gains options, which prints each of the build's option numbers on its own line. The
numbers come in through the environment, up to 64, since the target phase fixes them per build. The listing
loop has a loop invariant.

The command line oracle links the reference's build information unit, so its option numbers are those of the
build it compiles. A "!buildopts" line prints them for the harness to take in. Its options mode runs options
alone, with arguments, spaces and a comment, in other cases and misspelled. Every reply of the 60 lines
replays exactly. Five tampered paths each fail the vectors.

## D308. Peripherals command (2026-10-17)

`Adaflight.Command_Line` gains peripherals. Its environment gains the serial ports in the order of the target's
list, each with whether the board has it and the functions it opened with, whether the soft serial feature runs
as latched at boot, the build's gyro positions with the enabled gyros and each gyro's hardware and bus, and the
accelerometer, barometer and compass with their detection, hardware and bus. A bus is none, an SPI bus by
number, or an I2C bus by number with the device's address.

The command lists each port the board has, and each port it lacks that a feature claims or that is a soft
serial port, with "feature SOFTSERIAL off" or "no pins" as the reason. The claims follow in the features'
order, those whose functions the port opened with first and starred. Each gyro position the configuration lists
as detected prints its hardware, starred when enabled, and its bus. The accelerometer, barometer and compass
print the detected hardware with its bus, unless its code is AUTO or NONE or names no hardware of the build. A
sensor not detected prints its configured hardware past AUTO and NONE, by code where the build has no name for
it. The DroneCAN node lines are left out, since the oracle's build compiles them out.

The command line oracle writes the reference's serial port usage list in place and defines the detected gyro
and sensor tables, the sensor mask and the SPI device lookup, so scripted lines set the ports, the gyro and the
sensors with their buses. Its peripherals mode drives ports there and missing with random functions, port
settings, soft serial switches latched as at boot, and sensor hardware settings, some stored out of range.
Every reply of the 300 lines replays exactly. Seventeen tampered paths each fail the vectors. One is equivalent.
No target's port list holds the identifier just past its soft serial ports, so counting that identifier as a
soft serial port changes nothing.

## D309. Status command (2026-10-17)

`Adaflight.Command_Line` gains status. Its environment gains the board's status: the MCU's name and clock, the
clock sources where the platform reports them, the internal ADC's reference voltage and core temperature, the
stack with its use where the build checks it, the stored configuration's size and the storage's, the SPI and
I2C devices with the I2C errors, the OSD's display port device with its size, the build key and release name,
the millisecond clock, the real-time clock, the battery and the reasons arming is disabled. It also gains the
GPS receiver's link state, u-blox platform, port baud rate index, solution and satellite signals, whether the
GPS feature runs as latched at boot, the rangefinder, optical flow sensor and pitot with the accelerometer's
revision, and for each gyro its interrupt mode and the device count of its bus. The command reads the task
rates and the load from the scheduler's state.

The command prints the MCU line, the stack, the configuration and the bus devices, then each gyro position the
configuration lists as detected with its hardware and whether it is enabled, locked to an interrupt, served by
DMA or sharing its bus, and each detected sensor with its hardware. The GPS line follows: the provider without a
port, or the port with its actual and set baud rates, then whether the receiver is configured and the u-blox
platform, and while it delivers data the satellites, their mean signal, the dilutions, the position and the
time. The OSD, sd_info's lines, the flash chip, the build key, the uptime with the local time, the load with
the gyro, receiver and system rates, the battery and the arming disable reasons close it. The DroneCAN lines are
left out, since the oracle's build compiles them out.

The reference declares a GPS state for processing data and never enters it, and the GPS link has no such state.
For a detected sensor whose hardware code names no hardware of the build the reference prints the name through
a null pointer, and adaflight prints an empty name. For a GPS port that never opened the reference reads the
port's baud rate through a null pointer (finding F243).

The command line oracle defines the MCU, clock, ADC, stack, storage, bus and millisecond clock readings, links
the reference's GPS and runtime configuration units with their symbols weakened for the GPS state and the arming
disable names, and writes the battery state in place, so scripted lines set what status reads. Its status mode
drives each of them, GPS feature switches latched as at boot, and GPS and time zone settings. Every reply of
the 600 lines replays exactly. Twenty-eight tampered paths each fail the vectors. The twenty-ninth changes the
separator between gyro entries. The oracle's build has a single gyro position, so the separator never prints.

## D310. Env command (2026-10-17)

`Adaflight.Command_Line` gains env, which prints status's readings as NAME=value lines: the firmware's name and
version, the target, the board identifier, the build's date, time and revision, the MSP API version, the
board's name and manufacturer when they are set, the build key and release name each where the build has it,
the MCU with its clock, the internal ADC's readings, the stack, the stored configuration, the bus devices, each
detected gyro with the gyro count, each detected sensor, the GPS receiver, the OSD, the flash chip, the uptime
with the local time, the load with the rates, the battery and the arming disable reasons one space apart. A text
after the command keeps the names that start with it, compared with case.

The command line oracle's env mode drives the status mode's lines, board information lines, and env with
prefixes of every name, other texts and none. Every reply of the 600 lines replays exactly. Seventeen tampered
paths each fail the vectors. One is equivalent. The arguments start past the spaces after the command's name, so
env's own skip of leading spaces never finds one.

## D311. Passthrough commands (2026-10-17)

`Adaflight.Command_Line` gains escprog and gpspassthrough, and its generic gains the board's passthrough starts as
procedures: an ESC's serial link by output and protocol number, and the GPS receiver's, each telling whether it
started. `Adaflight.Reply_Command_Line` takes starts that fail from `Adaflight.CLI_Board_Steps` for the proof.
escprog takes a protocol, chosen by a word that starts sk, bl, ki or cc without regard to case, then an output
read as C's atoi reads it: an output below the motor count, or 255 for all of them with KISS. Another protocol
is the parse error, another output the output error, and a third word or no words the argument count error, each
ending the command. A start that fails prints the start error, and gpspassthrough prints its error the same way.
The serialpassthrough command is left for the target phase, since it opens and configures the board's serial
ports itself.

The command line oracle replaces the reference's passthrough starts with ones that record each call and return a
scripted result, and prints each command line's starts with their output and protocol. Its passthrough mode
drives escprog with protocols and outputs of every kind and gpspassthrough, with starts that succeed and fail.
Every reply and start of the 400 lines replays exactly. Fifteen tampered paths each fail the vectors.

## D312. Gyro register dump command (2026-10-17)

`Adaflight.Command_Line` gains gyroregisters, and its generic gains the board's read of a gyro's register by gyro
position. Its environment gains whether the raw gyro's detected sensor is an ICM-45605 or an ICM-45686. For each
gyro position the configuration's enabled mask names, the command prints an empty line and the gyro's heading,
then the WHO_AM_I, CONFIG and GYRO_CONFIG registers in upper case hexadecimal without leading zeros. When the raw
gyro is an ICM-456xx part it prints that part's five registers with their addresses instead, for every gyro
position, since the part comes from the raw gyro's detection.

The command line oracle defines the register read over register files that scripted lines write, and scripted
lines set the raw gyro's detection and the enabled mask, which is no setting. Its gyroregs mode drives registers
with every value, detections of both register sets and enabled masks. Every reply of the 400 lines replays
exactly. Ten tampered paths each fail the vectors.

## D313. Flash tool commands (2026-10-17)

`Adaflight.Command_Line` gains flash_erase, flash_scan, flash_write and flash_read, and its generic gains the
board's flash file system tools: whether a file system is there, the whole erase started, whether the flash is
ready, a step of the erase, the verify of the whole flash, a seek, a write, a flush, and a read of up to a length
of bytes at an address with the count read. `Adaflight.Reply_Command_Line` takes tools that do nothing from
`Adaflight.CLI_Board_Steps` for the proof, and the command line's effects gain the erase's beeper sound.

flash_erase does nothing without a file system. It starts the whole erase and polls the flash, taking an erase
step and printing a dot for each poll before the flash is ready, with a line end after every 122 dots, then asks
for the erase sound and prints the done line. flash_scan prints the board's verify verdict. flash_write writes
the text after the address and its spaces at the address, read as C's atoi reads it, and flash_read prints a
count of bytes from an address in reads of up to 32 bytes, stopping at a read that takes none. Both print the
argument count error without a space. The verify of the whole flash, a test pattern written over the volume and
read back, stays with the board.

The command line oracle replaces the reference's flash file system calls with ones over a scripted volume and
records each call. Its flash mode drives the four commands with erases of up to 300 polls, verify verdicts,
addresses and lengths of every kind, and volumes that are missing or end early. Every reply, beeper request and
call of the 400 lines replays exactly. Fourteen tampered paths each fail the vectors, one by stopping the harness,
since an erase on a board without a file system never ends.

## D314. OLED dashboard (2026-10-17)

`Adaflight.Dashboard` draws the board's state on a 21 by 8 character OLED display. An update reads a record of
readings and writes display operations that the board performs: a start that tells whether the display answers,
a quick clear, a position, a line, a character and a text of up to 40 characters, at most 256 of them per update.
Every 200 milliseconds while the menu system leaves the display alone, the update draws the armed page once on
arming, and while disarmed it draws the current page and a corner with the failsafe phase, the receiver's state
and a ticker. A disarm, a fixed page or a start forces a page change. With cycling on, the pages change every five
seconds in the order welcome, armed, profile, rate profile, GPS, receiver, battery, sensors, tasks, flight log and
debug, skipping welcome and armed, and the GPS page asks for a change when the GPS feature is off. A page change
starts the display again, so a display connected late can answer, then clears it and prints the page's title when
the display answered.

The welcome page prints the firmware's name, version and revision with the target's name. The other pages print
the PID profile's gains, the rate profile's rates, the GPS solution with its counters, packet log and a bar per
satellite signal, the channels as percentage bars two to a row, the battery's voltage, cells, current and drawn
capacity with their bars, the sensors' readings and the attitude, each enabled task but the serial task with its
times and loads, the flight log's file number, and four debug values. In SPARK the proof shows that every line
and every operation list stays within its bounds for any reading. The reference overruns its line buffer with
wide task and battery values (F247), where adaflight's 40-character text holds those lines whole. Adaflight
draws the reference's satellite graph at column 250 (F244), the extra channel after an odd channel count (F245),
the null ticker character (F246) and the minus sign on a negative current's decimal digit (F248).

The dashboard oracle builds the reference's dashboard with a display driver that records each operation, and
scripts the readings: arming, receiver signal, GPS solutions and satellite signals, battery readings with
negative currents, task statistics, flight log devices and file numbers, debug values, a display that does not
answer, clock steps across the 32-bit wrap, and cycling, fixed pages and cycle resets. Every operation of 30
random runs and four runs that hold the flight log page replays exactly. Of 30 tampered paths, 28 fail the
vectors. Two are equivalent: the next page time that Init sets, which the forced first page change replaces
before any update reads it, and the index a cycle reset sets, from which the last page and the first page both
step past the two skipped pages to the profile page.

## D315. BLHeli bootloader protocol (2026-10-17)

`Adaflight.BLHeli_Bootloader` performs the 4-way interface's BLHeli bootloader operations on an ESC's signal
pin. It is generic over the board's microsecond and millisecond clocks, a read of the pin, and the pin driven low
or high or set as an input or an output, each taking the line's state. A byte goes out as eleven pin writes 52
microseconds apart: a high bit, a low start bit, the eight data bits from the lowest and a high stop bit, with no
wait after the stop bit. A byte comes in once the pin goes low within 2 ms. The pin is sampled 39 microseconds
after the edge and then every 52, and a high start bit or a low stop bit fails the byte. A buffer goes out with
the pin as an output, followed by a CRC-16 of polynomial 16#A001#, low byte first, while the device information's
first byte is not zero, and the pin returns to an input. A buffer comes back with the same check and an
acknowledgement, or the acknowledgement alone. A failed byte ends the read with the bytes so far in place.

A connect sends the 21-byte boot init, reads eight bytes of boot information and keeps the signature when they
start with 471. A keep-alive succeeds on the command error reply. A restart marks the device connected and sends
the run command. An erase, read, write or verify first sets the address unless it is 16#FFFF#. A write or verify
then sets the buffer, which must draw no reply, sends the data and waits for its acknowledgement. Erases and
EEPROM writes wait up to 1500 tries of 2 ms, flash writes 250, and a verify returns the bootloader's reply byte
for the interface to judge. Every bit wait ends when the signed difference of the clock and its deadline turns
non-negative, so a byte across the 32-bit wrap of the microsecond clock keeps its timing, where the reference
compares the clock with the absolute deadline and loses it (F249). The unit is SPARK for the 256-byte buffers,
the bit counts and the CRC.

The bootloader oracle includes the reference protocol with the pins and clocks over a simulated 64-bit
microsecond clock that every clock read, pin read and pin write advances by one. A scripted ESC answers each turn
of the pin to an input with framed bytes after a gap, at bit times from 44 to 60 microseconds, with low stop
bits, missing and short replies, bad checks and wrong acknowledgements. The harness runs the port over the same
simulation. The code, device information, read buffer, sent bytes, write count, hash of every write with its time
and end clock of all 540 operations replay exactly, among them 60 keep-alive exchanges stepped across the clock
wrap. The absolute deadline comparison, put back in place, fails the vectors at the exchanges across the wrap.

## D316. STK500v2 bootloader protocol (2026-10-17)

`Adaflight.STK_Bootloader` performs the 4-way interface's STK500v2 operations on an ESC's signal
pin, over the same board procedures as the BLHeli bootloader and a microsecond delay. A link record
keeps the sequence number of the last message and the 16-byte buffer short replies land in, both
kept between operations. Bits go over the line as pulses. A one goes out as a high and a low of 64
microseconds, a zero as two highs and lows of 32, from the lowest bit. A message goes out with the
pin as an output: the leader bytes FF FF 7F, the start byte 1B, the next sequence number, the body's
length, the token 0E, the body and an XOR check of everything from the start byte, then a high of 32
microseconds before the pin returns to an input.

A bit is timed from the call to the end of the next rising edge, against a deadline 250 microseconds on. A time at
or below the threshold is a zero, whose second pulse gets 250 more. A reply waits for the leader's first bit for
up to 0.5 ms after a sign-on, 5 s after an EEPROM write or a chip erase and 35 ms otherwise, skips ten bits,
learns the threshold as three quarters of the last bit's time and reads on to a zero. It then checks the start
byte, the sequence number, a length high byte of at most 1 and a low byte of at least 1, the token, the command
and its status, reads the rest of the body into the buffer, where a failed byte leaves its bits so far, and checks
the XOR. Bytes past the end of the buffer are read and checked but not kept. The reference writes them past its
buffers, and every 256-byte read does so, since the reply has a status byte after the data (F250). A length
below 2 fails, so a 253-byte read, whose reply body is 256 bytes, succeeds, where the reference fails a length
whose low byte is 0 (F252). Every deadline
is met through the signed difference of the clock and the deadline, so a bit read across the clock's wrap times
out as any other, where the reference compares the clock with the absolute deadline and waits for an edge without
end when the deadline is the clock's last value (F251).

A connect signs on and reads the two signature bytes with the SPI multi command, keeping each when the first three
reply bytes are 0, the command or 0, and 0. It succeeds when all three replies arrive, kept or not. A read loads
the address unless it is FFFF and reads the count of bytes, 0 for 256. A write loads the address and programs the
bytes with a length 10 above the count. A chip erase sends the erase sequence for the atmega8. The unit is SPARK
for the reply length, the buffer indexes and the bit counts.

The STK500v2 oracle includes the reference protocol over the bootloader oracle's simulated clock, where a delay
advances the clock by its length. A scripted ESC answers in the pulse code at its own pulse widths, fast, slow
and near the learned threshold, with short leaders, broken start bytes, sequence numbers, lengths, tokens,
commands, statuses and checks, long and cut replies, silence and long gaps. Three more runs over clean replies
read 250 to 255 bytes, time zero pulses at the threshold itself, and use addresses with one byte at 0xFF. The code,
device information, read buffer with the byte after it, sent bytes, write count, hash of every write with its time,
sequence number and end clock of all 550 operations replay exactly. Thirty-two tampered paths each fail the
vectors.

## D317. USB joystick (2026-10-17)

`Adaflight.USB_Joystick` builds the report the board sends as a USB joystick and tells whether the board may be in
use as one. The report has eight axes from the roll, pitch, third auxiliary, yaw, first auxiliary, throttle,
fourth and second auxiliary channels, each cut to whole microseconds, held to 1000 to 2000 and scaled to -127 to
127 with integer division, with the pitch inverted, then a byte of eight buttons from the fifth to twelfth
auxiliary channels, each on from 1504 microseconds. The board may be in use as a joystick when its USB device is
the composite one and connected and either no battery is present or no voltage meter is set. The reference builds
both on every STM32 target.

`Adaflight.Arming` gains the stick command gate of those builds. Once a held stick combination is taken while
disarmed, the stick commands stop when the board may be a joystick or the stick commands disable mode is on.
`Adaflight.RX_Task` names the update step's joystick report, which goes out while disarmed after the arming status.

The joystick oracle includes the reference report and test over channels at the range limits, near the button
threshold and outside the range with fractions. The arming oracle now builds with the joystick, which changes 4 to
13 sequences in each existing arming vector file, each from a step where the gate blocks a stick command, and a
joystick sequence set scripts the test. The receiver task oracle records the reports each step sends, with the
armed flag from a second generator so its existing records stay as they were. Of 16 tampered paths, 15 fail the
vectors and one, a scale factor of 255, raises an axis past 127, which the harness rejects as a range error.

## D318. BMP280 barometer driver (2026-10-17)

`Adaflight.BMP280` drives the BMP280 and BME280 barometers for the barometer read cycle (D124). It is generic over
the chip's bus: register reads and writes within a call, reads and writes started for the bus to finish while the
driver polls it, the bytes a finished read brought, the I2C address, the SPI select pin, the device's registration
and a delay. Detection waits 20 ms, prepares the select pin of an SPI chip for 10 MHz, sets the I2C address to 0x76
when none was given, and reads the chip identity, again at 0x77 when the default found none. A BMP280 (0x58) or
BME280 (0x60) is registered, its 24 calibration bytes are read, and a forced measurement starts at eight times
pressure and once temperature oversampling. Any other identity releases the select pin and clears a default
address. The chip reads both values at once in 23 ms, so only the pressure calls do work. A start writes the
measurement control, a read starts the six data bytes while the bus is free and marks the sample stale, and a
sample takes them once the bus is done, unless the bus reported an error.

The calculation follows the datasheet's integer compensation. Its 32-bit temperature terms and 64-bit pressure
terms run in modular arithmetic, so a calibration that overflows them wraps as two's complement arithmetic does,
and the one overflowing 64-bit division wraps as the hardware's does. Without a sample the pressure is 0 and the
temperature is left. The unit is SPARK for that arithmetic, which the proof shows free of overflow for any
calibration and reading.

The barometer oracle includes the reference driver with the bus, pin and delay calls stubbed over a simulated
chip, one case per process since the driver keeps its state in statics. It draws the bus, the addresses, the chip
identity and a calibration around the datasheet's example or anywhere in range, then runs the driver's calls in a
random order with scripted busy, error and start answers. Every bus, pin and delay call, answer, pressure and
temperature of the 300 cases replays exactly. Thirty tampered paths each fail the vectors.

## D319. DPS310 barometer driver (2026-10-17)

`Adaflight.DPS310` drives the DPS310 and SPL07-003 barometers for the barometer read cycle over the bus formals of
the BMP280 driver (D318), without the started write. Detection prepares the select pin of an SPI chip for 10 MHz,
sets the I2C address to 0x76 when none was given, and reads the chip identity up to five times, 100 ms apart,
until a read is acknowledged with 0x10 or 0x11. A failed read leaves the identity read before it. A soft reset, a
40 ms wait and the coefficient and sensor ready bits follow, then the coefficients in chunks of nine registers, 18
for the DPS310 and 22 for the SPL07-003, any failed chunk ending the detection. The pressure, temperature, shift
and continuous measurement settings are set with a read and, where a bit is missing, a write, the DPS310's
temperature setting taking the coefficients' sensor bit. A failed detection releases the select pin and, when the
identity was not found, clears a default address.

The chip measures continuously, with a 45 ms pressure delay and no combined read. A pressure read starts the six
data bytes while the bus is free. A sample takes the bytes the last read brought without asking the bus and
compensates them in single precision, in the reference's order of operations, with the SPL07-003's two extra
terms. The calculation cuts the pressure in pascal and the temperature in hundredths of a degree toward zero. Past
the 32-bit range, where the reference's conversion is undefined, the port holds them at the range's ends. The
vectors stay inside it. The unit is SPARK for the coefficient fields and the compensation's bounds.

The DPS310 oracle includes the reference driver with the bus, pin and delay calls stubbed over a simulated DPS310
or SPL07-003 whose registers the writes change, with failing reads, status bits, the coefficient source bit and
coefficients around a typical set or anywhere in their widths, one case per process. Every bus, pin and delay
call, answer, pressure and temperature of the 300 cases replays exactly. Of 32 tampered paths, 31 fail the vectors.
The one that drops the acknowledgement from the identity check is equivalent: a failed read keeps the identity
read before it, and a matching identity ends the detection at once, so a failed read never sees a matching one.

## D320. MS5611 barometer driver (2026-10-17)

`Adaflight.MS5611` drives the MS5611 barometer for the barometer read cycle. The chip takes commands, not register
addresses, so the driver is generic over raw bus calls: command reads and writes within a call, command reads and
writes started for the bus to finish, the bus's busy state, the bytes a finished read brought, the I2C address, the
SPI select pin, the device's registration and the millisecond and microsecond delays. Detection waits 10 ms,
prepares the select pin of an SPI chip for 10 MHz and sets the I2C address to 0x77 when none was given. It reads
one byte at the first PROM address, and a failed read or 0xFF ends the detection. A reset, a 2.8 ms wait and the
eight PROM words follow. The 4-bit CRC of the application note decides, and a PROM of zeros fails it. The check
leaves the last word with its high byte and the four check bits. A failed detection releases the select pin and
clears a default address.

The chip converts temperature and pressure one at a time, each in 10 ms at 4096 times oversampling. A start sends
the conversion command, a read starts the three ADC bytes once the bus is free, and a sample takes the bytes the
read brought once the bus is done.

The calculation follows the datasheet's compensation in 64-bit integers, with its second-order terms below 20 and
below -15 degrees. A shift of a negative term rounds down. The unit is SPARK for that arithmetic. Each product and
second-order step has a bounded subtype, and the proof shows the arithmetic free of overflow and the pressure in
pascal and the temperature in hundredths of a degree within 32 bits for any PROM and reading.

The MS5611 oracle includes the reference driver with the bus, pin and delay calls stubbed over a simulated chip, one
case per process. It draws the bus, the configured and the chip's addresses, the first PROM byte, and PROM words
around the datasheet's example or anywhere in range with a valid check, a broken check or all zeros. A chip that is
found then runs 50 of the driver's calls in a random order with scripted busy and start answers and ADC readings.
Another 60 cases always find the chip and aim most readings at first order temperatures beside the 20 and -15 degree
thresholds. Every bus, pin and delay call, answer, pressure and temperature of the 360 cases replays exactly, 211 of
them past detection. Of 31 tampered paths, 30 fail the vectors. The one that moved the -15 degree threshold to -14
degrees passed and led to the threshold cases. On the final calculation, 16 of 17 tampers fail, three of them on the
range check of a bounded stage. The one that adds 1 to the first second-order term moves the offset and the
sensitivity by at most 1, which changes the pressure only where a sum crosses a rounding step.

## D321. BMP388 barometer driver (2026-10-17)

`Adaflight.BMP388` drives the BMP388 and BMP390 barometers for the barometer read cycle over the bus formals of the
BMP280 driver (D318), with one more that enables the interrupt of an end of conversion pin. Detection waits 20 ms,
enables that interrupt when the board has the pin, prepares the select pin of an SPI chip for 10 MHz, sets the I2C
address to 0x76 when none was given, and reads the chip identity, 0x50 or 0x60. A chip on SPI sends a dummy byte
before the registers of each read, which the driver reads and drops. A failed read leaves the identity read before
it, and any other identity releases the end of conversion pin and its interrupt when the board has them, where the
reference leaves the interrupt enabled with its handler attached (F254), releases the select pin and clears a default
address. A found chip is registered, gets
the data ready interrupt when the pin exists, and has its 21 calibration bytes read. The driver then sets eight
times pressure and once temperature oversampling, starts a forced measurement and waits until the bus is free.

The chip measures both values together in 36.9 ms, so only the pressure calls do work. A start begins a forced
measurement, a read starts the six data bytes, seven on SPI, once the bus is free, and a sample takes them once the
bus is done. The interrupt reads the interrupt status and drops it.

The calculation follows the datasheet's 64-bit integer compensation. Its terms run in modular
arithmetic, so a calibration that overflows them wraps as two's complement arithmetic does, and its
signed divisions truncate toward zero. The driver gives the temperature in hundredths of a degree
and the pressure in pascals, the compensation's hundredths of a pascal divided by 100. The reference
divides by 256 and reports a pressure 2.56 times too low (F253, D6). The unit is SPARK for that
arithmetic, which the proof shows free of overflow, with both results within 32 bits, for any
calibration and reading.

The BMP388 oracle includes the reference driver with the bus, pin, interrupt and delay calls stubbed over a
simulated chip, one case per process. It draws the bus, the configured and the chip's addresses, the identity, the
end of conversion pin, the SPI dummy byte, reads that fail, the busy answers of the detection's wait, and a
calibration around the reference's sample or anywhere in range. A chip that is found then runs 50 of the driver's
calls and interrupts in a random order with scripted busy and start answers and readings. Every bus, pin and delay
call, answer, pressure and temperature of the 300 cases replays exactly, 159 of them past detection. Of 37 tampered
paths, 36 fail the vectors. The one that rounds the signed quotients of the pressure terms down instead of toward
zero moves their final sum by less than 2^27, and the reported pressure is 25 times that sum over 2^48, so it
changes a sample with a chance near one in a hundred thousand.

## D322. MAX7456 OSD chip driver (2026-10-17)

`Adaflight.MAX7456` drives the MAX7456 and AT7456E character OSD chips. It is generic over the chip's SPI device:
the select pin before and during detection, the bus instance, the clock divisor for a frequency, register writes and
reads, a byte or a buffer written alone, a transfer started for the bus to finish, whether the bus is busy, uses DMA
or still has the driver's transfer pending, a wait for the bus, the two clocks, delays and the status LED.
Initialization clears both layers, waits 50 ms, and needs a select pin, a bus instance and a free pin. At 5 MHz it
ends any running command with 0xFF and reads the OSD insertion register, whose default 0x1B shows the chip is there.
Writing the ninth character address bit and reading it back tells the AT7456E. The clock setting picks 5, 10 or 20
MHz, and the chip gets a soft reset that the driver polls to its end. The offsets become 32 and 16 minus the
configured ones.

The video system follows the configuration or, when automatic, the chip's video sense, with PAL when there is no
signal. A stall check once a second, or when forced, reads back the video mode register and sets the registers again
when the chip lost them. Once a second in automatic mode the driver compares the sensed standard with the one it set,
and after a 100 ms debounce sets the registers again for the new one. Characters go to the foreground layer. A draw
compares the layer with a shadow of the chip's display memory, half the screen per call, and sends each changed
character with its address, in auto-increment runs where the next one also changed, within 250 bytes over DMA or 12
polled and an encoding time of 20 or 10 µs. A full refresh draws until the screen is done. A font character write is
one synchronous call, so the driver keeps no font loading flag and drawing goes on after it. The reference sets a flag
the write never clears, so its drawing stops for good and a full refresh after a font write loops forever when a draw
pass had stopped mid-screen (finding F255, amended 2026-10-26 as declared in D6). Brightness, inversion and the
background gray level are written when they change, and the debug values of the signal and clock debug modes are kept.

The draw's transfer buffer holds 256 bytes, the length the reference's encoding can reach past its 250-byte buffer
(F257). At the last character of a PAL screen the reference compares bytes past both buffers to choose a run (F256).
The driver counts that character as changed, which gives the oracle build's transfers. The unit is SPARK for the
encoder's buffer and screen indices and the time and debug arithmetic, which the proof shows free of overflow and
out-of-range access.

The MAX7456 oracle includes the reference driver with the SPI, pin, clock, LED and delay calls stubbed over a
simulated chip, one case per process. It draws the chip (present or not, its variant, the reads its reset and its
character memory write take), the bus (configured or not, the pin free or not, the kernel clock, DMA or polled), the
clock setting, the video system, the offsets and the debug mode. A chip that is found then runs 50 calls in a random
order with scripted video sense, stalls, busy answers, DMA completions and clocks. A scripted case draws the
256-byte transfer. Every SPI, pin, LED and delay call, every answer, and the hashes of the layer and the shadow
after each call replay exactly in the 301 cases, 229 of them past detection. Of 53 tampered paths, 52 fail the
vectors. The one that doubles the video debounce is equivalent (F258): the driver stamps the first sighting of a new
standard at a signal check and sees it again only at the next check, more than a second later, when any debounce
under a second has passed.

## D323. MAX7456 display port (2026-10-18)

`Adaflight.MAX7456.Display_Port` is the display layer over the MAX7456 driver (D322), a generic child that shares
the driver's instance. Initialization runs the driver's. Without a select pin, a bus or a free pin there is no port.
A port whose chip did not answer is set up and cleared but keeps 0 rows and 0 columns. A chip that answered gives
the rows of NTSC, of PAL for PAL, HD and any other system, or the driver's rows for an automatic one, and 30
columns, each with the profile's adjustment in a byte. A clear sets the profile's inversion and brightness, clears
the foreground layer, marks the port cleared and moves the cursor row to -1. A grab clears the chip without marking
the port and counts, a release counts down and a full release resets the count. Drawing, the screen size, writes,
the transfer and sync flags, layers and the background go to the driver, an empty text writes nothing, and the free
transmit space is 65535. The heartbeat runs the driver's stall and signal checks without forcing, and a redraw
refreshes the whole screen while disarmed. A font character takes the first 54 of its 64 bytes at the low byte of
its address. A readiness check of a chip that did not answer fails without rescan. With rescan it initializes the
chip, sets the rows and columns as the initialization does, through one helper, and redraws, where the reference
leaves them at 0 (finding F259, amended 2026-10-25 as declared in D6). The unit is SPARK for the port's counts and
dimensions.

The MAX7456 display port oracle includes the reference display port, the MAX7456 driver and the display layer over
the simulated chip of the MAX7456 oracle, one case per process. It draws the chip, the bus, the MAX7456 settings,
the video profile, the display port profile and the debug mode, then runs 50 of the display layer's calls in a
random order with scripted video sense, stalls, busy answers, DMA completions, clocks, arming and a chip that may
power up after initialization. Every SPI, pin, LED and delay call, every answer, the port's dimensions, grab count,
cleared flag and cursor row and the driver's state after each call replay exactly in the 300 cases, 258 of them with
a port, 41 with a chip found by a later rescan. All 21 tampered paths fail the vectors, two of them by stopping the
check: a port reported for a chip without a select pin leaves the check without the state to compare, and a redraw
while armed instead of disarmed runs into the endless refresh of F255.

## D324. SPI gyro layer (2026-10-18)

`Adaflight.MPU_Gyro` is the layer the SPI gyro chip drivers share. It is generic over the gyro's SPI device and the
number of chip probes the build includes: the select pin before, during and after detection, the bus instance, the
clock divisor, the probes in the reference's order, the device's registration, the millisecond clock, a delay, the
data ready interrupt, the cycle counter, transfers started with or without a completion call and the wait for them,
the receive buffer they fill, whether the bus has DMA, and register reads within a call. Detection waits 35 ms and
needs a bus type, a select pin and a bus instance. It prepares the select pin with the device's resource index,
waits until 100 ms after start, sets a 1 MHz clock and asks each chip in turn. The first that answers is registered,
and when none does the select pin goes back to an input with its pull-up. Without I2C gyro support the layer probes
the SPI bus whatever bus type the configuration names.

Initialization names the accelerometer, temperature and gyro data registers of the MPU family and arms the data
ready interrupt when the board has the pin. Each interrupt takes the cycle count, moves the sync time to the last
interrupt plus the longest DMA read when the interval was short or no short interval is set, keeps the count as the
last interrupt time, starts the DMA read in DMA mode and counts. A completed DMA read keeps its duration since the
interrupt when it is the longest and marks the data ready. The scheduler's gyro lock reads those times and counts.
The first gyro read sets the longest DMA read to 5 cycles and picks the mode: DMA when more than 1000 interrupts
came and the bus has DMA, reading 15 bytes from the accelerometer register, interrupt driven without DMA, or no
interrupt otherwise. Reads in the interrupt and polled modes send the register with the read bit, wait and take
three big-endian words. Reads in DMA mode take them from the last DMA read, the gyro with the temperature, scaled in
single precision in two bounded steps and cut toward zero. The hardware filter setting is 7 for the experimental
filter at up to 8 kHz on a gyro other than the MPU6050 and MPU6000, and 0 otherwise (D328). The unit is SPARK for
the word decoding, the buffer indices and the cycle and temperature arithmetic.

The MPU gyro oracle includes the reference layer with the bus, pin, interrupt, clock and delay calls and three chip
probes stubbed over a simulated device, one case per process. It draws the device configuration, the bus, the probe
answers, the startup clock, DMA, the interrupt pin, the short interval, the filter settings and the temperature
scale, then runs 60 interrupts, bursts of interrupts, DMA completions, reads, filter queries, new samples and
consumer clears in a random order, half the cases after a burst of more than 1000 interrupts. Every bus, pin and
delay call, answer, mode, count and time, clock after detection, reading and temperature of the 300 cases replays
exactly, 192 of them past detection. All 38 tampered paths fail the vectors, three of them by stopping the check on
a range: a gyro register past the DMA read and two sign tests that let a reading pass 32767. On the first pass a
shortened startup wait passed, since no vector showed the clock, and led to the clock check after detection.

## D325. MPU6000 gyro driver (2026-10-18)

`Adaflight.MPU_Gyro.MPU6000` drives the MPU6000 gyro and accelerometer over the SPI gyro layer (D324), a generic
child that adds the chip's register writes and reads, a microsecond delay, the clock's microseconds to cycles and
the failure call. Its detection is the layer's chip probe. It resets the device and then its signal paths, waiting
100 ms after each, reads the identity, waits a microsecond for the select pin, and accepts identity 0x68 with one of
the twelve product revisions the reference lists. A gyro of that sensor gets the 2000 degrees per second scale and a
short interrupt interval of 82 microseconds in cycles. Initialization runs the layer's, then selects the gyro clock,
disables the I2C interface, enables all axes, sets the sample rate divider, the 2000 degrees per second and 16 g
ranges, any-read interrupt clear and the data ready interrupt, 15 microseconds apart, with the temperature scale of
1/340 and zero of 36.53. The filter register takes the layer's setting, the clock goes to 20 MHz and one gyro read
follows, which calls the failure when the low bytes of its first two axes both read 0xFF. The accelerometer's one g
is 2048. The unit is SPARK for the sequence and the failure test.

The MPU6000 oracle includes the reference driver and the gyro layer over a simulated MPU6000, one case per process.
It draws the identity, the product revision, the bus, the startup clock, DMA, the interrupt pin, the sample rate
divider, the filter settings, the readings of the initial read and its acknowledgement, then runs the detection, the
gyro and accelerometer detection and initialization, stopping at a failure. Every bus, pin, delay and failure call,
detection result, scale, interval, reading and setting of the 300 cases replays exactly, 198 of them past detection,
23 with a failure and 17 with one failure byte. All 28 tampered paths fail the vectors. On the first pass two
passed, since the oracle set the failure bytes of both axes together and ran the gyro detection only on a found
chip, and led to cases with one failure byte and to the detection of an undetected chip.

## D326. ICM426xx gyro driver (2026-10-18)

`Adaflight.MPU_Gyro.ICM426xx` drives the ICM-42605, ICM-42622-P, ICM-42686-P, ICM-42688-P, IIM-42652 and IIM-42653
over the SPI gyro layer (D324), a generic child that adds register writes and reads, the start of the clock input
and whether the build has one. Its detection is the layer's chip probe. It waits 1 ms, selects register bank 0,
resets the chip, waits 1 ms, clears the power management and reads the identity up to 21 times, 1 ms apart, until
one of the six answers. On a build with a clock input, a found ICM-42688-P starts the clock and, when it runs, sets
pin 9 to the clock input in bank 1 and enables the external clock in bank 0. The IIM-42653 gets the 4000 degrees per
second scale and a one g of 1024, the others 2000 degrees per second and 2048, all with the temperature scale of
1/132.48 and zero of 25.

Initialization sets a 24 MHz clock, runs the layer's and names the chip's data registers, the DMA read starting at
the temperature. With the sensors off it writes the gyro anti-alias filter from the configuration's filter setting
and the accelerometer's for 258 Hz, from the ICM-42605's table or the others', then the low latency interface
filters, the pulsed push-pull data ready interrupt cleared on a status read, the interrupt pulse of 8 microseconds
without deassert and the async reset bit cleared, and disables the AFSR. The sensors go back on in low noise mode,
and the gyro and accelerometer configurations take the range selection, 1 for the ICM-42686-P, and the output data
rate from the base 2 logarithm of the sample rate divider when the gyro rate is set and the logarithm is below 4, or
1 kHz with the rate reset otherwise, 15 ms apart. The unit is SPARK for the tables and the register values.

The ICM426xx oracle includes the reference driver and the gyro layer over a simulated chip with register banks, one
case per process, built with the clock input. It draws the identity, the reads before the chip answers, the bus, the
clock input pin and whether it starts, the startup clock, DMA, the interrupt pin, the filter setting, the sample
rate divider, the gyro rate and the bank registers the driver reads, runs the detection, the gyro and accelerometer
detection and initialization, then 30 interrupts, bursts, DMA completions, reads and new samples. Every bus, pin,
clock and delay call, result, setting and reading of the 300 cases replays exactly, 239 of them past detection over
all six chips. All 39 tampered paths fail the vectors.

## D327. MPU6500 gyro driver (2026-10-18)

`Adaflight.MPU_Gyro.MPU6500` drives the MPU6500, MPU9250, MPU9255, ICM-20601, ICM-20602 and
ICM-20608-G over the SPI gyro layer (D324), a generic child that adds register writes and reads, the
bus register write and a microsecond delay. Its detection is the layer's chip probe. It reads the
identity once and also names the ICM-42605, ICM-42686-P and ICM-42688-P, so on a build that probes
it first those chips skip the ICM426xx detection (D326) and go straight to that driver's
initialization (F260). A gyro of the family gets the 2000 degrees per second scale, or 4000 for an
ICM-20601 under the high range option. Initialization runs the layer's, then resets the chip, its
signal paths and the power management, selects the clock and sets the gyro and accelerometer ranges,
the layer's filter setting, the sample rate divider, any-read interrupt clear and the data ready
interrupt, 15 to 100 ms apart, with the chip's temperature conversion: 333.87 counts per degree and
21 degrees at zero for the MPU-6500 and MPU-9250, 326.8 and 25 for the ICM-2060x family, the
constants rounded as the C compiler rounds them. The reference gives every chip the MPU6000's 340
and 36.53 (finding F261, D6). The ranges are 2000 degrees per second and 16 g. The ICM-20601 takes
its own range codes, with 4000 degrees per second under the high range option. It then disables the
I2C interface, waits 100 ms, sets a 20 MHz clock and waits a microsecond. The accelerometer's one g
is 2048. The bypass bit for an MPU9250 magnetometer is left out, since no board configuration
enables that magnetometer. The unit is SPARK for the sequence and the range selection.

The MPU6500 oracle includes the reference driver and the gyro layer over a simulated chip, one case per process. It
draws the identity from the nine the driver names or any byte, the high range option, the bus, the startup clock,
DMA, the interrupt pin, the sample rate divider and the filter settings, then runs the detection, the gyro and
accelerometer detection and initialization. Every bus, pin, register and delay call, detection result, scale and
setting of the 300 cases replays exactly, 170 of them initialized over all five sensor kinds and 15 of those with
the high range scale. All 43 tampered paths fail the vectors. The one that writes 0 for the filter setting passed
until the layer knew the experimental filter (D328).

## D328. Experimental gyro hardware filter (2026-10-18)

Every reference build compiles the experimental gyro hardware filter, the fourth filter setting that the settings
table and the configuration fix already know. The SPI gyro layer (D324) gives the filter register 7 under that
setting at up to 8 kHz, unless the gyro hardware the detection named is the MPU6050 or MPU6000, and 0 for every
other setting. The layer's state contains that hardware for the integration to set. The ICM426xx driver (D326) takes
the 1962 Hz anti-alias entry under the experimental setting on every chip but the ICM-42605, which keeps 258 Hz. The
gyro oracles compile against the unit test platform header, which leaves the setting out, so the layer had given 0
and the ICM426xx driver 258 Hz for it.

The gyro oracles now build with the experimental filter and draw all four settings, and the MPU6000 and MPU6500
oracles print the hardware the gyro detection names, which the vectors hand to the layer. The layer's filter queries
also draw the gyro hardware, the MPU6050 or MPU6000 in 40 percent of them. Every vector replays exactly. Of the
initializations under the experimental setting, 36 of 45 on the MPU6500 write 7, the rest above 8 kHz, all 49 on the
MPU6000 write 0, and the 53 on ICM426xx chips other than the ICM-42605 write the 1962 Hz entry. All 11 tampered
paths fail the vectors, among them the MPU6500 driver's write of 0 for the filter setting (D327).

## D329. ICM20689 gyro driver (2026-10-18)

`Adaflight.MPU_Gyro.ICM20689` drives the ICM-20601, ICM-20602, ICM-20608-G and ICM-20689 over the
SPI gyro layer (D324), a generic child that adds register writes and reads and a microsecond delay.
Its detection is the layer's chip probe. It resets the chip, waits 100 ms and reads the identity,
and for one of the four disables the I2C interface, resets the accelerometer and temperature signal
paths and waits 100 ms. A gyro of the family gets the 2000 degrees per second scale and an
accelerometer with a one g of 2048. The reference's accelerometer detection accepts the ICM-20602
and ICM-20689 only, so an ICM-20601 or ICM-20608-G flies with its gyro and no accelerometer (F262,
D6). Initialization sets an 8 MHz clock before the layer's, then selects the clock, waits 120
microseconds and sets the 2000 degrees per second and 16 g ranges, the layer's filter setting, the
sample rate divider, any-read interrupt clear and the data ready interrupt, with the temperature
scale of 0.003 and zero of 25. The reference's detection probes this driver before the MPU6500
driver (D327), and its gyro detection tries the MPU6500 driver first, so on a build with both the
ICM-20601, ICM-20602 and ICM-20608-G take this detection and the MPU6500 initialization. The unit is
SPARK for the sequence.

The ICM20689 oracle includes the reference driver and the gyro layer over a simulated chip, one case per process,
built with the experimental filter (D328). It draws the identity from the four the driver names or any byte, the
bus, the startup clock, DMA, the interrupt pin, the sample rate divider and the filter settings, then runs the
detection, the gyro and accelerometer detection and initialization. Every bus, pin, register and delay call,
detection result, scale and setting of the 300 cases replays exactly, 241 of them initialized over all four chips
and 44 of those with the experimental filter's 7. All 31 tampered paths fail the vectors.

## D330. M25P16 flash driver (2026-10-18)

`Adaflight.Flash_Device` is the SPI flash device the chip drivers share: the chip's geometry, the address the next
program writes, whether the chip takes 4-byte addresses, whether a write could have left it busy, whether a program
reports its end, the bytes of the last program and the chip's clocks for writes and reads. A driver hands the bus a
list of up to six segments. Each sends command bytes, a caller's buffer or nothing for a read, receives or not,
releases the chip select or not, and names the callback the bus runs after it. A segment of length 0 ends the list.
The callbacks belong to the unit. A status read answers busy while a write is in progress, which has the bus repeat
it, and otherwise clears the busy flag. A write enable sets the flag. The end of a program moves the write address
past its bytes and asks for their report when the program has one.

`Adaflight.Flash_Device.M25P16` drives the 40 SPI NOR chips of the M25P16 family table, 2 to 64 MB parts with
256-byte pages, a generic child over the bus's transfers, segment lists sent or read, wait, DMA flag and busy query
and clock divisor. Identification looks the JEDEC ID up for the clocks, the sectors and the pages per sector and
marks the chip as possibly busy. An unknown ID clears the geometry. Configuration does nothing on a memory-mapped
system and otherwise sets the read clock and, past 16 MB, the 4-byte addresses. The ready check answers not ready
while a DMA transfer runs, ready when no write could have left the chip busy, and otherwise reads the status. Sector
and chip erases start with the status read, then the write enable and the erase, and wait for the bus. The sector
erase also waits before it starts. A program waits for the bus, then sends the status read only when the chip could
be busy, the write enable, the program command and one or two buffers, the last of which releases the select and
ends the program. Any other buffer count sends nothing and returns 0, after the written bytes take the first
buffer's length. A program without a report waits for the bus. A read sets the read clock, reads with the status
read only when the chip could be busy, waits and restores the write clock. The program's finish step does nothing
and is left out. The unit is SPARK for the command bytes, the table and the segment lists.

The M25P16 oracle includes the reference driver over a simulated chip, one case per process. Its bus runs segment
lists the way the reference's SPI interrupt handler does. The chip keeps a write enable latch, stays busy for a
drawn number of status reads after a program or erase, ignores commands while busy, wraps a program within its page
and takes 4-byte addresses after its command. It draws the JEDEC ID, from the table in 85 percent of cases, the
memory-mapped flag, DMA with the bus's busy answers, and 4 to 14 operations, half of them near the last write. Every
transfer, segment, callback, result and device field of the 300 cases replays exactly. Of them 254 identify a chip,
35 of them past 16 MB, 1461 status reads repeat on a busy chip, 280 programs report their end, and 123 of 250 reads
return erased or programmed bytes. Of 42 tampered paths, 41 fail the vectors, one by stopping the checker and one by
a status read that never answers. The one that also reads the write enable bit as busy passes and is equivalent:
every write enable is followed by its write in the same list, which clears the latch, so no status read sees it set.

## D331. Flash layer (2026-10-18)

`Adaflight.Flash_Device.Layer` is the flash layer over an SPI flash chip driver, a generic child over the select
pin, the bus, the clock divisor, a delay, the identification read and the driver's procedures. Preinitialization
leaves the select pin an input with its pull-up. Initialization clears the partition table and, when the
configuration names a bus, checks for a select pin, that it is free and that the bus attaches, prepares the pin,
sets a 5 MHz clock, waits 50 ms and reads four identification bytes, the first three of which the driver looks up. A
known chip keeps its JEDEC ID and is configured. An unknown one returns the select pin to its pull-up. The
partitions then give the flash filesystem the chip's sectors, ending before a bad block management partition when
there is one. Setting a partition updates the entry of its type, or takes the next free entry while fewer than five
are in use, so the table of six entries holds at most five. The type stays the raw byte the caller gave, and the
sectors are cut to 16 bits.

The layer hands the ready check, the wait, the programs and the reads to the driver. A sector erase clears the
program report and waits for the chip, a chip erase clears it and returns at once, and a read clears it. A continued
program trims its buffers to the room left in the page, the first alone when it fills the page. The geometry is the
chip's, or empty without a chip. A lookup by type finds the first entry of the type, an empty entry being of the
unknown type, and a lookup by index finds the entries added. Type names are padded to nine characters. The second
reading of the identification for chips that answer a dummy byte first, the ready check that fails after a deadline
and the flush serve drivers this build leaves out: the M25P16 sets no deadline and has no flush. The unit is SPARK
for the partition table and the page arithmetic.

The flash layer oracle includes the reference layer and M25P16 driver over the chip and bus of D330, one case per
process. It draws the select pin and bus, whether the pin is free and the bus attaches, the identification bytes,
from the table in 75 percent of cases and with a leading dummy byte in 10 percent, DMA with the bus's busy answers
and the busy reads, then initializes the layer and runs 4 to 14 drawn calls, half of them near the last write, with
bursts of one to six partition settings and, in a quarter of the continued programs, a first buffer that fills the
page exactly. Every pin, bus, segment and delay call, result, geometry, partition and name of the 300 cases replays
exactly, 183 of them with a chip, while 28 bursts fill the table and 23 programs fill the page exactly with two
buffers. All 28 tampered paths fail the vectors, two by stopping the checker. On the first pass the one that keeps
both buffers when the first fills the page exactly passed, since no case filled it exactly, and led to those
programs.

## D332. Gyro start (2026-10-18)

`Adaflight.Gyro_Start` is a gyro sensor's start after its detection. The sample rates and the rate code follow the
detected sensor: 3200 Hz with the accelerometer at 800 Hz for the BMI160 and the BMI270, which runs at 6400 Hz under
the experimental hardware filter (D328), 6400 and 800 Hz for the BMI423, 9000 and 1125 Hz for the ICM-20649, 6664
and 833 Hz for the LSM6DSO, 6400 and 1600 Hz for the ICM-45686, ICM-45605 and ICM-56686, and 8000 and 1000 Hz for
every other sensor. The divider drops are 0 for every sensor, since the drivers no longer use the gyro's sample rate
divider. The overflow protection follows the gyro hardware. The ICM-20601, ICM-20602, ICM-20608-G, ICM-20649,
ICM-20689 and ICM-40609-D lack it, as does hardware past the list. The data ready check answers the flag and clears
it. The settings the start copies into the driver, the configuration's hardware filter and high range and the
device's interrupt pin and alignment, are left to the integration. The unit is SPARK for the tables.

The gyro start oracle includes the reference gyro initialization, built with the experimental filter and the LSM6DSO
driver, since a board detects that sensor only with its driver, and calls the sensor start with a stub
initialization, one case per process. It draws the detection result, the gyro hardware except the simulator's
virtual gyro, the configuration's hardware filter setting, out of range in one case of ten, the high range setting,
the interrupt pin, the alignment, the divider drops before the start and the data ready flag. Every rate, rate code,
divider drop, protection, copied setting and data ready answer of the 300 cases replays exactly, with all five rates
drawn. All 25 tampered paths fail the vectors, the two in the data ready check by its postcondition.

## D333. QMC5883 compass driver (2026-10-18)

`Adaflight.QMC5883` drives the QMC5883L and QMC5883P compasses, generic over the bus of the barometer drivers.
Detection of the L sets the address 0x0D when none was set, resets the chip, waits 20 ms and reads the identity
0xFF, then refuses a chip whose mode after the reset is not standby, while a failed read of the mode passes.
Detection of the P sets the address 0x2C when none was set and reads the identity 0x80. Initialization registers the
device and writes the L's reset and its continuous 200 Hz mode at 8 gauss with 512 times oversampling, or the P's
sign setting, its continuous 100 Hz mode at 8 gauss and eightfold oversampling, stopping at the first refused write,
and gives the output data rate when every write went through.

Each read first collects the bytes of the transfer the previous call started. While it waits for data it starts the
status read, starts the six data bytes once the status reports data ready, or, on the L, clears an overrun by reading
the unlock register. The call after a data read hands over the three little-endian axes. The P rejects all-zero and
all-one readings and the eleventh repeat in a row of one reading, and starts again from the status. The reference
keeps the read state in static variables of its read function, shared by every QMC5883 device. This unit keeps the
state per device, which behaves the same with one compass. The unit is SPARK for the read state and the reading
checks.

The QMC5883 oracle includes the reference driver over a simulated chip whose answers each case draws and prints before
use, one case per process. It draws the variant, the bus type and a preset address, the identity and mode answers, the
write and read acknowledgements, then 20 to 60 reads with status, data and start answers, among them all-zero, all-one
and repeated readings. Half of the cases instead read 60 to 120 times, with one reading throughout or with a new reading
every 12 to 25 reads. Every bus call, detection, initialization and reading of the 300 cases replays exactly. In them
207 compasses initialize and 3070 readings arrive. The P rejects 397 all-zero, 245 all-one and 19 repeated readings, and
the L clears 530 overruns. Of 39 tampered paths, 38 fail the vectors, one by stopping the checker. The one that drops
the store of the unlock byte passes and is equivalent, since the next data read overwrites that byte before any use. On
the first pass the one that keeps the repeat count across a changed reading passed, since the cases with changing
readings repeated too few times to reach the limit, and led to the cases with a new reading every 12 to 25 reads.

## D334. Gyro detection (2026-10-18)

`Adaflight.Gyro_Detect` names the gyro hardware of the sensor the chip detection found. The build's drivers try the
sensor in the order MPU6050, L3GD20, MPU6000, MPU6500, MPU9250, ICM20649, ICM20689, ICM426xx, ICM456xx, ICM56686,
BMI160, BMI270, BMI423, LSM6DSO, LSM6DSV, LSM6DSK320X and ICM40609D, then the virtual gyro. The first driver that
accepts the sensor names the hardware. The MPU6500 driver built for SPI accepts the MPU6500, MPU9250, ICM-20601,
ICM-20602 and ICM-20608-G and names each of them. Built only for I2C it accepts only the MPU6500 on I2C, so a build with
both MPU6500 drivers names no MPU6500 hardware for that chip. The ICM20689 driver accepts the ICM-20601, ICM-20602,
ICM-20608-G and ICM-20689 and names all four ICM20689. The first three reach it only in builds without the MPU6500
driver for SPI. The LSM6DSV driver accepts each of its two variants only when the build names it. The L3GD20 driver and
the virtual gyro accept any sensor. A build with the virtual gyro skips the chip detection, and a failed chip detection
keeps the hardware the device had. The unit is SPARK for the result over every build, where the vectors cover 39. The
result is a hardware value other than the default, and a build with the L3GD20 or the virtual gyro always finds one.

The gyro detection oracle compiles the reference's gyro sensor detection with the drivers' own detect functions once per
driver set. Its 39 sets are each driver alone, no driver, the pairs whose drivers accept the same sensors, every driver
with and without the L3GD20, two sets with the virtual gyro, and five mixed sets, four of them as board configurations
build them. Each set runs every sensor value from 0 to 31 with a chip found and not found, from a starting hardware
value. Every result, hardware, presence flag and chip detection call of the 2496 detections replays exactly. All 35
tampered paths fail the vectors, three by stopping the checker on a postcondition.

## D335. Accelerometer detection (2026-10-18)

`Adaflight.Acc_Detect` names the accelerometer hardware of the sensor the gyro's chip detection found. The build's
drivers try the sensor in the order MPU6050, MPU6000, MPU9250, MPU6500, ICM20649, ICM20689, ICM426xx, ICM456xx,
ICM56686, BMI160, BMI270, BMI423, LSM6DSO, LSM6DSV, ICM40609D and LSM6DSK320X, then the virtual accelerometer. This
order puts the MPU9250 before the MPU6500 and the ICM40609D before the LSM6DSK320X, unlike the gyro's. The scan starts
at the driver of the configured hardware, or at the first driver when the configuration names the default, and the first
driver that accepts the sensor names the hardware. A configured hardware whose driver the build lacks, or one that finds
nothing, starts the scan again from the first driver. The configured value none finds nothing. The MPU6500 driver built
for SPI accepts the MPU6500, MPU9250, ICM-20601, ICM-20602 and ICM-20608-G, and built only for I2C it accepts only the
MPU6500 on I2C. The ICM20689 driver accepts only the ICM-20602 and ICM-20689, where its gyro detection also takes the
ICM-20601 and ICM-20608-G. Configuring the ICM20689 on a build with both drivers gives an ICM-20602 the ICM20689
hardware, where the default gives it the ICM-20602. A failed detection keeps the accelerometer the device had. The unit
is SPARK for the result over every build and configured value. A found accelerometer is a hardware value other than the
default and none, and the configured value none never finds one.

The accelerometer detection oracle compiles the reference's accelerometer detection with the drivers' own detect
functions once per driver set. Its 39 sets are each driver alone, no driver, the pairs whose drivers accept the same
sensors or run in another order than the gyro's, every driver, five sets with the virtual accelerometer, two of them
with one LSM6DSV variant, and five mixed sets, four of them as board configurations build them. Each set runs every
sensor value from 0 to 31 against every configured value from 0 to 29 and 255, from a starting detected value. Every
result, detected accelerometer and presence flag of the 38688 detections replays exactly. All 34 tampered paths fail the
vectors, three by stopping the checker on a postcondition. On the first pass the one that lets the configured LSM6DSV32X
start the scan in a build without that driver passed, since no build paired the virtual accelerometer with one LSM6DSV
variant, and led to the two such builds.

## D336. Barometer detection (2026-10-18)

`Adaflight.Baro_Detect` lists the barometer drivers in the detection's order BMP085, MS5611, LPS, DPS310, BMP388,
BMP280, QMP6988, 2SMPB-02B, LPS22DF and BMP5xx, then the virtual barometer. It names the hardware of a found chip. The
DPS310 driver's SPL07-003 is the SPA06-003 when the build names that option. A BMP5xx with the identity 0x50 or 0x51 is
the BMP580 or BMP581, and any other identity leaves the hardware at none. The generic child `Adaflight.Baro_Detect.Scan`
detects over the bus. Without the virtual barometer it first sets the configured bus type's instance, then the I2C
address or the SPI select pin, and a bus type the build lacks or an instance that refuses ends the detection. The scan
starts at the configured hardware's driver, or at the first driver for the default. A hardware value keeps its place in
the order when the build lacks its driver, so the scan goes on from there. The first built driver that finds its chip
names the hardware and ends the scan, an unknown BMP5xx included. The configured value none and values past the list
find nothing, and unlike the accelerometer detection a configured hardware that finds nothing does not start again from
the first driver. A failed detection keeps the barometer the device had. The BMP085 detection receives the configured
XCLR and EOC pins, the BMP388 and BMP5xx detections the EOC pin. The unit is SPARK for the result and the kept value
over every build and configuration.

The barometer detection oracle includes the reference barometer with every driver's detection stubbed, built once for
each combination of I2C and SPI support and twice with the virtual barometer. Each case draws the drivers the build has,
the SPA06-003 option, the configured hardware and bus, the bus instance answers and each driver's answer. A driver the
build lacks answers false without a call, as its absent detection code would. A quarter of the virtual builds' cases
find an unknown BMP5xx chip before any other driver. Every bus and driver call, result, detected barometer and I2C
address of the 600 cases replays exactly. In them 219 barometers are found, every hardware value of the list among them,
and 26 scans stop at an unknown BMP5xx in a build with the virtual barometer. All 31 tampered paths fail the vectors. On
the first pass the one that lets the scan go on past an unknown BMP5xx passed, since no case reached one in a build with
the virtual barometer, and led to those cases.

## D337. Compass detection (2026-10-18)

`Adaflight.Compass_Detect` lists the compass drivers in the detection's order HMC5883, LIS2MDL, LIS3MDL, AK9916, AK8975,
AK8963, QMC5883L, QMC5883P, IST8310, MMC560X and BMM350, then the MPU925x passthrough and the simulator's virtual
compass. Every build with a compass has every driver, so the build names only its bus support, the MPU slave bus that a
SPI MPU6500 or MPU9250 gyro driver brings, DroneCAN, the simulator and the board's compass alignment. The generic child
`Adaflight.Compass_Detect.Scan` detects over the bus. A configured DroneCAN compass is found only through the DroneCAN
stack. Otherwise the interrupt pin comes first, then the configured bus, which is the I2C instance and address, the SPI
instance and select pin, or the MPU slave bus behind an MPU9250 gyro. A bus type the build lacks, an instance that
refuses, or an MPU slave bus without an MPU9250 ends the detection. The scan starts at the configured hardware's driver,
or at the first for the default, and sets the configured address again before each driver while the bus is I2C. Behind
an MPU9250 gyro the AK8963 case moves the bus onto the MPU slave bus for its probe and puts the configured bus back when
the probe fails, so the drivers after it probe on the configured bus. The reference leaves the shared bus retyped, so
its later drivers probe on the MPU slave bus with the address the last failing driver left (finding F263, amended
2026-10-26 as declared in D6). The MPU925x passthrough is tried only when configured, and its failure ends the
detection. The simulator's virtual compass is found unless the configuration is none, and it reports the default
hardware. A failed detection keeps the compass the device had. The unit is SPARK for the result and the kept value over
every build and configuration.

The compass detection oracle includes the reference compass with every driver's detection stubbed, built for both buses
with and without the MPU slave bus, for SPI only, for I2C only, with DroneCAN and a board alignment, and twice for the
simulator, once with a board alignment. Each case draws the configured hardware and bus, the bus instance answers, the
gyro's detected sensor, each driver's answer and the address a failing driver leaves behind. Every bus and driver call
with the bus type and address each driver sees, result, detected compass, alignment and interrupt pin of the 660 cases
replays exactly. In them 287 compasses are found, every hardware value among them. All 33 tampered paths fail the
vectors. On the first pass the one that gives the simulator the board's alignment passed, since the simulator build had
none, and led to a simulator build with one.

## D338. Rangefinder detection (2026-10-18)

`Adaflight.Rangefinder_Detect` maps the configured rangefinder hardware to its driver, which is the HC-SR04, the TF
family (TFmini, TF02, TF-Nova), the MT family (MTF01, MTF02 and their P variants), the Nooploop family of six models, or
the UPT-1. Every build with a rangefinder has every driver. The generic child `Adaflight.Rangefinder_Detect.Probe` tries
the configured hardware's driver alone, with no fallthrough to another driver. A found rangefinder reschedules the
rangefinder task and names the configured hardware. The HC-SR04 runs at 70 ms and the UPT-1 at its 20 ms frame period,
the others at the delay their driver reports. The UPT-1 driver reports 10 ms, which the detection does not use. Hardware
none and values past the list find nothing. A failure keeps the detected rangefinder and clears its presence flag, which
the caller applies from the result. The unit is SPARK for the found hardware, which is always the configured one.

The rangefinder detection oracle includes the reference rangefinder with every driver built and its detection stubbed.
Each case draws the configured hardware, each driver's answer and the delay a found driver reports. Every driver call,
task reschedule, result, detected rangefinder and presence flag of the 300 cases replays exactly, 158 of them found,
every hardware value among them. All 14 tampered paths fail the vectors.

## D339. Optical flow detection (2026-10-18)

`Adaflight.Optical_Flow_Detect` lists the optical flow drivers, the MT and the UPT-1, which come with the rangefinder
drivers of the same modules. The generic child `Adaflight.Optical_Flow_Detect.Probe` tries the configured hardware's
driver alone, and a build without the rangefinder drivers finds no optical flow sensor. The MT driver takes the
rangefinder's configured hardware, which names the module. A found sensor reschedules the optical flow task at the delay
its driver reports and names the configured hardware. Hardware none and other values find nothing. A failure keeps the
detected sensor and clears its presence flag, which the caller applies from the result. The unit is SPARK for the found
hardware, which is always the configured one and needs the rangefinder drivers.

The optical flow detection oracle includes the reference optical flow with both drivers' detection stubbed, built with
and without the rangefinder drivers. Each case draws the configured optical flow and rangefinder hardware, each driver's
answer and the delay a found driver reports. Every driver call, task reschedule, result, detected sensor and presence
flag of the 300 cases replays exactly, 83 of them found. All 10 tampered paths fail the vectors.

## D340. HMC5883L compass driver (2026-10-18)

`Adaflight.HMC5883` drives the HMC5883L compass, generic over the bus of the barometer and QMC5883 drivers. Detection on
SPI registers the device and prepares its bus at no more than 10 MHz. On I2C an unset address takes the chip's 0x1E and
a preset one stays. Detection then reads the identity register and needs 0x48. Initialization writes eight-sample
averaging at 75 Hz in normal measurement, the 1.3 gauss gain and continuous conversion, whatever the writes answer,
waits 100 ms, arms the data ready interrupt when the board has its pin, and gives the 75 Hz output data rate. A read
alternates between starting the six data bytes and handing over the axes they brought, X, Z and Y, each high byte first.
A start the bus refuses is tried again at the next read. The reference keeps the read state in static variables of its
read function, shared by every HMC5883L device. This unit keeps the state per device, which behaves the same with one
compass. The unit is SPARK for the read state and the axis conversions.

The HMC5883L oracle includes the reference driver over a simulated chip whose answers each case draws and prints before
use, one case per process. It draws the bus type and a preset address, the identity and its read acknowledgement, the
write acknowledgements and the interrupt pin, then 20 to 60 reads with start answers and data. Every bus call,
detection, initialization and reading of the 300 cases replays exactly. In them 219 compasses initialize and 4026
readings arrive. All 22 tampered paths fail the vectors.

## D341. IST8310 compass driver (2026-10-18)

`Adaflight.IST8310` drives the IST8310 compass over the same bus as the other compass drivers.
Detection gives an unset I2C address the chip's 0x0E and reads the identity 0x10. Initialization
registers the device and writes 16-sample averaging, the normal pulse duration and a single
measurement, each only after the one before went through, waits 6 ms after each of the first two
whether or not they went through, and gives the 100 Hz output data rate. A read first collects the
bytes of the transfer the previous call started. While it waits for data it polls the status
register, starts the six data bytes once the status reports data ready, and after 15 polls without
data ready moves on to trigger a new measurement. The call after a data read hands over the axes, X
and Z times 3 and Y negated and times 3, each kept to its low 16 bits like the reference's 16-bit
store, and triggers the next single measurement. A read that hands over the axes reports a reading
whether or not its trigger goes out, and a trigger alone reports none. The reference reports a
reading at a trigger that goes through, so after 15 polls without data ready it reports the axes it
handed over last as new, every 17 calls when every status read starts (finding F264, D6). A trigger
the bus refuses is tried again at the next read. The reference keeps the read state in static
variables of its read function, shared by every IST8310 device. This unit keeps the state per
device, which behaves the same with one compass. The unit is SPARK for the read state, the poll
limit and the 16-bit axis conversion.

The IST8310 oracle includes the reference driver over a simulated chip whose answers each case draws and prints before
use, one case per process. It draws the bus type and a preset address, the identity and its read acknowledgement and the
write acknowledgements, then 40 to 120 reads with start, trigger, status and data answers, a third of the cases never
reporting data ready. Every bus call, detection, initialization, reading and axes buffer of the 300 cases replays
exactly. In them 234 compasses initialize and 3545 readings are reported, 340 of them after no data read. All 30
tampered paths fail the vectors, among them the one that makes a trigger report no reading and the one that saturates
the scaled axes.

## D342. LIS3MDL compass driver (2026-10-18)

`Adaflight.LIS3MDL` drives the LIS3MDL compass over the same bus as the other compass drivers.
Detection gives an unset I2C address the chip's 0x1E, the HMC5883L's address too, and reads the
identity 0x3D. Initialization registers the device and writes the 4 gauss range, the temperature
sensor with ultra-high-performance X and Y at 80 Hz, the block data update, ultra-high-performance Z
and continuous conversion, whatever the writes answer, waits 100 ms and gives the 80 Hz output data
rate. A read alternates between starting the six data bytes at the X low byte and handing over the
axes they brought, each low byte first and divided by 4 with the quotient truncated toward zero. The
six-byte read starts at 0x28 with the auto-increment bit set, the sub-address's top bit on I2C and
the MS bit on SPI, which the datasheet requires for a multi-byte read. The reference reads without
it, so the chip answers its X low byte six times (F265, D6). The reference keeps the read state in
static variables of its read function, shared by every LIS3MDL device. This unit keeps the state per
device, which behaves the same with one compass. The unit is SPARK for the read state and the axis
conversion.

The LIS3MDL oracle includes the reference driver over a simulated chip whose answers each case draws
and prints before use, one case per process. It draws the bus type and a preset address, the
identity and its read acknowledgement and the write acknowledgements, then 20 to 60 reads with start
answers and data. Every bus call, detection, initialization and reading of the 300 cases replays
exactly. In them 226 compasses initialize and 4177 readings arrive. Every tampered path fails the
vectors, among them the one that reads without the auto-increment bit.

## D343. LIS2MDL compass driver (2026-10-18)

`Adaflight.LIS2MDL` drives the LIS2MDL compass over the same bus as the other compass drivers. Detection gives an unset
I2C address the chip's 0x1E and reads the identity 0x40. Initialization registers the device and writes continuous 100
Hz conversion with temperature compensation, offset cancellation and the block data update, each only after the one
before went through. It gives the 100 Hz output data rate and succeeds only when all three went through, and a failed
initialization leaves the rate at 0. A read alternates between starting the six data bytes and handing over the axes
they brought, each low byte first, with X negated to the common sensor frame and kept to its low 16 bits like the
reference's 16-bit store. The reference keeps the read state in static variables of its read function, shared by every
LIS2MDL device. This unit keeps the state per device, which behaves the same with one compass. The unit is SPARK for the
read state and the axis conversion.

The LIS2MDL oracle includes the reference driver over a simulated chip whose answers each case draws and prints before
use, one case per process. It draws the bus type and a preset address, the identity and its read acknowledgement and the
write acknowledgements, then 20 to 60 reads with start answers and data, every tenth with the X axis at -32768, whose
negation wraps back to -32768. Every bus call, detection, initialization and reading of the 300 cases replays exactly.
In them 208 compasses are found, 123 initialize and 85 fail to, and 3909 readings arrive. All 23 tampered paths fail the
vectors. On the first pass the one that saturates the negated X axis passed, since no reading had X at -32768, and led
to the readings with that axis.

## D344. AK8975 compass driver (2026-10-18)

`Adaflight.AK8975` drives the AK8975 compass over the same bus as the other compass drivers. Detection gives an unset
I2C address the chip's 0x0C and reads the identity 0x48. Initialization registers the device, powers it down, waits 20
ms, enters fuse ROM access, waits 10 ms, reads the three sensitivity values, waits 10 ms, powers down again, waits 10
ms, reads both status registers and starts a 16-bit single measurement, whatever the writes and the status reads
answer. A refused fuse ROM read fails the initialization, where the reference takes the gains from the uninitialized
stack memory the read left (F266). Each axis gain is its sensitivity value plus 128, and the output data rate is 50 Hz. A
read starts the
first status, and when it reports data ready starts the six data bytes and then the second status. It then starts the
next single measurement, retried at each read until the bus takes it, drops the data on a data error or overflow, and
otherwise hands the axes over at the next read. Each axis is its signed word times its gain divided by 256, clamped to
16 bits, then negated and kept to its low 16 bits like the reference's 16-bit store. The reference keeps the read state
in static variables of its read function, shared by every AK8975 device. This unit keeps the state per device, which
behaves the same with one compass. The unit is SPARK for the read state and the axis conversion.

The AK8975 oracle includes the reference driver over a simulated chip whose answers each case draws and prints before
use, one case per process. It draws the bus type and a preset address, the identity and its read acknowledgement, the
fuse ROM values and whether the chip answers them, from the case number so the other draws keep their places, and the
other write and status read acknowledgements, then 40 to 120 reads with start, write, status and data answers. Every bus
call, detection, initialization, gain and reading of the 300 cases replays exactly. In them 200 compasses initialize, 39
fail at a refused fuse ROM read, and 2082 readings arrive, 286 axes at -32768 and 310 at -32767. The 28 tampered paths of
the first campaign failed its vectors, one by stopping the checker, and the unchecked fuse read and an initialization
that reports success after a refused read, tampered back in, fail these.

## D345. AK9916 compass driver (2026-10-18)

`Adaflight.AK9916` drives the AK9916 compass, the magnetometer of an ICM-20948 that a GPS module's own controller may
bridge to its I2C port. Detection needs an I2C bus, gives an unset address the chip's 0x0C and reads the device identity
0x09 from the second identity register, since the first holds the company identity 0x48 that the AK8975 and AK8963
drivers accept. Initialization registers the device, resets it, waits 1 ms and sets continuous 100 Hz measurement,
checked by reading the mode back, and gives the 100 Hz output data rate. A read takes the first status, the six data
bytes and the second status in one blocking read. Without data ready it counts, and the 25th such read sets the mode
again with a read-back whose answer the reference discards. A sensor overflow drops the data. Otherwise each axis is 1.5
times its signed word, low byte first, clamped to 16 bits. The reference keeps the count in a variable shared by every
AK9916 device and resets it at initialization. This unit keeps the count per device, which behaves the same with one
compass. The unit is SPARK for the count and the axis conversion.

The AK9916 oracle includes the reference driver over a simulated chip whose answers each case draws and prints before
use, one case per process. It draws the bus type and a preset address, the identity and its read acknowledgement, the
reset write's answer, and the mode write and read-back answers, 15 percent of the read-backs with bit 4 set, then 40 to
160 reads with read answers, status, data and mode read-back answers, a quarter of the cases never reporting data ready.
Every bus call, detection, initialization and reading of the 300 cases replays exactly. In them 203 compasses are found,
118 initialize, and 10208 readings arrive. All 29 tampered paths fail the vectors. On the first pass the one that
narrows the mode mask passed, since no read-back had bit 4 set, and the one that reads the mode back after a refused
mode write passed, since the reset and mode writes shared one answer. They led to the read-backs with bit 4 set and the
separate answer for the reset write.

## D346. MMC560X compass driver (2026-10-18)

`Adaflight.MMC560X` drives the MMC560X compass over the same bus as the other compass drivers. Detection gives an unset
I2C address the chip's 0x30, waits 10 ms for the chip to power up and reads the product identity 0x10. Initialization
registers the device, resets it and waits 20 ms, sets it and waits 1 ms, then writes the 2 ms bandwidth, the 100 Hz
rate, continuous measurement with automatic set and reset, and high power continuous mode with periodic set. It stops
at the first refused write and gives the 100 Hz output data rate only when every write went through. A read takes the
nine output bytes in one blocking read with no status check. Each axis is its 18-bit count from the two high bytes and
the top two bits of its low byte, centered on 131072 and shifted right by 2, which rounds a negative value down like
the reference's arithmetic shift. The unit is SPARK for the axis conversion.

The MMC560X oracle includes the reference driver over a simulated chip whose answers each case draws and prints before
use, one case per process. It draws the bus type and a preset address, the product identity and its read
acknowledgement and the six write acknowledgements, then 20 to 60 reads with read answers and data. Every bus call,
detection, initialization and reading of the 300 cases replays exactly. In them 230 compasses are found, 139
initialize, and 8397 readings arrive. Of 28 tampered paths, 27 fail the vectors. The one that takes another axis's low
byte passes and is equivalent, since the low byte gives the count's two lowest bits, which the shift drops.

## D347. AK8963 compass driver (2026-10-18)

`Adaflight.AK8963` drives the AK8963 compass on I2C, on SPI, or on the MPU slave bus behind an MPU9250 gyro, whose I2C
master reaches the chip. Detection gives an unset I2C or slave address the chip's 0x0C and prepares the bus. SPI gets
its select pin and a 10 MHz clock. The MPU slave bus turns the gyro's DMA off and sets the gyro's interrupt pin
configuration to bypass, its I2C master to 400 kHz and its user control to master mode, each write followed by a 10 µs
wait. Detection then resets the chip, waits 4 ms and reads the identity 0x48, and a chip that does not answer gets its
bus released. Initialization registers the device, powers down, enters fuse ROM access, reads the three sensitivity
values, powers down again, reads both status registers and starts a 16-bit single measurement, whatever the writes and
the status reads answer, with no waits between them. A refused fuse ROM read fails the initialization, where the
reference takes the gains from the uninitialized stack memory the read left (F266). Each axis gain is its sensitivity
value plus 128, and the output data rate is 50 Hz.

On the MPU slave bus a chip write sets the gyro's slave 0 address, register, data and a one-byte transfer, and reports
success. A chip read sets the address with the read bit, the register and the length, waits 4 ms and reads the gyro's
external sensor data with interrupts masked. A read on I2C or SPI reads the first status and, with data ready, the six
data bytes and the second status. A read on the MPU slave bus queues the status read through the gyro and returns
without data. A later read completes it once 8 ms have passed, and with data ready queues the data read, which a later
read completes the same way. A status read that fails or finds no data queues the next status read at once. A read that
brings data starts the next single measurement, drops the data on a sensor overflow, and otherwise gives each axis as
its signed word times its gain divided by 256, clamped to 16 bits. The queued read's elapsed time is the signed 32-bit
difference of the microsecond clock. After 35.8 minutes of waiting the reference's subtraction overflows, and this unit
computes the remaining time without overflow. The reference keeps the queued read and the slave read phase in static
variables shared by every AK8963 device. This unit keeps them per device, which behaves the same with one compass. The
unit is SPARK for the slave read phase, the queued read timing and the axis conversion.

The AK8963 oracle includes the reference driver built with the MPU slave bus, over a simulated chip whose registers and
answers each case draws and prints before use, one case per process. A read returns the chip's registers from the one it
names, or on the MPU slave bus from the one in the gyro's slave 0 register. Every read takes its drawn acknowledgement,
the fuse ROM read among them, a refused direct read still brings the chip's bytes, as an I2C read that ends in an error
can, and a refused read through the busy gyro brings none. It draws the bus type, a preset address, the registers, the read and write acknowledgements and the
microsecond clock, a fifth of the clocks within 200 ms of the 32-bit wrap. Then come 30 to 80 reads on I2C and SPI or 60
to 200 on the MPU slave bus, each with registers, acknowledgements and the time since the read before, a fifth of those
times within 10 µs of 8 ms. Every bus call, detection, initialization, gain and reading of the 300 cases replays
exactly. In them 225 compasses are found, 201 initialize, 86 on I2C, 36 on SPI and 79 on the MPU slave bus, 24 fail at
a refused fuse ROM read, and 5908 readings arrive, 1709 of them through the gyro. The 61 tampered paths of the first
campaign failed its vectors. On its first pass the one that ignores the first status read's answer passed, since a
refused read brought no bytes, and led to the refused direct reads that bring the chip's bytes. The unchecked fuse read
and an initialization that reports success after a refused read, tampered back in, fail these vectors.

## D348. W25N flash driver (2026-10-18)

`Adaflight.Flash_Device.W25N` drives the W25N SPI NAND flash chips, the W25N01GV, the W25N02KV and
the MX35LF2GE4AD, with blocks of 64 pages of 2048 bytes. Identification looks the JEDEC ID up for
the block count, the read clock, the status register instructions, the page address form, the buffer
read mode and the replacement blocks, and names the replacement blocks and one marker block at the
end of the chip for bad block management. The reference enters that range in the partition table
during identification. This unit keeps it in the device for the flash layer, which does not try this
driver yet. Configuration resets the chip, waits for it, clears the protection register, turns on
ECC with the buffer read mode and sets the read clock, unless the system runs from memory-mapped
flash. A wait polls the status register until the busy flag clears and gives up at the millisecond
the last command set, and a wait that ends ready clears that millisecond to 0. An erase waits,
enables writes, erases the address's block and allows 15 ms. Erasing the whole chip erases every
block in turn. Every page address instruction sends the page's bits 16 to 23 in the byte after the
instruction, which the W25N02KV's 131072 pages need. The reference sends 0 there for that chip, so
its upper half addresses the lower half (finding F267, D6).

A program starts at its begin address only when the chip's data buffer holds no unprogrammed data, and otherwise goes on
at the buffer's next column. It loads the first buffer after a ready poll, skipped when no write could have left the
chip busy, and a write enable, with the data load instruction into an empty buffer or the random data load instruction
into one that holds data. When the load reaches the end of a page, the linked segment list goes on to program the buffer
into the page the program started at, with its own ready poll and write enable, and reports the bytes after that.
Otherwise the load reports them. A program of no buffers reports 0 bytes. A flush programs a buffer that holds data. A
read flushes, moves the address's page into the buffer when the buffer held data or holds another page, reads up to the
end of the page after a ready poll, and resets the chip on an uncorrectable ECC result. A wait that times out ends the
read with 0 bytes. The reference keeps the buffer state and the chip settings in static variables shared by every W25N
device. This unit keeps them in the device, which behaves the same with one flash chip. The unit is SPARK for the buffer
state, the addresses and the timeouts.

The W25N oracle includes the reference driver over a simulated SPI NAND chip and SPI bus, with the millisecond clock
advancing one millisecond every one to six calls. The bus runs segment lists with their callbacks and links. The chip
keeps a data buffer, its registers and write enable latch, stays busy for a drawn number of status reads after each kind
of command, and gives each page read a drawn ECC result. Each case draws the JEDEC ID, the configuration flags, DMA with
the bus's busy answers, the busy reads, the ECC results and the clock, a fifth of the clocks within 40 ms of the 32-bit
wrap, then runs 4 to 16 drawn operations, most of them at the address the last program reached. Two cases erase the
whole of a W25N01GV. Every bus call, identification and state after each operation of the 300 cases replays exactly. In
them 282 chips are identified and 260 configured, 60 of 401 wait operations time out, and of 352 reads 230 bring bytes,
18 of them resetting the chip after an ECC result, and 122 end at a timeout. Of 67 tampered paths, 66 fail the vectors,
one of them by flooding the checker's output. The one that narrows the ECC mask to its high bit passes and is
equivalent, since only that bit separates the uncorrectable results that reset the chip.

## D349. W25M flash driver (2026-10-18)

`Adaflight.Flash_Device.W25M` drives the W25M stacked-die flash chips behind one select pin, the
W25M512 with two W25Q256 NOR dies and the W25M02G with two W25N01GV NAND dies. Identification
selects each die and identifies it with the NOR or the NAND driver, whatever that answers, and gives
the chip the first die's geometry with twice its blocks and twice its size. A die is selected with
the die select command 0xC2 and the die's number between bus waits, only when another die was
selected last. Configuration, waits and full erases go to each die in turn. A readiness check asks
only the dies that could be busy, and the check and a wait stop at the first die that is not ready.
An erase or a read goes to the address's die at the address within it, and a read that spans both
dies reads from each in turn and stops at the first die read that brings fewer bytes than asked,
counting the bytes brought. The reference counts all the bytes asked for whenever every die read
brought some, also when a NAND die stopped at its page end (finding F268, D6). A program's begin
selects the address's die and hands it the whole address, and the continuation and finish go to the
die of the last begin. The reference keeps the dies, the die size, the last selected die and the
program's die in static variables. This unit keeps them in a record the caller passes, and the flash
layer does not try this driver yet (finding F269 concerns that step). The unit is SPARK for the die
selection and the address split, with a precondition that keeps an operation's address within the
two dies.

The W25M oracle includes the reference driver with the die drivers stubbed. A die identification
gives the die the geometry its driver would, the W25N one with its bad block partition request, and
each die operation logs its die and arguments and answers from the step's drawn answers, which give
ready or not, a wait that ends ready or times out, a read of all, half or none of its bytes, and a
program that takes its bytes or none. Each case draws the JEDEC ID and the configuration flags, then
6 to 20 operations, half of them within 600 bytes of the die boundary. Every die select, die call
and state after each operation of the 300 cases replays exactly. In them 145 W25M512 and 124 W25M02G
chips are identified, and of 410 reads 54 span both dies, 47 die reads bring half their bytes and 50
bring none. All 34 tampered paths fail the vectors, the two that change a stacked chip's JEDEC ID by
stopping the checker after its mismatches.

## D350. LPS22DF barometer driver (2026-10-18)

`Adaflight.LPS22DF` drives the LPS22DF barometer on I2C or SPI. Detection waits 20 ms, prepares the
select pin and a 10 MHz clock of an SPI chip, gives an unset I2C address the chip's 0x5D, and reads
the identity 0xB4. A refused identity read leaves the identity the last read gave, which the
reference keeps in a static variable and this unit keeps in its state. A chip without the identity
gets its bus released and the default address taken back. Otherwise detection registers the device,
sets the software reset and reads the second control register until the reset bit clears, reading
the millisecond clock after each read and giving up, without releasing the bus, once more than 10 ms
have passed. It then turns on the low-pass filter and the block data update and sets a continuous 10
Hz rate averaging 512 samples, whatever the writes answer, and sets up the barometer task for a
combined read with a 10 ms pressure delay. A pressure read starts the five data bytes while the bus
is free, a pressure sample takes the bytes the last read brought while the bus is free, and the
other calls do nothing. The calculation gives the pressure in pascal as the 24-bit count times 100
over 16 in single precision, cut toward zero and divided by 256, and the temperature in hundredths
of a degree as the signed 16-bit count. The reference takes the count unsigned, so a temperature
below zero reads 655.36 degrees too high (finding F270, D6). The unit is SPARK for the reset
timeout, the counts and the pressure arithmetic.

The LPS22DF oracle includes the reference driver with both bus kinds over a simulated chip, one case
per process. It draws the bus, the addresses, the identity, how many reads fail first, how many
control register reads still show the reset, never clearing in 15 percent of the cases and 6 to 16
reads in a fifth, around the read the 10 ms timeout passes on, and the clock's pace, a fifth of the
clocks within 12 ms of the 32-bit wrap. It then makes 50 of the driver's calls with scripted busy
and start answers and raw readings, among them temperatures below 0 degrees and pressure counts
whose scaled value ends in .5 or .75 just under a multiple of 256. Every bus, pin, delay and clock
call, detection and calculation of the 300 cases replays exactly. In them 123 chips are found and 45
identified chips time out in the reset, 21 of them with a reset that clears later. All 38 tampered
paths fail the vectors. On the first pass the one that checks the timeout after the reset bit
passed, since no reset cleared on the read that passed 10 ms, and the one that rounds the scaled
count passed, since no count sat where rounding and truncation part. Both led to the drawn resets
and counts.

## D351. QMP6988 barometer driver (2026-10-18)

`Adaflight.QMP6988` drives the QMP6988 barometer on I2C or SPI. Detection waits 20 ms, prepares the
select pin and a 10 MHz clock of an SPI chip, gives an unset I2C address the chip's 0x70, and reads
the identity 0x5C. A refused identity read leaves the identity the last read gave. A chip without
the identity gets its select pin returned to an input for the preinit owner and the default address
taken back. Otherwise detection registers the device, sets the IIR filter to 5, reads the 25
calibration bytes into a buffer that starts at zeros, sets the power mode and the sampling, whatever
the writes and the read answer, and sets up the barometer task for a combined read with a 23 ms
pressure delay. The two 20-bit and the ten 16-bit coefficients are signed and each is scaled in
single precision around its nominal value. The reference takes the ten 16-bit ones unsigned, where
the vendor's driver reads them signed (finding F271, D6). A pressure start writes the forced
measurement again and reports the write's answer, a pressure read starts the six data bytes while
the bus is free, a pressure sample takes the bytes the last read brought while the bus is free, and
the other calls do nothing. The calculation compensates the temperature and the pressure in single
precision in the reference's operation order, gives the pressure in pascal cut toward zero and the
temperature as the compensated value cut toward zero and divided by 256, and keeps the last pressure
or temperature when the new one is exactly zero. The unit is SPARK for the coefficients, whose
subtypes bound each one over every calibration byte, and for the compensation, whose terms are
bounded one by one so the sums stay finite.

The QMP6988 oracle includes the reference driver with both bus kinds over a simulated chip, one case
per process. It draws the bus, the addresses, the identity, whether the first read fails, the 25
calibration bytes, typical in half of the cases and random in two fifths, whether the calibration
read is refused, and whether writes answer, then makes 50 of the driver's calls with scripted busy
and start answers and raw readings, a tenth of them at the 2^23 midpoint. Every bus, pin and delay
call, detection and calculation of the 300 cases replays exactly. In them 194 chips are found, 113
on I2C and 81 on SPI, 18 with a refused calibration read and 16 with refused writes, 1047 samples
are taken and 1384 calculations run, 6 of them keeping both values on a zero result. Of 49 tampered
paths, 44 fail the vectors and one stops the checker at a coefficient's subtype check. Four pass and
are equivalent at the integer result: three reorder single precision products or sums, whose
rounding the pascal and 1/256 degree results hide, and one divides the compensated temperature by
256 before the cut, which gives the same whole number.

## D352. BMP085 barometer driver (2026-10-18)

`Adaflight.BMP085` drives the BMP085 barometer on I2C with its clear and conversion-end pins, which
the configuration names by tag, 0 for none. Detection sets the clear pin up as an output driven
high, sets the conversion-end pin up with a rising-edge interrupt, waits 20 ms, gives an unset I2C
address the chip's 0x77, and reads the identity 0x55. A chip that does not answer, or answers
another identity, gets its conversion-end pin and interrupt released when it has one, its clear pin
driven low and the default address taken back. Otherwise detection registers the device, reads the
version byte, whatever it answers, and the 22 calibration bytes, whose refused read fails the
detection the way a wrong identity does, where the reference parses the uninitialized buffer the
read left (F272), then gives the barometer task a 6 ms temperature delay and a 27 ms pressure delay
and tests the conversion-end pin, which counts as connected when it reads low and then high 12 ms
after a temperature start. A second detection answers found at once. A temperature or pressure start
clears the conversion flag and starts the control write, the interrupt sets the flag, a read starts
the two or three data bytes while the bus is free and, with the pin connected, the flag set, and a
sample takes the bytes the last read brought while the bus is free, the pressure as 19 bits of the
three bytes. The calculation compensates with the datasheet's integer arithmetic in 32 bits that
wrap, as the processor computes them, with arithmetic right shifts, and gives a division by zero,
which the reference never checks and the ARM processor answers with zero, that zero. It gives the
temperature in hundredths of a degree and the pressure in pascal, and keeps the fine temperature for
the next calculation. The reference keeps everything in static variables shared by every BMP085
device. This unit keeps them per device, which behaves the same with one barometer. The unit is
SPARK for the wrapping arithmetic, the shifts and the divisions.

The BMP085 oracle includes the reference driver, built with wrapping signed arithmetic as the ARM
processor computes, over a simulated chip, one case per process. It draws the clear and
conversion-end pin tags, the bus and the addresses, the identity, whether the first read fails,
whether the calibration read is refused, from the case number so the other draws keep their places,
the two levels the conversion-end pin shows during detection, and the 22 calibration bytes, near the
datasheet's example or random, then makes 50 of the driver's calls, each after a drawn interrupt or
none, with scripted busy and start answers and raw readings. A division by zero would end the case.
None of the 300 cases reaches one. Every bus, pin, interrupt and delay call, detection and
calculation of the 300 cases replays exactly, with the fine temperature and the raw readings. In
them 135 chips are found, 79 with a clear pin, 80 with a conversion-end pin, 42 of those connected,
and 24 on SPI, 20 fail at a refused calibration read, 2015 interrupts fire, 1483 samples are taken
and 935 calculations run. Of the first campaign's 63 tampered paths, 60 failed its vectors and two
stopped the checker at a subtype check. One passes and is equivalent: the rounding term of the B3
step adds 2 before a shift by 2 to a value the fixed oversampling of 3 makes a multiple of 8, so the
shift drops it. The unchecked calibration read and a refusal that skips the pin release, tampered
back in, fail these vectors.

## D353. TF rangefinder driver (2026-10-18)

`Adaflight.Lidar_TF` drives the Benewake TF serial rangefinders, the TFmini with a 40 cm to 12 m
range, the TF02 with 40 cm to 22 m and the TFnova with 10 cm to 14 m. Detection takes one of the
three rangefinder types and needs a configured serial port, which it opens at 115200 baud, then
gives the task a 10 ms period, the model's maximum range and a 90 degree cone, and sends the TFmini
and TF02 the 100 Hz command. Initialization resets the frame state. An update reads the clock and
every waiting byte through the frame state machine, two sync bytes 0x59, six payload bytes and a
checksum over all eight. A frame whose checksum fits gives the reading, out of range below the
model's minimum or above its maximum, for a TF02 whose reliability byte is under 7 and for a TFnova
whose confidence byte is under 90, and otherwise the distance in centimeters, 13 less for a TFmini
whose integral time byte is 7, and notes the frame's time. A frame whose checksum does not fit
counts an error. After the bytes, an update that saw no frame for more than 200 ms and sent no
command for more than 500 ms, both as signed 32-bit differences of the millisecond clock, sends the
command again. A read gives the last reading, 0 before the first frame. The reference keeps the
port, the frame state, the reading and the times in static variables. This unit keeps them in its
state, which behaves the same with one rangefinder, and keeps the last frame's distance, strength
and trailing bytes, which the reference shows through its debug values. The unit is SPARK for the
frame state machine and the reading.

The TF rangefinder oracle includes the reference driver over a stubbed serial port and clock, one
case per process. It draws the rangefinder type, a non-TF one in a seventh of the cases, whether a
port is configured and opens, and the clock, a fifth of them within 2 s of the 32-bit wrap, then
detects and runs 40 updates, each after a drawn clock advance of 10 ms, up to 100 ms, 150 to 700 ms
or up to 3 s, in a sixth of them to exactly 200 ms after the last good frame or 500 ms after the
last command, over a drawn byte stream of up to three frames with distances in and out of range,
long integral times, low reliabilities and confidences, wrong checksums in 15 percent of the frames,
false sync bytes and frames split across updates. Every port open, write and clock read, detection
and update of the 300 cases replays exactly, with the reading, the last frame's values and the error
count. In them 227 rangefinders are found, 98 TFmini, 65 TF02 and 64 TFnova, 7328 of 9080 updates
bring bytes, 6143 updates end with a distance and 2937 out of range, 2680 frames fail their
checksum, and the command goes 555 times. Of 45 tampered paths, 43 fail the vectors. Two pass and
are equivalent: the phase reset of the initialization, which repeats the phase detection leaves, and
the port guard of the update, which the device table reaches only after a detection.

## D354. Nooploop rangefinder driver (2026-10-18)

`Adaflight.Nooploop` drives the Nooploop TOFSense serial rangefinders, the F, FP, F2, F2P, F2PH and
F2MINI, with ranges from 2 cm to 10, 17, 5, 17, 33 and 5 m. Detection takes one of the six models
and needs a configured serial port, which it opens at 115200 baud, then gives the task a 10 ms
period, the model's maximum range and a 90 degree cone. Initialization resets the frame state and
the reading to no new data. An update reads the clock, notes the time of the first update, and reads
every waiting byte through the frame state machine: the sync bytes 0x57 and 0x00, after which a
second 0x57 keeps waiting for the 0x00, then 14 more bytes, the last the 8-bit sum of the 15 before
it. A frame whose sum fits gives a reading: out of range for a negative 24-bit distance, one outside
the model's range in millimeters or a status byte of 0xFF, and otherwise the distance in millimeters
divided by 10. The reading is new and the frame's time noted. A frame whose sum does not fit changes
nothing. After the bytes, when no frame came for more than 200 ms, or none ever came and the first
update was more than 200 ms ago, an update more than 200 ms after the last failure report makes the
reading a hardware failure, new when it was not one already, and notes the report. The reference
takes a time of 0 as none for all three times, so a frame, a first update or a report at the
millisecond 0 does not count, and this unit does the same. A read gives no new data until a new
reading, then the reading once. The reference keeps the port, the frame state, the reading and the
times in static variables. This unit keeps them in its state, which behaves the same with one
rangefinder. The unit is SPARK for the frame state machine and the reading, whose subtype the model
ranges bound.

The Nooploop oracle includes the reference driver over a stubbed serial port and clock, one case per
process. It draws the model, another type in a seventh of the cases, whether a port is configured
and opens, and the clock, 0 in 8 percent of the cases and within 2 s of the 32-bit wrap in 17
percent, then detects and runs 40 updates, each after a drawn clock advance, in a seventh of them to
exactly 200 ms after the last good frame or, before any, after the first update, in an eighth of the
cases with one to four silent updates first, over a drawn byte stream of up to three frames with
distances in and out of range or negative, invalid status bytes, wrong sums in 15 percent of the
frames, repeated and false sync bytes and frames split across updates, and reads the distance after
each update, twice in 30 percent of them. Every port open and clock read, detection and reading of
the 300 cases replays exactly. In them 224 rangefinders are found, 14 of them with the clock at 0,
7013 of 8960 updates bring bytes, and of 11572 reads 3734 give a distance, 2458 out of range, 585 a
hardware failure and 4795 no new data. Of 47 tampered paths, 43 fail the vectors. Four pass and are
equivalent: the two resets of the initialization repeat the defaults of a state built once, and a
read before the first frame gives no new data either way, the sign check of the distance rejects
what the range check after it rejects as well, and the port guard of the update is reached only
after a detection.

## D355. UP-T1 sensor driver (2026-10-18)

`Adaflight.UPT1` drives the Upixels UP-T1 serial module, a laser rangefinder and an optical flow
sensor in one frame stream, which the rangefinder update parses for both. Either detection opens the
configured serial port at 115200 baud when the other has not already, and fails without a port or
when it does not open. The rangefinder detection gives its task a 10 ms period, a 12 m range and a
90 degree cone. The optical flow detection gives its task a 20 ms period, an 8 cm minimum range, a
quality threshold of 30 and a 60 ms gyro delay. Initialization resets the parser and the reading to
out of range. An update counts every byte received and, before the 22nd, ignores them as the
module's startup text, then sends the command that selects the protocol. It then takes frames of a
header 0xFE, a length 0x0A, ten data bytes, their exclusive-or and a footer 0x55, counting a wrong
checksum or footer as an error. A frame gives the reading in centimeters when the laser status is
0xF5 and the distance lies between 25 and 12000 mm, and out of range otherwise, with the distance
and its microsecond time kept for the flow. The frames with a valid laser status and a positive
integration time add their flow integrals, in 32 bits that wrap, and their windows over the update.
When the summed window is between 1 us and 1 s, the update stamps the time and gives the rates in
radians per second, each integral sum over 10000 over the window in single precision, with the
quality of the last usable frame, 0 when its distance fell outside 80 to 12000 mm. Otherwise the
invalid frames add to a count that, past 5, stays at 5 and zeros the rates and the quality. A read
gives the reading once, then no new data. The reference keeps the port, the parser, the counts and
the flow data in static variables. This unit keeps them in its state, which behaves the same with
one module, and keeps the last frame's values and the parser phase before the last byte, which the
reference shows through its debug values. The unit is SPARK for the parser, the wrapping sums and
the rates, whose subtype bounds the division by a window of at least 1 us.

The UP-T1 oracle includes the reference driver with the optical flow build over a stubbed serial
port and a microsecond clock that advances 997 us at each read, one case per process. It draws
whether a port is configured and opens, which detections run and in which order, and the clock, then
runs 40 updates over a drawn byte stream: 5 to 30 startup bytes, then frames with flow integrals,
integration times of 0, 1 or up to 65535 us, laser distances in and out of range and at each limit,
status and confidence bytes, wrong checksums in a tenth, wrong footers and lengths, false headers,
frames split across updates, and in 7 percent of the updates 16 to 22 frames with windows of 50 to
65 ms, past the 1 s limit. Every port open, write and clock read, detection, reading, debug value
and flow sample of the 300 cases replays exactly, the rates bit for bit. In them 243 rangefinders
and 210 flow sensors are found, 192 together, 4342 of 9720 updates end with a distance and 2777 out
of range, 7680 flow samples come with 2400 at quality 0 and 145 zeroed, and 172 updates bring more
than 16 whole frames. Of 54 tampered paths, 47 fail the vectors and two stop the checker at a
subtype check. Five pass and are equivalent: the initial reading, which a read before the first
frame never shows, the two error counts, which nothing reads, the flow frame count in the window
test, which a positive integration sum implies, and the saturated invalid count, whose value no
longer matters once the rates are zero.

## D356. HC-SR04 rangefinder driver (2026-10-18)

`Adaflight.HCSR04` drives the HC-SR04 ultrasonic rangefinder on a trigger pin and an echo pin, named
by tag. Detection fails when either pin has an owner. Otherwise it sets the trigger pin up as an
output driven low, waits 100 ms, sets the echo pin up as an input and, when the echo pin reads low,
fires up to five 11 us trigger pulses, each followed by 60 ms of polling the echo pin for a high
level by the millisecond clock. A sensor that answers gets the echo pin's interrupt on both edges
and gives the task a 100 ms period, a 4 m range, a 30 degree cone and a 45 degree extended cone. One
that does not gets both pins released. The echo interrupt keeps the microsecond time of a rising
edge and, at a falling edge later than it by less than 2^31 us, the travel time and the millisecond
clock's reading. An update that finds the echo ended after the last trigger and within 60 ms of it
gives the distance as the travel time over 59, out of range past 4 m. One that finds the echo more
than 60 ms after the trigger, or before it, gives a hardware failure. One that finds it in the
trigger's millisecond leaves the reading. An update more than 60 ms after the last trigger fires the
next pulse. A read gives the reading once, then no new data. The reference stamps the echo with the
microsecond clock over 1000, which wraps after 71.6 min of uptime while the millisecond clock runs
on, so every reading after that is a hardware failure, and it keeps a falling edge more than 2^31 us
after its rise as a negative travel time and a negative distance (finding F273, D6). The reference
keeps its state in static variables. This unit keeps it per device, which behaves the same with one
sensor. The unit is SPARK for the travel time conversion and the division.

The HC-SR04 oracle includes the reference driver without its unit test guard, so its echo interrupt
handler and trigger pulse are built, over stubbed pins, interrupt setup, delays and both clocks, one
case per process since the driver keeps its state in statics. It draws the pin tags, which pin has
an owner, whether the echo pin is low at first and at which poll it goes high, and the millisecond
clock, which advances 7 ms at each read and starts near its wrap, below 100 s, anywhere in its 32
bits or between 36 and 71 min of uptime, then detects and, when the sensor answers, runs 40 updates,
each after a drawn clock advance, in a fifth of them exactly 60 or 61 ms after the last trigger,
with drawn echo edges fed to the handler at their microsecond times: pairs with travel times up to
30 ms, at the 4 m limit, zero, negative by a few ms or past 2^31 us, some ending in the clock's
millisecond, and lone edges, a rise sometimes more than 2^31 us in the past. Every pin, interrupt,
delay and clock call, detection and reading of the 300 cases replays exactly. In them 25 cases have
an owned pin, 213 sensors are found, and of 8520 updates 1293 end with a distance, 75 of them at 4 m
and 8 negative, 555 out of range, 6583 in hardware failure and 81 without new data. Of 49 tampered
paths, 47 fail the vectors and 2 stop the checker at the reading's subtype check.

## D357. 2SMPB-02B barometer driver (2026-10-19)

`Adaflight.SMPB_02B` drives the Omron 2SMPB-02B barometer on I2C or SPI. Detection prepares the
select pin and a 10 MHz clock of an SPI chip, sets the I2C address to 0x70 when none was given, and
reads the chip identity, 0x5C, up to five times 50 ms apart. A chip that never gives it gets its
select pin returned to the preinit state and the default address taken back. Otherwise detection
reads the nine coefficient registers, scales them in single precision, the pressure's linear one as
well, where the reference scales it through an integer division that truncates it to a whole number
(finding F274, D6), and writes the IIR filter of 8 samples. A refused coefficient read or IIR write
fails the detection, returning an SPI chip's select pin to the preinit state, where the reference
parses the uninitialized buffer the read left and reports the chip found (F275). A found chip gives
the barometer task a 35 ms pressure delay, the temperature coming with the pressure. A pressure
start sets the forced measurement with 4 temperature and 32 pressure averages, a pressure read
starts the six data bytes while the bus is free, a pressure sample takes the bytes the last read
brought while the bus is free and compensates them, and the temperature calls do nothing. The
compensation solves the datasheet's quadratics in single precision in the reference's order:

- the temperature as the negated linear coefficient less the root of the discriminant, over twice
  the quadratic coefficient, then over 256
- the raw pressure as the root less its linear coefficient, over twice its quadratic coefficient
- the pressure as the raw pressure over the temperature polynomial

A negative discriminant gives the reference a NaN and a zero quadratic coefficient a NaN or an
infinity, which the IEEE arithmetic propagates into the results. This unit keeps a kind beside each
value, finite, an infinity of either sign or not a number, and follows the same propagation, with
the final quotient computed in double precision, which rounds to the same single, so that an
overflow becomes a kind instead of a check. The calculation gives the pressure in pascal and the
temperature in hundredths of a degree as the ARM processor converts a single to a signed 32-bit
integer: toward zero, saturated past the range, and 0 for a NaN, a conversion the host leaves
undefined. The reference keeps everything in static variables. This unit keeps them per device,
which behaves the same with one barometer. The unit is SPARK for the scaling, the compensation and
the conversions, with the coefficient subtypes bounding every term and the quadratic coefficients
zero or at least one register count.

The 2SMPB-02B oracle includes the reference driver over a simulated chip, one case per process. It
draws the bus, SPI in 30 percent of the cases, the configured and real addresses, the identity each
of the five attempts answers, whether writes answer, which coefficient read the chip refuses, if
any, from the case number so the other draws keep their places, and the 21 coefficient bytes, with
the 24-bit offsets within 20 bits in 45 percent of the cases and a quadratic coefficient zero or
within three counts of it in a fifth, then makes 50 of the driver's calls, each with drawn busy and
start answers and data bytes near the midpoint, at it, random or at the ends. The driver's
conversion of a NaN is undefined on the host, so the oracle converts the results as the ARM
processor does. Every bus and pin call, detection, call result, pressure and temperature of the 300
cases replays exactly, the single precision values bit for bit where finite and by kind otherwise.
In them 153 chips are found, 70 on SPI, 38 fail at a refused coefficient read or IIR write, 24
writes are refused, 829 samples compensate and 1075 calculations run. 870 of the 7650 call results
show a NaN pressure and 112 a NaN temperature, and none an infinity. Of the first campaign's 53
tampered paths, 45 failed its vectors and 6 stopped the checker at a subtype check. Two pass and are
equivalent: a commuted sum in the temperature polynomial, which the addition keeps exact, and an
assignment the started read overwrites. The unchecked configuration, tampered back in, fails these
vectors.

## D358. LPS barometer driver (2026-10-19)

`Adaflight.LPS` drives the ST LPS22, LPS25, LPS33 and LPS35 barometers on SPI. Detection fails on
another bus, prepares the select pin and a 10 MHz clock, and reads the identity, 0xB1 for the LPS22,
LPS33 and LPS35 and 0xBD for the LPS25. It then powers the chip down with block updates, writes and
reads back the second control register, the averages, 64 for the temperature and 512 for the
pressure, and the data ready pin, failing when one reads back differently, starts the chip at 25 Hz
with block updates, the interrupt and the autozero reset, reads the first control register back,
gives the barometer task a combined read, a 1 us temperature delay and a 41666 us pressure delay,
and reads samples until one is not zero or more than 500 ms pass by the millisecond clock, which
fails the detection with the task's values left set. A sample reads the status and, when a pressure
or a temperature is ready, the three pressure bytes, sign extended, and the two temperature bytes,
and zeros otherwise. Only the pressure sample call reads. The other calls do nothing and succeed.
The calculation gives the pressure as the raw count times 100 over 4096 and the temperature as the
raw count times 10 over 48 plus 4250, in hundredths of a degree, both with the integer division. The
reference keeps the raw counts in static variables. This unit keeps them in its state, which behaves
the same with one barometer. The unit is SPARK for the sample decoding and the calculation, whose
24-bit subtype bounds the products.

The LPS oracle includes the reference driver over a simulated chip on a stubbed SPI bus and
millisecond clock, one case per process. It draws the bus, SPI in 88 percent of the cases, the
identity, 0xB1 in 45 percent and 0xBD in 35, which of the three verified writes read back wrong, 6
percent each, the clock, a fifth of the cases within 600 ms of its 32-bit wrap, its step, 1 to 40 ms
or 100 to 400 ms and a divisor of 500 ms in some, how many of detection's reads stay empty, none,
one to six or all, and the readiness, status bits and data bytes of each sample, with one count zero
in some, then detects and makes 50 of the driver's calls, redrawing the sample in 60 percent of
them. Every pin and bus call, clock read, detection, call result, raw count and calculation of the
300 cases replays exactly. In them 212 chips answer a known identity, 44 fail a read back, 69 time
out, 99 are found and 4950 calls run. Of 43 tampered paths, 42 fail the vectors and 1 stop the
checker at a subtype check.

## D359. BMP5xx barometer driver (2026-10-19)

`Adaflight.BMP5xx` drives the Bosch BMP580 and BMP581 barometers on I2C or SPI. Detection waits 20
ms, sets up the data ready pin and its rising edge interrupt when one is configured, prepares the
select pin and a 10 MHz clock of an SPI chip, sets the I2C address to 0x47 when none was given, and
reads the chip identity, 0x50 or 0x51, trying 0x46 when the default address gave another. A chip
that gives neither gets its select pin returned to the preinit state and the default address taken
back. Otherwise detection registers the device, resets the chip and waits 5 ms, sets the pulsed,
active high interrupt on data ready when the pin is configured, the compensation with the IIR output
in the shadow registers, an IIR coefficient of 15 on both values, 128 pressure and 4 temperature
oversamples and the normal mode at 50 Hz, whatever the writes answer, gives the barometer task a
combined read with a 15 ms pressure delay, and waits while the bus is busy. A chip on SPI sends a
dummy byte before its registers, which the reads skip. The pressure read brings the six data bytes,
kept on a failed read, and the pressure sample takes the temperature from the first three and the
pressure from the last three. The other calls do nothing. The calculation gives the temperature as
the signed 24-bit count times 100 over 65536, in hundredths of a degree, and the pressure as the
count over 64, in pascal, both with the integer division. The reference keeps the raw counts and the
data bytes in static variables. This unit keeps them per device, which behaves the same with one
barometer. The unit is SPARK for the sample decoding and the calculation, whose 24-bit subtype
bounds the products.

The BMP5xx oracle includes the reference driver over a simulated chip, one case per process. It
draws the bus, SPI in 30 percent of the cases, the configured and real addresses, the identity, 0x50
or 0x51 in 80 percent, whether a data ready pin is configured, how many busy answers detection waits
out, the SPI dummy byte and which of the first 32 reads fail, in 15 percent of the cases, then
detects and makes 50 of the driver's calls over drawn data bytes, typical, random, negative, at the
sign bit, at 63 and 64 counts or at the ends, redrawn in 60 percent of the calls. Every pin and bus
call, detection, call result, raw count and calculation of the 300 cases replays exactly. In them
175 chips are found, 84 BMP580 and 91 BMP581, 132 cases configure the data ready pin, and 8750 calls
run. Of 51 tampered paths, 50 fail the vectors. One passes and is equivalent: the select pin return
in the address retry, which only an I2C chip reaches.

## D360. ICM456xx gyro driver (2026-10-19)

`Adaflight.MPU_Gyro.ICM456xx` drives the ICM-45686 and ICM-45605 gyros over the SPI gyro layer.
Detection resets the chip and polls the reset bit 10 us apart for up to 20 ms, wakes it and reads
its identity up to 21 times, 1 ms apart. Initialization sets a 24 MHz clock, runs the layer's, turns
the sensors on in low noise mode and waits 1 ms, sets the accelerometer to 16 g at 1600 Hz and waits
10 ms, enables the gyro's anti-alias filter and interpolator and sets its low pass filter from the
filter setting through the indirect registers, falling back to the raw path and the bypass when an
update fails, sets the gyro to 2000 degrees per second at 6400 Hz and waits 35 ms, takes the short
period of 156 us, sets the pulsed, push-pull, active high interrupt on data ready and names the data
registers. The accelerometer initialization enables its anti-alias filter and interpolator and sets
its low pass filter to an eighth of its rate the same way. An indirect register access waits for the
done bit 4 us apart for up to 5 ms, writes the address and reads or writes the data 4 us apart. An
update reads, writes when the masked bits differ, reads back and tries three times, and a read while
armed fails. The reads take the six little-endian bytes of the gyro or the accelerometer with a
blocking transfer. The first gyro read leaves the interrupt mode without DMA, which the reference
never selects. The reference keeps the arming state in a global flag. This unit takes it as an
argument of the initializations. The unit is SPARK, with the polls bounded by their timeouts.

The ICM456xx oracle includes the reference driver and the common SPI gyro layer over a simulated
chip with its indirect registers, one case per process. It draws the bus, the chip identity, 0xE9 or
0xE5 in 85 percent of the cases, and the reads before it answers, the polls the reset bit and each
indirect access take to clear, the first access past the driver's 5 ms timeout in 4 percent of the
cases, past all three retries in some, and the reset past its 20 ms timeout in 3, whether indirect
writes take, refused in 12 percent, the arming state, armed in 5 percent, the startup clock and its
step, the interrupt pin, the filter setting and the register values, then runs the detection, the
gyro and accelerometer detection and initialization, and 30 steps of interrupts, bursts, DMA
completions, gyro and accelerometer reads and new samples. Every bus, pin, clock and delay call,
detection, setting, reading and indirect register value of the 300 cases replays exactly. In them
215 chips are found, 132 answer 0xE9 and 122 0xE5, 14 cases are armed, the first indirect access
times out in 7, past all retries in 2, the reset in 11, 36 refuse the indirect writes, and of 6450
steps 1524 read the gyro, 1265 the accelerometer and 2067 raise interrupts. Of 69 tampered paths, 68
fail the vectors. One passes and is equivalent: the masking of an update's value, since every value
lies within its mask.

## D361. LSM6DSO gyro driver (2026-10-19)

`Adaflight.MPU_Gyro.LSM6DSO` drives the LSM6DSO gyro over the SPI gyro layer. Detection reads the
identity, 0x6C, once. Initialization sets the reset bit of the third control register and waits 100
ms, enables the gyro data ready on both interrupt pins, sets the accelerometer to 833 Hz at 16 g
from its first filter and the gyro to 6664 Hz at 2000 degrees per second, the block update and the
address increment, the I2C disable and the gyro's first filter, the high performance accelerometer
with the 335 Hz gyro filter, and the I3C disable, each masked write reading the register first and
skipped when the read fails, waits 1 ms after each write, arms the data ready interrupt when the
board has the pin, and sets a 10 MHz clock. It leaves the layer's data registers, DMA read and short
period unset. The interrupt only marks data ready. The reads take the six little-endian bytes of the
gyro or the accelerometer with a blocking transfer and fail when the transfer does. The gyro's scale
is 0.07 degrees per second per count and the accelerometer's 2048 counts per g. The unit is SPARK.

The LSM6DSO oracle includes the reference driver, its initialization and the common SPI gyro layer
over a simulated chip, one case per process. It draws the bus, the chip identity, 0x6C in 85 percent
of the cases, which of the first 32 reads fail, in 15 percent, the startup clock and its step, the
interrupt pin and the register values, lets the layer find another chip first in a twelfth of the
cases, then runs the detection, the gyro and accelerometer detection and initialization, and 30
steps of interrupts, bursts, DMA completions, gyro and accelerometer reads and new samples. Every
bus, pin, clock and delay call, detection, setting and reading of the 300 cases replays exactly. In
them 254 chips answer the identity, 44 cases script read failures, the layer finds another chip
first in 25 cases, 209 gyros are found, and of 6270 steps 1479 read the gyro, 1239 the accelerometer
and 2004 raise interrupts. Of 45 tampered paths, 43 fail the vectors. Two pass and are equivalent:
the delay guard of a write, since every write waits, and the acknowledgement check of the identity
read, since a refused read leaves the byte zero.

## D362. ICM56686 gyro driver (2026-10-19)

`Adaflight.MPU_Gyro.ICM56686` drives the ICM-56686 gyro over the SPI gyro layer. Detection resets
the chip and polls the reset bit 10 us apart for up to 20 ms, wakes it and reads its identity up to
21 times, 1 ms apart. Initialization sets a 24 MHz clock, runs the layer's, and through the indirect
registers selects 16-bit little-endian data, turns on the gyro's sample rate converter and
prefilter, sets its low pass filter from the filter setting, bypasses its notch, and turns on the
accelerometer's converter and prefilter with its low pass filter at an eighth of its rate, whatever
each access answers. It then sets the accelerometer to 16 g at 1600 Hz and the gyro to 2000 degrees
per second at 6400 Hz and the pulsed, push-pull, active high interrupt, turns the sensors on in low
noise mode and waits 35 ms, takes the temperature scale of 1/128 degree per count with its zero at
25 degrees and the short period of 156 us, names the data registers and enables the data ready
interrupt. An indirect access writes the address, and the data for a write, then waits 4 us and
polls the done bit 10 us apart for up to 5 ms. A read then takes the data and waits again. A
modification reads first and writes the masked bits, or the masked value alone when the read fails.
A write while armed fails. The reads take the six little-endian bytes of the gyro or the
accelerometer with a blocking transfer. The first gyro read leaves the interrupt mode without DMA,
which the reference never selects. The reference keeps the arming state in a global flag. This unit
takes it as an argument of the initialization. The unit is SPARK, with the polls bounded by their
timeouts.

The ICM56686 oracle includes the reference driver and the common SPI gyro layer over a simulated
chip with its indirect registers, one case per process. It draws the bus, the chip identity, 0x08 in
85 percent of the cases, and the reads before it answers, the polls the reset bit and each indirect
access take to clear, the first access past the driver's 5 ms timeout in 4 percent of the cases,
every later access past it in 5 and the reset past its 20 ms timeout in 3, whether indirect writes
take, refused in 12 percent, the arming state, armed in 5 percent, the startup clock and its step,
the interrupt pin, the filter setting, past the known ones in 8 percent, and the register values,
then runs the detection, the gyro and accelerometer detection and initialization, and 30 steps of
interrupts, bursts, DMA completions, gyro and accelerometer reads and new samples. Every bus, pin,
clock and delay call, detection, setting, reading and indirect register value of the 300 cases
replays exactly. In them 214 chips are found, 12 cases are armed, 12 time out on the first indirect
access, 14 on every later one and 10 on the reset, 39 refuse the indirect writes, 26 have an unknown
filter setting, and of 6420 steps 1515 read the gyro, 1272 the accelerometer and 2060 raise
interrupts. Of 75 tampered paths, 74 fail the vectors. One passes and is equivalent: the masking of
a modification's value, since every value lies within its mask.

## D363. BMI423 gyro driver (2026-10-19)

`Adaflight.MPU_Gyro.BMI423` drives the BMI423 gyro over the SPI gyro layer. The chip starts in I2C
mode: the select pin low for 1 ms then high for 2 ms and a discarded identity read select SPI. A
register is 16 bits little-endian behind two dummy bytes. Detection selects SPI and reads the
identity, 0xAB in the low byte. Initialization writes the soft reset and waits 2 ms, selects SPI
again, selects the 16-bit samples, writes the filter configuration, second order filters on both
sensors or the gyro's bypassed for the experimental setting, before each sensor's configuration, the
accelerometer at 16 g and 800 Hz and the gyro at 2000 degrees per second and 6.4 kHz with the
bandwidth of the filter setting, which waits 55 ms, then the push-pull active high interrupt pin in
long pulse mode with the gyro data ready on it, the other writes 1 ms apart, enables the interrupt
when the board has the pin, and sets a 10 MHz clock. The interrupt handler is the layer's, the
chip's own with no short period. The first gyro read after 1000 interrupts takes the DMA mode when
the bus has it, in which each interrupt starts the 15-byte read of both sensors and the reads decode
the accelerometer at byte 3 and the gyro at byte 9. The other modes read a sensor's six
little-endian bytes behind the address and the dummy bytes with a blocking transfer, a gyro read in
the mode without interrupts repeats the first read once 1000 interrupts have come, and a read in the
first mode fails. The scale of 2000 degrees per second over the 16-bit count is set at the gyro
detection. The unit is SPARK, with the sample offsets bounded by the receive buffer.

The BMI423 oracle includes the reference driver and the common SPI gyro layer over a simulated chip
with 16-bit registers behind two dummy bytes, one case per process. It draws the bus, the chip
identity, 0xAB in 85 percent of the cases, the dummy bytes, whether reads answer, refused in 5
percent, the startup clock and its step, DMA, the interrupt pin, the filter setting, past the known
ones in 8 percent, and the register values, then runs the detection, the gyro and accelerometer
detection and initialization, and 30 steps of interrupts, a burst of 990 to 1050 interrupts first or
after some reads outside the DMA mode, DMA completions, gyro and accelerometer reads and new
samples. Every bus, pin, clock and delay call, detection, setting and reading of the 300 cases
replays exactly. In them 240 chips are found, 185 cases have DMA, 66 the experimental filter and 26
an unknown one, 194 raise a burst, 33 of them at or below the 1000 threshold, 21 repeat the first
read from the mode without interrupts, and of 7200 steps 1813 read the gyro and 1381 the
accelerometer. Of 75 tampered paths, 74 fail the vectors and 1 stop the checker at a subtype check.

## D364. LSM6DSV16X gyro driver (2026-10-19)

`Adaflight.MPU_Gyro.LSM6DSV16X` drives the LSM6DSV16X, LSM6DSV32X and LSM6DSK320X gyros over the SPI
gyro layer. The LSM6DSV16X probe reads the identity, 0x70, resets the chip and takes the variant bit
of control register 8 for the LSM6DSV32X. The LSM6DSK320X probe reads its identity, 0x75. A reset
clears the two rate fields with their modes kept, sets the address increment, each write read back,
waits 500 us, writes the reset bit, waits 10 ms and polls the register once a millisecond for up to
10 more until the reset bit clears with the block update set, then checks the identity again.
Initialization sets a 10 MHz clock and configures the chip in up to three attempts, each a reset and
the control registers written and read back: block update and increment, high accuracy mode 1, the
high accuracy modes of both sensors, the accelerometer at 16 g, or 32 g on the LSM6DSV32X, with its
second low pass filter at a quarter of its rate, the gyro at 2000 degrees per second, or 4000, with
the first low pass filter bandwidth of the filter setting and a bit the LSM6DSK320X needs, its
filter on, the pulsed data ready on the first interrupt pin, then after 500 us the gyro at 8 kHz and
the accelerometer at 1 kHz. When every attempt fails the failure call takes over. Otherwise the
scale is 0.07 degrees per second per count, or 0.14, and the layer's initialization runs. The
interrupt and the DMA read are the layer's. A DMA completion latches the twelve bytes of both
sensors behind a sequence count before the layer's completion. The reads take a sensor's six
little-endian bytes with a blocking transfer, or the latched sample once one is ready, and fail
before the first gyro read. The reference reads the latched sample twice over when a completion
changes the count during the copy. Here the latch is a parameter of the read, so one copy under the
count suffices. The reference indexes its four-entry bandwidth table with the filter setting, which
MSP writes unchecked (finding F276). A setting past the known ones takes the 288 Hz bandwidth here.
The unit is SPARK, with the sample offsets bounded by the receive buffer and the latch.

The LSM6DSV16X oracle includes the reference driver and the common SPI gyro layer over a simulated
chip, one case per process. It draws the chip identity, 0x75 in 45 percent of the cases and 0x70 in
40, the variant bit, set in 30 percent, the polls a reset takes to clear, past the driver's 10 in 6
percent, the identity the chip answers after a reset, another in 4 percent, whether that reset sets
block update, not in 5 percent, a register that ignores writes from its first, second or third one,
in 10 percent, the bus, the startup clock and its step, DMA, the interrupt pin, the filter setting
and the register values, lets the layer find another chip in a twelfth of the cases when neither
identity answers, then runs the detection, the gyro and accelerometer detection and initialization,
and 30 steps of interrupts, a burst of 990 to 1050 interrupts first or after some reads outside the
DMA mode, DMA completions, gyro and accelerometer reads and new samples. A failure ends the case.
Every bus, pin, clock, delay and failure call, detection, setting, reading and latch state of the
300 cases replays exactly. In them 126 chips are LSM6DSK320X, 75 LSM6DSV16X and 30 LSM6DSV32X, 231
gyros are found, 52 initializations fail after three attempts, and of 5370 steps 1285 read the gyro,
1048 the accelerometer and 1730 raise interrupts. Of 101 tampered paths, 98 fail the vectors and 1
stop the checker at a subtype check. Two pass and are equivalent: the return after the failure call,
which never returns in the reference, and the latch reset at the first gyro read, since the latch
starts cleared and no later read returns to that mode.

## D365. BMI160 gyro driver (2026-10-19)

`Adaflight.MPU_Gyro.BMI160` drives the BMI160 gyro over the SPI gyro layer. Detection sends one 0xFF
byte to select SPI, waits 100 ms and reads the identity, 0xD1. Initialization commands the gyro and
the accelerometer into normal power mode, 100 and 5 ms apart, and checks the power status. When both
are normal it sets the accelerometer to 800 Hz with the second oversampling and the gyro to 3200 Hz
with the oversampling of the filter setting, the ranges 8 g and 2000 degrees per second, 1 ms after
each, sets the two offset enable bits over the offset register, and enables the data ready interrupt
on the first interrupt pin, pushed, 1 ms after each. It then enables the interrupt when the board
has the pin and sets a 10 MHz clock, whether the power status passed. The reference answers a second
detection or initialization from flags. Here each call does its bus work, and the reference's fast
offset compensation, behind a constant that never enables it, is left out. The interrupt and the DMA
read are the layer's: the first gyro read after 1000 interrupts takes the DMA mode when the bus has
it, in which each interrupt reads the twelve bytes of both sensors and the reads decode the gyro at
byte 2 and the accelerometer at byte 8. The other modes read a sensor's six little-endian bytes with
a blocking transfer. The reads answer true in every mode. The scale of 2000 degrees per second over
the 16-bit count is set at the gyro detection and the accelerometer counts 4096 per g. The unit is
SPARK, with the sample offsets bounded by the receive buffer.

The BMI160 oracle includes the reference driver and the common SPI gyro layer over a simulated chip,
one case per process. It draws the chip identity, 0xD1 in 85 percent of the cases, the power status
after the mode commands, normal in 85 percent, the bus, the startup clock and its step, DMA, the
interrupt pin, the filter setting, past the known ones in 8 percent, and the register values, lets
the layer find another chip first in a twelfth of the cases, then runs the detection, the gyro and
accelerometer detection and initialization, and 30 steps of interrupts, a burst of 990 to 1050
interrupts first or after some reads outside the DMA mode, DMA completions, gyro and accelerometer
reads and new samples. Every bus, pin, clock and delay call, detection, setting and reading of the
300 cases replays exactly. In them 219 chips are found, 23 fail the power status, 21 have an unknown
filter setting, 175 raise a burst, and of 6570 steps 1532 read the gyro, 1306 the accelerometer and
2107 raise interrupts. Of 71 tampered paths, 70 fail the vectors and 1 stop the checker at a subtype
check.

## D366. ICM40609 gyro driver (2026-10-19)

`Adaflight.MPU_Gyro.ICM40609` drives the ICM-40609-D gyro over the SPI gyro layer. Detection selects
register bank 0, resets the chip, waits 1 ms and reads the identity, 0x3B. Initialization sets a 24
MHz clock, runs the layer's with the chip's data registers and the DMA read from the temperature,
takes the temperature scale of 1/132.48 degree per count with its zero at 25 degrees, turns the
sensors on in low noise mode with the RC oscillator and waits 200 us then 35 ms, selects big-endian
data, sets the accelerometer to 16 g at 1 kHz and waits 10 ms, sets the temperature filter to 4 kHz,
the third order user interface filters of both sensors and the second order decimator, the low
latency filter bandwidths, the anti-alias filters of both sensors from the corner of the filter
setting, 213, 488, 997 or 1962 Hz, through the 63 profiles of the chip, the notch at 1.5 kHz with
its widest bandwidth and the coefficient of its cosine, rounded from eight times its distance from
one, the first order high pass filter at its second bandwidth, each in its register bank with bank 0
selected after, the gyro to 2000 degrees per second at 8 kHz, waits 35 ms, and routes the pulsed,
push-pull, active high data ready interrupt to the first pin, cleared on the status read, with the 8
us pulse and no deassertion. The reads are the layer's. The unit is SPARK, with the profile search
bounded by the table.

The ICM40609 oracle includes the reference driver and the common SPI gyro layer over a simulated
chip with five register banks, one case per process. It draws the chip identity, 0x3B in 85 percent
of the cases, the bus, the startup clock and its step, DMA, the interrupt pin, the sample rate
divider, the filter setting, past the known ones in 8 percent, and the register values of the banks,
lets the layer find another chip first in a twelfth of the cases, then runs the detection, the gyro
and accelerometer detection and initialization, and 30 steps of interrupts, a burst of 990 to 1050
interrupts, exactly 1000 in a tenth of the cases, first or after some reads outside the DMA mode,
DMA completions, gyro and accelerometer reads and new samples. Every bus, pin, clock and delay call,
detection, setting and reading of the 300 cases replays exactly, the notch coefficient from the
cosine among them. In them 225 chips are found, 29 have an unknown filter setting, and of 6750 steps
1607 read the gyro, 1377 the accelerometer and 2127 raise interrupts. Of 107 tampered paths, 99 fail
the vectors. Eight pass and are equivalent: the bits of the filter order, decimator and bank masks
that their values set, the keep mask bit cleared just before, the profile table corner at 1962 Hz
and its last entry, which the fixed targets reach exactly and never pass, and the notch coefficient,
88.19 at the constant 1.5 kHz, which rounds and truncates alike.

## D367. SD card SPI driver (2026-10-19)

`Adaflight.SD_Card` drives an SD card over SPI, the layer under the FAT file system. Initialization
takes the detect pin, the bus and the select pin, sets the 400 kHz clock, waits a second and clocks
ten idle bytes before it starts the card: each poll advances the card from the reset command through
the interface condition, which names the version, the initialization command repeated until it
answers, the operating conditions for the capacity of a version 2 card, the card specific data for
the block count, the identification for the metadata and the 512 byte block length of a standard
capacity card, then sets the 25 MHz clock. A command waits for an idle byte, up to eight, sends its
six bytes and waits for the answer, up to eight bytes. A data block waits for its token, up to eight
bytes, and its two check bytes are discarded. A read sends the read command and the poll takes the
block when its token comes, within 100 ms. A write sends the write command, the token and the block,
the whole block with DMA or 256 bytes at a time, the poll finishes it with two check bytes and takes
the card's answer, calls the completion, and waits for the card to leave busy within 250 ms. A run
of writes sends its count and the multiple block command, and ends with the stop token when a write
leaves the run or its count runs out. Each failure resets the card, up to eight in a row before it
counts as absent, and an initialization past a second starts over. The reference keeps a pointer to
the caller's block while a write is pending. Here the driver keeps a copy, and a read's bytes arrive
in that copy at the completion. A card whose mode is off takes no operation, where the reference
calls through a null dispatch table (finding F277), and a reset command whose idle wait aborts
answers 0, where the reference returns an uninitialized byte. The bit field reader stops at the end
of the card specific data, where the reference reads one byte past it. The unit is SPARK, with the
segment lengths and the bit fields bounded.

The SD card oracle includes the reference driver, its dispatch and its bit field reader over a
simulated card and the reference's segment semantics: chip select asserted at the first segment and
after each negation, a callback answering busy repeating its segment, an abort skipping the rest.
The card parses commands byte by byte, answers after a drawn number of idle bytes, past the driver's
eight in 7 percent of the cases, sends its registers after a drawn wait, past eight in 20 percent,
and its data blocks after another, past eight in 30 percent, takes written blocks, stays busy for a
drawn number of bytes after each, past the driver's eight in 20 percent, and refuses one drawn
command in 20 percent. Each process runs one case: it draws the card's version, 1 in 20 percent, its
capacity, high in 70 percent of the version 2 cards, its registers, the initialization answers, the
write answer, accepted in 90 percent, the configuration, with the mode off in 5 percent, the detect
pin, present in 40 percent, the clock and its step, DMA and the bus's busy answers, initializes the
driver and runs 40 drawn operations: polls, block reads with an error token in place of the start
token in 10 percent of them, block writes with a malformed data response from a few percent of the
cards, runs of writes continued at their next block in 55 percent of the steps inside a run, card
removals and clock advances, only polls when the mode is off, with the card busy for up to 12 bytes
after the application command in 30 percent of the cards, and each written block gets its own
buffer, since the reference keeps the pointer. While a read waits for its data token or a write
waits for the card, 35 percent of the steps advance the clock so that the next poll lands on the
timeout boundary: at the limit, one past it, up to nine before it or up to 60 past it. Thirty more
cases hold a present card whose data tokens come past the poll's eight idle bytes and which refuses
no command, advance the clock in 60 percent of the waiting steps, onto the limit itself in 60
percent of those, poll right after each advance in 85 percent, and while a run is open begin runs in
place of reads, at the run's next block in 60 percent. Every bus, pin, clock and delay call, each
segment with its bytes or their hash, the completions, the driver's state after each operation and
the metadata of the 330 cases replay exactly. In them 151 cards reach the ready state, 343 blocks
are stored, 517 completions are called, 433 with a block, and the results cover every driver state
but the identification wait, which ends within the poll that starts it, since the two registers
share one delay. Of 111 tampered paths, 98 fail the vectors and 3 stop the checker at a subtype
check. Ten pass and are equivalent:

- the reset command's no-reply exception, whose answer of zero after an aborted idle wait the reset
  state rejects as it rejects no reply
- the detect inversion gated on the detect pin, which is read only behind that pin
- the enable test on any nonzero mode, since the layer starts this driver for the SPI mode only
- the SPI mode constant, which that test no longer compares
- the failure count's clear at initialization, which the firmware calls once on a count of zero
- the card-absent state the poll writes while disabled, which initialization wrote already
- the capacity flag's clear for a version 1 card, clear already since a card keeps its version
  across the resets of a run
- the send completion's comparison with the chunk count, which the poll reaches only after it sent
  the second chunk
- the run begin's test of the first command's reply, since the second command answers only after the
  first succeeded
- the write's busy answer when a run's end stays in progress, which the stopping state answers with
  busy on the next pass

## D368. SD card SDIO driver (2026-10-19)

`Adaflight.SD_Card_SDIO` drives an SD card through an SDIO controller, which runs the card commands
itself. The card state, the operation results, the configuration and the metadata moved from the SPI
driver into `Adaflight.SD_Card_Types`, which both card drivers share. Initialization takes the
detect pin, the controller's DMA stream, 0 where the family takes one from the map and the map has
none, the write cache setting and the controller, then asks the controller to start the card, which
it runs to the end: each poll moves the card from the reset through the initialization, done when
the controller reports the card ready and gives its information, which names the version, 2 for
every kind but the first, the capacity class, the block count from the capacity cut to 32 bits, and
the identification for the metadata, whose production year is 2000 plus the eight bits of the date's
year field above the month, where the reference ORs the field's two nibbles onto each other and
gives at most 2015 (finding F278, D6). A read starts a one block transfer and the poll takes the
block when the transfer ends with the card ready, within 100 ms. Past that, or when the card reports
an error, the poll resets the card and reports the failure through the completion, where the
reference repeats the poll until the card answers, without a reset or a completion (finding F278,
D6), and the port's passes stop at 64, which the vectors never reach. A write starts the transfer,
the poll calls the completion when the transfer ends and waits for the card to leave busy within 250
ms. With the write cache, the blocks of a run collect in a cache of 16 and go to the card in one
transfer when the cache fills or the run ends, each cached block answered success without a
completion and the run's count and next block advanced. A run's end writes the blocks still cached
as one transfer without a completion, and a write or a run begun at a block out of sequence, in the
ready state as in the writing state, ends the run first and waits while the transfer runs. The
reference drops the cached blocks at a run's end, lets a block out of sequence join the cache in the
ready state and begins a run from the ready state over the blocks an earlier run left, so blocks are
lost or written at the wrong index (finding F278, D6). A run of writes takes its count and ends when
a write leaves the run or its count runs out. A failure asks the controller for a new initialization
and counts the failure, up to eight in a row or a missing card before the card counts as absent, and
otherwise returns the card to the reset state with the time, whether the controller accepted or not.
The reference counts only a refused initialization and leaves the state as it was after an accepted
one, which on its controllers runs once and repeats its first answer, so a card that failed an
operation stays in the state that failed (finding F278, D6). An initialization past a second starts
over. A refused read resets the card and reports the failure through the completion of the read
asked for, where the reference reports it through the previous operation's (finding F278, D6). An
operation the controller refuses answers a failure. One in the wrong state answers busy. A card
whose mode is off takes no operation. The unit is SPARK, with the poll's repeats, the cache count
and the cache slices bounded.

The SDIO card oracle includes the reference driver and its dispatch over a stubbed controller: an
initialization answering every call with one drawn result, refused in 10 percent of the cases, a
card ready after a drawn number of status calls past the first initialization and past each write,
past three in 30 percent, and not at drawn calls in 15 percent, card information refused for a drawn
number of calls and at drawn calls, block transfers pending for a drawn number of checks, past three
in 30 percent, one drawn transfer refused in 20 percent, and a DMA map without a stream in 7
percent. Each process runs one case: it draws the card's kind, high capacity in 60 percent, its
capacity, past 32 bits in 20 percent, and its identification, the configuration, with the write
cache in half of the cases and the mode off in 5 percent, the detect pin, present in 40 percent, the
clock and its step, initializes the driver and runs 40 drawn operations: polls, block reads and
writes, runs of up to 24 writes with the next block of the run drawn ahead of the others and bursts
of up to 16 of them that fill the cache, run begins at the run's next block, card removals and clock
advances, which while the card initializes or a read or a write waits put the next poll on the
timeout boundary in 35 percent of the steps and on the stop timeout in half of those, only polls
when the mode is off. Thirty more cases take an accepted initialization, a card not ready at half of
the status calls, no refused transfer and runs of one to three blocks, advance the clock in 60
percent of the waiting steps, onto the stop limit itself in 75 percent of those, and poll right
after each advance in 85 percent. Every controller, pin and completion call, the written blocks by
their hash, the driver's state and cache count after each operation and the metadata of the 330
cases replay exactly. In them 236 cards reach the ready state, 426 transfers write 660 blocks, 38 of
them several blocks from the cache and 5 the full cache, 175 reads start, 480 completions are
called, and the results cover every driver state. Of 100 tampered paths, 92 fail the vectors. Eight
pass and are equivalent:

- the refused initialization's count, threshold, start and insertion checks, which a controller that
  answers every initialization with its first result never reaches
- the information copy of an unanswered call, which brings the same values
- the status of an ended write run, which every caller compares with success only
- the failed read's completion with the operation's stored index and data, which equal the call's

## D369. W25Q128FV flash driver (2026-10-19)

`Adaflight.Flash_Device.W25Q128FV` drives the nine NOR flash chips of the W25Q128FV family, 2 to 32
MB parts with 256-byte pages and 64 KB sectors, over a quad SPI controller: a generic child of the
flash device over the controller's one-line instructions with data, an answer or an address, its
four-line read with an address and dummy cycles, segment lists with their buffers on four lines, the
wait, the millisecond clock and the report of written bytes. Identification looks the JEDEC ID up
for the sectors and sets the geometry. An unknown ID clears it. Configuration does nothing on a
memory-mapped system and otherwise resets the chip: it waits for the chip, sends the reset pair,
waits a millisecond and for the chip again, then reads the second status register and, when the quad
enable bit is clear, reads it again and writes it back with the bit set after a volatile write
enable. The ready check reads the first status register. A wait for the chip ends when the chip
reads ready or the timeout the last operation set passes, and clears the timeout, so a wait that
follows another with no operation between ends at the first busy answer. Erases wait for the chip,
enable writes, send the block or chip erase and set the erase timeout. A program goes to the bus as
a segment list: the status read repeated while the chip is busy, the write enable, the quad program
command with its address and one or two buffers on four lines, the last of which releases the chip
and ends the program, after which a program without a report waits for the bus. No buffer reports
zero bytes to a program with a report, and any other count sends nothing and returns 0 after the
written bytes take the first buffer's length. A read waits for the chip, reads on four lines after
eight dummy cycles, sets the read timeout and returns the length, or 0 when the chip stayed busy or
the bus refused. The driver never sets a program timeout, which only the octo SPI path of the
reference does. That path and the memory-mapped octo SPI operation stay out, since three SPRacing H7
boards reach them memory mapped and the other builds leave them behind an experimental define. The
bus formal runs the segment list's callbacks, which the STM32 quad SPI controller code does not
(finding F279). The unit is SPARK for the command bytes, the table and the segment lists.

The W25Q128FV oracle includes the reference driver over a simulated chip, bus and clock, one case
per process. The bus runs segment lists as the SPI handler does and clocks the one and four line
transfers through the chip as bytes. The chip keeps a write enable latch and a volatile one, a quad
enable bit with a stored copy the reset restores, stays busy for a drawn number of status reads
after a program, an erase or a reset, ignores commands while busy and wraps a program within its
page. The clock advances a millisecond every one to six calls and stays clear of the microsecond
wrap, where the reference hangs (F279). It draws the JEDEC ID, from the table in 85 percent of
cases, the memory-mapped flag in 10 percent, the busy reads, past three in 30 percent of programs,
the quad enable bit and the other bits of the second status register, reads the bus refuses in 15
percent of cases, and the clock, then runs 4 to 14 drawn operations, half of them near the last
write: ready checks, waits, sector and chip erases, programs of one buffer or of none to three,
reads of up to 64 bytes and geometry queries. Every bus and clock call, with the bytes of each
transfer or their hash, and the device's state after each operation of the 300 cases replay exactly.
In them 251 chips identify, 555 programs run through the bus, 206 reads start, 61 waits time out and
68 reads return nothing. Of 88 tampered paths, 82 fail the vectors and 3 stop the checker at a
subtype check. Three pass and are equivalent:

- the deadline comparison at a difference of exactly 2 ** 31 ms, which a millisecond clock under 2
  ** 23 never produces
- the clear of the deadline after a timed wait, since a deadline of zero and a passed one both read
  as timed out under that clock
- the sector count a failed identification clears, which is zero already since the geometry starts
  empty and identification runs once

## D370. OLED display driver (2026-10-19)

`Adaflight.OLED_Display` drives the UG-2864HSWEG01 display of the dashboard over I2C, 128 by 64
pixels drawn as 8 rows of 21 characters from a 5 by 7 font with a one-pixel gap, a generic over the
link's write of a control byte and a value, which the display answers or not. A command goes behind
the control byte 16#80#, a data byte behind 16#40#, and a command list stops at the first write the
display does not answer. Initialization sends the display-off command, which has to be answered,
then the 22 setup commands and a clear, and answers true after. A clear sends the normal display,
display off and horizontal addressing commands, a quick clear, then the contrast 200 and display on.
A quick clear resets the page, the start line and the column and writes 1024 zero bytes. A position
sets the page from the row and the column address from six times the column, in its low and high
halves. A character sends its five font columns and a gap byte, each combined with the format,
normal or inverse, which the reference keeps as a global nothing writes. A character below the space
or past the font's 135 glyphs sends the blank, where the reference reads past its table (finding
F280). The unit is SPARK, with the font index bounded.

The OLED oracle includes the reference driver over a stubbed I2C write that answers from a drawn
pattern over the first 64 writes of a case, with failures in 25 percent of the cases. Each process
runs one case of 4 to 12 drawn operations: the initialization, in 70 percent of the cases first,
clears, quick clears, positions and lines in the screen in 90 percent and out to 255 otherwise,
characters from the font's range and texts of up to 40 characters with bytes past 127 in 15 percent.
Every write with its control byte, value and answer, and the initialization's result of the 300
cases replay exactly: 401 initializations, 367 clears, 586 texts and 793 writes the display does not
answer. Of 31 tampered paths, 28 fail the vectors and 1 stop the checker at a subtype check. Two
pass and are equivalent: the initial result of a command list, which the first command's write
overwrites, and the operator that applies the character format, a format the reference never changes
from zero.

## D371. SX1280 radio driver (2026-10-19)

`Adaflight.SX1280` drives the SX1280 radio of the ExpressLRS SPI receiver, a generic over the busy
pin, the microsecond clock, the receiver's interrupt line, the reset and busy pins, the receiver's
SPI as a command write and a full-duplex transfer, the DMA segments the interrupt chain sends, and
the receiver's answers: whether a hop or a telemetry response is due, the hop frequency, the
telemetry assembly and packet, and the processing of a received packet into its status. Every
transfer waits for the busy pin to fall, up to a millisecond. Initialization needs the receiver's
interrupt pin, sets the 18 MHz clock, pulses the reset pin low for 50 ms and lets it float for 20
ms, reads the firmware version, which has to be neither 0 nor 65535, then sets standby on the RC
oscillator, automatic frequency synthesis and the high sensitivity gain regime. The configuration
sets the packet type, the LoRa modulation with the spreading register and packet parameters, or the
FLRC modulation and packet parameters with the CRC seed, the sync word swapped and marked for the
two coding rates that collide with it, and the sync address control masked, then the interrupt
masks, 13 dBm and the frequency. The interrupt claims the radio when it is free, stamps the time and
configures the busy interrupt, then runs a chain of DMA transfers, each started when the busy pin
reads low or when it falls, with the interrupt disabled before each transfer:

- the interrupt status read, which names the reason, with a hardware error for a FLRC packet without
  a valid sync word or with a CRC or sync error
- the clear of every interrupt
- for a received packet, the buffer address, the eight packet bytes, the packet statistics and the
  receiver's processing with the time of the receiver's last interrupt
- the hop frequency when the receiver asks for one or a hop waits
- the telemetry packet and transmission when the receiver asks for that, or the return to reception
- the receiver's interrupt enabled again and the radio freed, unless a hop still waits

A hardware error ends the chain after the clear with the radio held. The tick handler frees a radio
held past a millisecond. The tock handler starts the hop when the receiver asks or one waits. The
packet statistics give the signal strength and ratio, with the FLRC strength from the second byte
and the LoRa strength corrected by a quarter of a negative ratio, wrapping below -128 as the
reference's signed byte does (finding F281). The chain runs at most 12 steps, which the reference's
recursion never reaches. The unit is SPARK for the command bytes and the chain.

The SX1280 oracle includes the reference driver over stubs:

- a chip that answers register reads from a hash of the address, the buffer from a hash of its
  offset, the status from a drawn byte and the buffer status, packet statistics and interrupt status
  from values drawn at each interrupt step
- a busy pin answering from a pattern drawn per step over its first 16 reads
- a clock stepping 40 to 400 us per read
- the interrupt lines
- the receiver's hooks with answers drawn per step

The reference's uninitialized transfer bytes are zeroed at compile time (F281). Each process runs
one case of 6 to 24 operations: the initialization, with the interrupt pin missing in 5 percent and
the reset or busy pin missing in 20 and 10 percent, configurations with drawn parameters, FLRC in 40
percent and the colliding sync words in 30 percent, their last byte at the marking boundary of the
3/4 coding rate in 40 percent of those, modes, frequencies, powers, buffer addresses, interrupt
masks, transmissions, receptions, statistics, status reads, register writes and reads, interrupts in
20 percent of the steps, busy pin falls in 10, tick handling with the clock advanced past the
millisecond in half of them, tock handling and busy checks. Thirty more cases answer the firmware
version registers with 0xFFFF in 20 percent and 0 in 10, as a tenth init field, and while a chain
waits on the busy pin make half the steps ticks, landing exactly 1000 us after the chain's stamp in
60 percent of them. Every bus, pin, interrupt, clock and hook call, with the bytes of each transfer,
and the driver's state after each operation of the 330 cases replay exactly: 304 chips initialize,
935 interrupts arm the busy pin 257 times, 99 falls continue a chain, 277 packets are processed, 168
hops and 120 telemetry responses are sent. Of 126 tampered paths, every one fails the vectors.

## D372. SX127x radio driver (2026-10-19)

`Adaflight.SX127x` drives the SX127x radio of the ExpressLRS SPI receiver, a generic over the
receiver's SPI command helpers (a register write, a burst write, a register read and a burst read,
each with the register address as the command byte and the write bit set for a write), the reset
pin, the delay, the receiver's interrupt line and the time of its last interrupt. Initialization
needs the receiver's interrupt pin, pulses the reset pin low for 50 ms and lets it float, reads the
version register up to three times 50 ms apart for the chip's id and puts the chip to sleep through
a read, modify and write of the mode bits. The configuration writes the LoRa defaults (sleep, the
LoRa range bit, standby, the flags cleared, an 8-byte payload, the default sync word, the FIFO
bases, DIO0 on both done interrupts, the LNA boost, automatic gain, the 150 mA current limit, the
default preamble and the IQ inversion bit), then the preamble length, the maximum output power, the
spreading factor with its detection registers, the bandwidth, coding rate and CRC mode with the
errata registers for 500 kHz, and the frequency. The sync word write steps up to the next allowed
word of the 105. The bit field operations mask from the bit range and refuse ranges past bit 7. The
frequency in hertz converts in steps of 15625 over 256 (61.03515625 Hz). The frequency error
combines the three error registers as a signed 19-bit value scaled by the bandwidth's factor in
unsigned arithmetic. The correction steps the offset against the error sign, back to zero at either
bound of 1638 steps, and writes 95 percent of its parts per million as a truncated and wrapped byte
(finding F282). The signal strength subtracts 157 as a wrapped byte and the packet statistics
correct it by a quarter of a negative ratio (F282). The interrupt handler clears the receiver's
interrupt, reads and clears the flags for the reason (received, sent, both or neither) and takes the
receiver's last interrupt time when it is set. The unit is SPARK: the offset subtype bounds the
scaled correction and a nonzero frequency guards its division.

The SX127x oracle includes the reference driver over stubs: the receiver's SPI helpers logging each
command and answering reads from a hash of the address, the case's seed and the step's salt, with
the version register answering its id from a drawn read on, the reset pin, the delay and the
interrupt line. Each process runs one case of 6 to 24 operations: the initialization, with the
interrupt pin missing in 5 percent of the cases and the reset pin in 20, configurations, modes,
frequencies in hertz and in register steps, powers, preambles, spreading factors, bandwidth and
coding writes, sync words, transmissions and receptions of 1 to 16 bytes, reception starts,
bandwidth lookups with unknown codes in 20 percent, offsets and corrections at drawn offsets and
frequencies, frequency errors, statistics, interrupt flags and reasons, interrupts with the last
time set or clear, bit field reads and writes with invalid ranges in 30 percent, register writes,
reads and bursts, and the LoRa defaults. Every bus, pin and delay call with its bytes and the
results of the 4383 operations of the 300 cases replay exactly: 242 of 397 initializations find the
chip, 215 interrupts report their reason, 220 corrections step the offset and 28 lookups answer all
ones. Of 151 tampered paths, 140 fail the vectors and 8 stop the checker at a subtype check. Three
pass and are equivalent:

- the signed conversion's case at exactly 2 ** 31, which the frequency error's product shifted right
  by four never reaches
- the order of the transmit and receive flag tests, which follow the test of both flags at once
- the packet statistics' test for a negative signal to noise ratio, where a ratio of zero adds
  nothing to the strength

## D373. BMM350 compass driver (2026-10-19)

`Adaflight.BMM350` drives the BMM350 compass over I2C, a generic over the bus device: whether it is
I2C, its address, the device's registration, register reads and writes with their acknowledgement,
and millisecond and microsecond delays. Detection waits 3 ms and reads the chip identity 0x33 at the
configured address, or at 0x14 then 0x15 when none is set, leaving the address unset when neither
answers. Initialization registers the device, soft resets the chip up to three times until it
answers its identity 24 ms later, reads the 32 trim words of the one-time memory, each after its
read command completes within ten polls 300 us apart with no error bit, and parses them into the
axis and temperature offsets and sensitivities, the temperature coefficients of the offsets and
scales, the reference temperature and the cross-axis terms, all zero when the read fails. It powers
the memory off, resets the magnet through the bit and flux guide commands with the chip suspended
first, then enables the data ready interrupt, four-sample averaging at 100 Hz, the offset update,
the three axes and the normal power mode, each power command waited for in the status register up to
its timeout and the normal mode's success deciding the initialization. A read takes the twelve data
bytes behind the two dummy bytes, assembles the three axes and the temperature as 24-bit values,
scales them by the reference's single precision constants, applies the trim in the reference's order
of operations and hands over the axes in tenths of a microtesla rounded half to even and held within
16 bits. An axis whose temperature scale term makes its divisor zero keeps its class, an infinity by
the sign of its sum or an undefined value, through the cross axis terms, and reads as the limit of
its sign or as zero, as the target's conversion of the reference's result does (finding F283). The
SPARK proof bounds every intermediate from the trim subtypes and the 24-bit readings, with a nonzero
single precision divisor at least 2 ** -24.

The BMM350 oracle includes the reference driver, with the target's conversion of a float to an
integer in place of the host's (an infinity saturates at the 32-bit limits, an undefined value reads
as zero), over stubs: a chip answering each identity read, command read and status poll from drawn
tables, with the power manager busy for a drawn number of polls after each command, one status read,
one command read and one write that fail, a trim word whose read fails in one of five ways with a
single error bit, the polls a trim read takes, the 32 trim words, small in half the cases, and soft
resets that keep the power mode in 30 percent of the chips. Each process runs one case: the bus type
and preset address, the detection, the initialization and 40 to 120 reads with drawn
acknowledgements and data, small readings in 60 percent of them. Thirty more cases hold a found chip
that answers every access, busy at the suspend and bit reset limits, and busy for 22 or 23 polls
after the flux guide reset, its own count in a last init field, and a reference temperature word at
the sign boundary in half of them. Every bus, registration and delay call with its bytes, the
detection, the initialization's result and its parsed trim, and each read's result and axes of the
330 cases replay exactly: 244 chips are found, 64 at a configured address and 180 by the scan, 219
initialize, 41 of them after a failed trim read, and 18480 of 20004 reads bring axes. Of 128
tampered paths, 115 fail the vectors and 9 stop the checker at a subtype check. Four pass and are
equivalent: the last digits of the three scale constants, which single precision does not hold, and
the trim's clear before the memory read, which initialization runs once on a trim still at its
defaults.

## D374. CC2500 radio driver (2026-10-19)

`Adaflight.CC2500` contains the CC2500 radio's register access behind the SPI radio unit's
operations, a generic over the receiver's SPI helpers: a command byte with a value, a command with a
burst, a single and a burst read, a lone byte, the DMA switch and a microsecond delay. A FIFO read
takes its bytes with the FIFO address under the read burst flag. A FIFO write flushes the transmit
FIFO, sends the bytes under the write burst flag and strobes the transmission. Burst reads and
writes take the address as the caller formed it, a register read sets the single read flag, a strobe
is one byte and a register write one command. The power level selects one of eight amplifier table
bytes, levels past seven as the last, written to the table register. The reset switches DMA off,
strobes the reset, waits 1 ms and reports whether the first frequency register reads its reset value
0xC4. The unit is SPARK and holds no state.

The CC2500 oracle includes the reference helpers over stubs: the receiver's SPI helpers logging each
call and answering reads from a hash of the command byte, the case's seed and the step's salt, the
first frequency register answering its reset value in 70 percent of the steps, the DMA switch and
the delay. Each process runs one case of 10 to 30 operations drawn evenly from FIFO reads and writes
of 1 to 32 bytes, burst reads and writes of 1 to 8 bytes at drawn addresses, register reads with the
first frequency register in 20 percent, strobes, register writes, power levels past seven in 20
percent and resets. Every bus, DMA and delay call with its bytes and each operation's result of the
300 cases replay exactly: 5983 operations, 720 of them resets and 614 power levels, over 159133
logged calls. Of 36 tampered paths, every one fails the vectors.

## D375. Headfree turn of the stick commands (2026-10-24)

`Adaflight.RC_Command` contains the stick half of headfree mode. `Headfree_Vector` takes the roll
and pitch commands, and the yaw command unless a level or hold mode is on (angle, horizon, altitude
hold, position hold, GPS rescue), as an earth frame vector. The attitude's `Headfree_To_Body` (D289)
turns it into the headfree frame. `Apply_Headfree` puts the turned commands back on the sticks: roll
and pitch, and yaw outside the level and hold modes.

The turn keeps the vector's length, so it can push a command past its divider. Full roll and pitch
turned by 45 degrees put about 707 on one axis, a deflection of 1.41 where the reference states a
range of -1 to 1, and the rates then run up to twice the configured maximum or to the rate limit
(F284). When the largest ratio of a turned command to its divider passes one, `Apply_Headfree`
divides the turned commands by that ratio and holds each to its divider, so the stick direction
stays and no deflection passes one (D6). The divider is 500 less the deadband, 500 less the yaw
deadband for yaw.

The RC oracle gains headfree sequences: headfree mode in three steps of four, a level or hold mode
in one of three, and a stand-in for the turn that keeps the stick vector it is given and hands back
a turned vector drawn within 500 or 1200 per component. The turn itself is the attitude oracle's.
The reference module compiles with the same scaling. The checker gives the port's stick vector the
recorded turned vector, then replays the commands, deflections, setpoints and feedforward.
Feedforward averaging stays off in these sequences, as in the throttle sequences, since the
averaging has a declared tolerance (D6). 40 sequences of 80 steps replay exactly, 2418 of the steps
in headfree mode and 1117 of those scaled. Five tampered paths each fail the vectors.

## D376. BMI270 gyro driver (2026-10-24)

`Adaflight.MPU_Gyro.BMI270` drives the BMI270 gyro over the SPI gyro layer. The chip starts in I2C
mode, and the select pin low for 1 ms then high for 10 ms selects SPI. A register read returns one
dummy byte before the value. Detection selects SPI and reads the identity, 0x24. The gyro detection
sets the scale of 2000 degrees per second over the 16-bit count.

Initialization writes the soft reset, waits 100 ms, selects SPI again and loads the chip's
configuration file: advanced power save off, loading open, the 328 bytes to the loading register, 10
ms, loading closed. `Adaflight.BMI270_Config` contains the bytes, the configuration file of the
maximum FIFO variant from Bosch Sensortec's BMI270 Sensor API, release v2.113.0, under the
BSD-3-Clause license. `third_party/bosch-bmi270` names the source and contains the license. The
experimental filter setting then sets the FIFO for gyro frames without headers or downsampling and a
watermark of one frame. The accelerometer goes to 16 g and 800 Hz and the gyro to 2000 degrees per
second and 3.2 kHz, both in performance mode, the gyro with the oversampling of the filter setting.
The interrupt pin then signals data ready, or the FIFO watermark in the experimental setting,
push-pull and active high, and the gyro, accelerometer and temperature sensor start. The
experimental setting flushes the FIFO last. Each write waits 1 ms. Initialization then enables the
interrupt when the board has the pin and sets a 10 MHz clock. The interrupt handler is the layer's,
the chip's own with no short period.

In the experimental setting a gyro read takes the FIFO length and the first frame in one 10-byte
transfer. It keeps a whole frame unless all three words are -32768, the mark of an invalid frame,
and flushes the FIFO when bytes remain. Outside that setting the first gyro read picks the mode as
in the BMI423 driver (D363): DMA after 1000 interrupts when the bus has it, each interrupt then
starting the 14-byte read of both sensors, interrupt driven without DMA, or no interrupt. The mode
without interrupts stays, where the BMI423's returns to the first read after 1000 interrupts. The
other reads take a sensor's six bytes at byte 2 of an 8-byte transfer. The experimental setting
takes the interrupt-driven mode at initialization, so its accelerometer reads read (D6). The
reference never leaves the first mode in that setting, and its accelerometer read reports success
without reading, which leaves the accelerometer at zero (F285). The unit is SPARK, with the sample
offsets bounded by the receive buffer.

The BMI270 oracle includes the reference driver, compiled with the same mode change, and the common
SPI gyro layer over a simulated chip whose 8-bit registers read behind one dummy byte and whose FIFO
flush clears the FIFO length. It links the reference's copy of the configuration file and records
the burst as its length and CRC-32, 9fa5db37, the CRC-32 of Bosch's bytes too. It draws the bus, the
chip identity, 0x24 in 85 percent of the cases, the dummy byte, refused reads in 5 percent, the
startup clock and its step, DMA, the interrupt pin, the filter setting, past the known ones in 8
percent, the register values and, at each new sample, a FIFO length near one frame and frames of
-32768 words. It then runs the detection, the gyro and accelerometer detection and initialization,
and 30 steps of interrupts, a burst of 990 to 1050 interrupts or exactly 1000, DMA completions,
reads and new samples. Every bus, pin, clock and delay call, detection, setting and reading of the
300 cases replays exactly. In them 234 chips are found, 55 with the experimental setting and 17 with
an unknown one, and of 7020 steps 1640 read the gyro and 1380 the accelerometer. The experimental
setting's 384 gyro reads keep 181 frames, drop 27 invalid ones, find less than a frame 176 times and
flush 71 times, and its 340 accelerometer reads each make the transfer the reference skips. Outside
it the cases end 39 in DMA mode, 34 interrupt driven and 106 without interrupts, after 187 bursts,
22 of exactly 1000. Of 114 tampered paths, 113 fail the vectors and 1 stops the checker at a range
check.

## D377. STM32F4 target crate and the first image (2026-10-24)

Phase 7 starts with a target crate beside the core and the tests, `targets/stm32f4`, Alire crate
`adaflight_stm32f4`. It builds with the `gnat_arm_elf` 16.1.0 toolchain from Alire on the
`light-tasking-stm32f4` runtime, which brings the startup code, a 168 MHz system clock from the
board's 8 MHz crystal, the F405's memory map of 1 MB of flash, 128 KB of SRAM and 64 KB of CCM,
`Ada.Real_Time` and the Ravenscar tasking the drivers will use for interrupts. The crate depends on
the core by path, so the core cross-compiles for the target with every build and the generic drivers
can be instantiated with the platform's bus procedures. The core keeps no target code and the host
vector checks stay as they are.

Board data comes from the board configuration repository, a pinned submodule at
`third_party/board-configs`, through `tools/boardgen.py`: before every build it reads the board's
configuration file and writes `Adaflight.Board` into the crate's `gen/` directory, with the board,
manufacturer and MCU names, the crystal frequency, the beeper polarity and frequency, every pin
define as a `Pin` of `Adaflight.Pins` (a port letter and a number), the inverter pins and the timer
pin map. The generated package is deterministic for a given file and is not committed. `BOARD`
selects the board, CLRACINGF4 when unset, which the CLRacing F4S V1.2 and V1.4, the F4 Mini V1.2 and
the RDQ Bardwell F4 AIO V2 share. Feature defines, bus instances and DMA options are not generated
yet. The generator grows with the drivers.

`Adaflight.STM32.GPIO` overlays the GPIO port registers at their AHB1 addresses with a volatile
record, enables a port's clock in the RCC, sets a pin as a push-pull output and sets, clears or
toggles it through the bit set and reset register. It is plain Ada: the proofs that buy assurance on
the target are the DMA buffer and register bounds of the bus drivers to come. The first image sets
the board's LED pin as an output and toggles it every 500 ms with `delay until`, an image of 9960
bytes of text, 452 of data and 8960 of bss by `arm-eabi-size`, the core linked and garbage-collected
to what the image uses. `target.do` builds the image and prints its sizes, `verify.do` runs it after
the vectors, and the Target Build workflow keeps the image and its map as an artifact. The image is
flashed through the STM32 ROM bootloader over USB with `dfu-util` at the start of flash, the board
put into DFU mode by its boot button. The bench test of this milestone is the LED blinking at 1 Hz
on the F4S V1.2 after a DFU flash.

## D378. Command line terminal (2026-10-24)

`Adaflight.Command_Line.Terminal`, a child of the command line's instantiation, is the character
layer between a port and the commands. A session enters interactive or driven by a configurator and
keeps the line typed so far, up to 255 characters. An interactive entry prints the banner and the
prompt and holds arming, which stays held when the session ends. A configurator entry answers a
start of text. Each byte of a poll is taken in the reference's order. Interactive:

- a tab or a question mark completes the line over the command names as far as every matching name
  agrees, adds a space after a whole name, lists the matching names when more than one matches or
  the line is empty, and redraws the line
- control-D on an empty line closes the session with the restart line and the restart
- control-L clears the screen and prompts
- delete takes the last character back with a backspace, a space and a backspace
- any other byte goes to the common path, where a line end on a non-empty line echoes a line end,
  runs the line through `Process_Line` with the interactive flag set, clears the line and prompts
  again unless the command left the command line, and a printable character past the leading spaces
  joins the line and echoes

A line runs while the configuration's profile indices are valid, the line processor's precondition.
The configuration fix sets them at load and the profile commands keep them in range, and the
terminal checks the condition at each line since the line processor does not state it as a
postcondition. A configurator session takes the common path without echo, and closes with an end of
text at an end of text or at any byte more than two seconds after its entry, leaving the rest of the
poll's bytes. An unknown command in an interactive session gets the `###ERROR IN input: UNKNOWN
COMMAND, TRY 'HELP'###` line and the prompt, where a configurator gets `ERR_CMD_NA` with the line,
so the command line's environment has the interactive flag. The command line also names its 62
commands in the order of the reference's table, which `help` already follows and the completion
walks. The reference extends the line while its first and last matching names agree and lists every
name between them, and its table keeps `battery_profile` after `play_sound`, so a typed `b` lists 38
names of which 31 do not match and extends to `bat`. This unit walks the matching names only
(finding F286, D6). The unit is SPARK for the line buffer's bounds and the completion's walk.

The command line oracle gains terminal lines: each enters the reference's command line when it is
closed, interactive or not, with the clock at a given millisecond, hands a batch of bytes to its
poll through a stubbed port whose writes are collected like the command replies, and reports the
session's state after it. A closing line ends the session. The generator draws 600 sessions, 1275 of
them interactive, with 1739 batches of 35483 bytes: unknown words, comments, commands that print
little, tabs and question marks after prefixes of command names or on an empty line, control-L,
control-D on empty and typed lines, deletes, every line end, leading spaces, bytes outside the
printable range, lines past the buffer, and configurator batches with and without an end of text,
timed inside and past the two seconds. Every reply of the 1658 that print and every session state
replays exactly, with at most one line end per batch so the line's effects read as the command
lines' do.

## D379. STM32F4 USART1 and the command line (2026-10-26)

The second milestone of Phase 7 puts the command line on the board. `Adaflight.STM32.USART` drives
USART1 at eight data bits, no parity and one stop bit over the board's UART1 pins, PA9 and PA10 on
alternate function 7, with the APB2 clock the runtime sets, 84 MHz, and a divider rounded to the
nearest sixteenth: a blocking transmitter the command line puts its text through, and a receiver
whose interrupt keeps the bytes in a ring of 256 until the main loop takes them and drops the rest.
`Adaflight.STM32.GPIO` gains the alternate function setting with an optional pull-up.
`Adaflight.STM32.Console` instantiates the command line over the USART with the core's board step
units, since the board's DShot, flash and passthrough tools wait for their drivers, and the terminal
over it.

The image drives the UART1 inverter pin low, enters an interactive session at boot, and polls the
receiver every millisecond. The bytes go to the terminal with the millisecond clock, the uptime and
the arming hold, a session the terminal closed is entered again, and a restart request resets the
core through its reset control register. The configuration starts from the reset configuration of
`Adaflight.Config_Reset`, with no storage behind a save yet. The environment names the board and the
MCU from the generated board package, takes the build date and time from the compiler, and reads the
device's three unique identifier words. The main stack is 32 KB, set in the project's linker
switches. The LED keeps its 1 Hz blink. The bench check is a serial adapter on the UART1 pads at
115200 baud: the banner and prompt show at boot and after `exit`, which restarts the board, and the
commands reply as the host vectors record them.

## D380. MSP command processor (2026-10-26)

`Adaflight.MSP_Processor` routes one MSP command frame to the unit that answers it, in the
reference's stage order: the out replies that take an argument and read the configuration (the
command line setting and its information, the configuration reset and the restart), then the common
in messages (the transponder, the battery and its meters, the OSD and its canvas, a font character),
then the in messages. The out replies that read a snapshot of the board's state wait for the
snapshot layer. The simplified tuning write, which acts on the running profile and gyro settings,
answers an error until that layer lands. A command no unit answers is an error with an empty reply.
`Context` holds what the board reports to the messages: the control state, the gyro's sample rate,
the flight log and the PID loop time, the motors and their output device with the 3D feature, the
OSD display port and whether it took the font character, the video transmitter and its running
table, and the receiver's provider with its serial protocol. The reply's bytes go to the caller's
stream, cut to its room. The port's reply payload holds 512 bytes, so the flash read reply, which
needs 4096 more, waits for the flash layer (F269). `Effects` returns every unit's effects together
with the runtime work the reference does between the units: a PID profile change asks for the motor
output endpoints and the mixer profile again, a rate profile change for the stick processing, the
wing's tuning for the PID settings, an OSD write for the elements, and a VTX configuration write
marks the MSP transmitter ready. The configuration write and the restart that the board, control and
OSD messages ask for come back as one flag each.

The harness hands every MSP in line of the command line vectors to the processor in place of its own
routing: 23956 requests over 72 commands in 24 families replay exactly, result, reply and effects.
Four tampered paths each fail the vectors.

## D381. MSP configuration views and the out replies (2026-10-26)

`Adaflight.MSP_Views` builds the snapshots the MSP out units read from the stored configuration: the
mode conditions, adjustment ranges, channel map and failsafe channels in the runtime types the
flight tasks read, and the tuning, receiver, hardware, peripheral, serial, text, OSD and common
views, each with a record for what the board reports beside the configuration (the options built in,
the detected gyros, the motors in use, the flight log's rate values, the display and transmitter
devices, the request's port). A stored value past its runtime type leaves its entry empty: a mode or
linked box past the boxes, a function past the adjustments, a channel past the eighteen, a step past
the range, a failsafe mode past the three or an OSD profile past the three.
`Adaflight.MSP_Processor` gains the out stages in the reference's order before the in messages: the
common replies, the state and configuration replies, then the replies with an argument (the box
names and ids, the restart, several replies in one, the VTX table rows, the simplified tuning, the
configuration reset, the texts, the battery profile, the LED strip values, the command line setting
and its information) and the passthrough request, whose mode and argument come back as an effect
while its reply counts the motors for the ESC passthroughs and answers no port for the serial one. A
reply the build or the state leaves out answers an error with an empty reply. A request for several
replies measures each sub-reply in full and answers an error when one exceeds the 255 bytes its size
byte holds, where the reference wraps the size and its room accounting (finding F288, declared in
D6). The reply room is the MSP port's 512-byte payload. The reference's buffer holds 4112 bytes with
the flash file system, whose read reply waits for the flash layer (F269). The VTX configuration and
table replies mark the MSP transmitter ready.

The command line oracle gains out reply lines: each runs one command through the reference's
dispatch over the configuration the set lines built, with the reply room cut to 512 bytes and the
sub-reply check of F288 in its fixed copy, and prints the runtime values the reply read (the motor
count, the channel count, the detected gyro flags, the DShot telemetry use, the log rate values and
the transmitter state) before the result and the reply bytes. The generator draws 1200 lines in two
runs: settings of every group, profile selections, motor, gyro flag, serial port, transmitter and
build key directives, and 718 requests over 61 commands with their arguments, several replies in
one, passthrough modes and unknown commands. Every result and every one of the 19953 reply bytes
replays exactly, and the MSP in and bind families replay unchanged through the extended processor.
Five tampered paths each fail the vectors.

## D382. STM32F4 MSP on UART1 (2026-10-26)

The STM32F4 image serves MSP on UART1 beside the command line. The main owns an MSP port (D53) and
polls the receiver ring every millisecond: while the command line's session is closed the bytes go
to the port, which hands each complete command frame to the MSP command processor (D380, D381) with
a context built from the board, and the reply goes out as a frame in the request's framing through a
byte transmitter the USART driver gains. A hash mark opens an interactive command line session after
the port's guard time and a start of text a configurator session at once. While the session is open
the bytes go to the terminal (D378), and when it closes the port takes them again. A reboot request
on the port, a restart a message asks for and the command line's `exit` reset the core through its
reset register after the reply. The context names the firmware variant (D384), the
version as 2026.10.0 with the text 0.1.0, the compilation date and time, the microcontroller and
board names, the manufacturer, the device identifier words, the board identifier and configuration
state from the configuration, the MAX7456 and beeper built in, UART1 as the one serial port, and no
sensors, motors, meters or devices yet. The state replies read zeros until the sensor tasks run on
the board.

The image left the development profile: with the eighteen MSP in units and the out units linked at
the debug optimization level with validity checks, it overflowed the 1 MB flash by 155 KB. The core
now builds for the board in its release profile, optimized for size without run-time checks,
assertions or debug information, which the proof makes safe. The target sources keep their checks.
The host checks build the core in the validation profile, with its checks on. The image is 777232
bytes of text, 1672 of data and 83424 of zeroed data. The bench check is a serial adapter on the
UART1 pads at 115200 baud with the configurator connecting, reading the setup, PID, receiver, modes,
OSD and ports tabs and writing a setting, and the command line still entering with a hash mark.

## D383. STM32F4 gyro over SPI1 (2026-10-26)

The STM32F4 image starts the board's gyro at boot and reads it every millisecond. `Adaflight.STM32.SPI`
drives SPI1 as a master in mode 3 with eight-bit frames, most significant bit first, the select pins
left to the devices: a polled full duplex transfer, and the clock divisor as the smallest power of two
from 2 to 256 that brings the 84 MHz bus clock to the asked rate or below, so detection at 1 MHz runs
at 656 kHz and the MPU6000's 20 MHz reads run at 10.5 MHz. `Adaflight.STM32.EXTI` arms a pin's
external interrupt line on its rising edge and clears its pending flag. `Adaflight.STM32.Time` holds
the millisecond clock, the core's cycle counter for the microsecond delays and the layer's interrupt
times, and the millisecond delay. `Adaflight.STM32.Gyro` instantiates the SPI gyro layer (D324) over
a device of the select pin, the data ready line and the receive bytes, with the MPU6000 (D325) and
MPU6500 (D327) drivers as its two chip probes in that order, the bus never in DMA mode, and a
protected handler on the data ready line's interrupt that counts and times each sample through the
layer. Its start runs the layer's preinitialization and detection, names the gyro hardware through
the gyro detection (D334), takes the chip driver's scale, the sample rates of the gyro start (D332)
and the driver's initialization, then the accelerometer detection over the same chip. The main brings
the result through the gyro selection (D294) over the one position and the configuration's gyro
checks, and into the state the replies read: the status sensor flags, the detected flags, the active
sensor hardware, the raw readings reply with the gyro as counts and the accelerometer divided by the
count for one g, and the status report's gyro and accelerometer lines with the interrupt mode. A
missing gyro flashes its failure code twice on a configured board and holds arming on the no-gyro
flag. A failed initialization read flashes its code ten times and resets the core, where the
reference's release build requests the bootloader, which the image has no request path for yet.

The first read waits 250 ms after the start so the interrupt count passes the layer's detection
threshold and the reads run locked to the interrupt. The reads stay in the main loop until the
scheduler takes the sensor tasks. The image is 785076 bytes of text, 1768 of data and 83472 of zeroed
data. The bench check is the configurator's sensors tab showing the gyro and accelerometer traces
following the board, and the command line's `status` naming the gyro and accelerometer with the gyro
locked.

## D384. Firmware variant (2026-10-26)

The image answers the firmware variant `ADFL` in the variant reply, its own name beside the version
numbering of D382 and the image layout of D6. The stock configurator accepts one variant at connect
and opens its command line tab alone for any other, so the full tabs need its variant check widened
to `ADFL`: three string comparisons in its source, at the connect gate, the command line completion
and the build information read. That build is the adaflight-configurator repository, the upstream
configurator's history with adaflight's changes on its main branch. The bench check moves to it.

## D385. STM32F4 scheduler and sensor tasks (2026-10-26)

The STM32F4 image runs the scheduler (D38) in place of its millisecond loop.
`Adaflight.STM32.Flight` holds the board's flight software: the configuration, the MSP context and
the command line environment, the gyro filters (D26), the accelerometer and the attitude estimate
with their settings from the configuration (D187), the scheduler with its settings, and the core
loop's cadence (D190). The start runs the gyro's start (D383), the configuration's gyro checks, the
loop ratio from the PID loop setting, the gyro filters at the gyro's sample period with its scale,
the accelerometer at its sample rate and count for one g, the attitude estimate, the gyro
calibration, and after the data ready wait the task setup (D160) over the tasks the image serves:
the system load, the main and serial tasks, the realtime gyro, filter and PID tasks, the
accelerometer and attitude tasks, and the receiver task, whose check finds no frames yet. The pass
takes the scheduler's phases as the harness does, with the clock from the runtime at cycle
resolution and the core's cycle counter. The realtime block runs at the gyro's target: the gyro task
reads the sensor into the filters' accumulation and the cadence, the filter task runs when the
cadence says so, the PID task's slot stays empty until the control loop reaches the board, the
failsafe check is marked, and the gyro lock reads the interrupt count, the sync cycles and the
chip's short period. The selection over the queue, the held task's run and the pass's end follow.
The serial task is the MSP port and the command line of D382, evaluating the other data while
disarmed, and reads the PID loop's delta and the system load into the status reply first. The task
functions (D192) take the serial and accelerometer tasks and no step for the units the board has no
driver for. The attitude task takes the filters' attitude lowpass and the accelerometer without a
compass, disarmed and without the angle or headfree modes. The raw readings reply takes the filtered
rates as counts and the calibrated accelerometer over the one g divisor. The attitude replies take
the angles and the quaternion.

The image is 825352 bytes of text, 3512 of data and 105448 of zeroed data. The yaw spin recovery
waits for the receiver's rates setup, the RPM notches for the motors and the calibration tone for
the beeper. The bench check is the command line's `tasks` listing the running tasks with their
rates and times, `status` with the system load and the gyro locked, and the configurator's setup
tab following the board's attitude.


## D386. STM32F4 configuration store in flash (2026-10-26)

The STM32F4 image keeps its configuration in the internal flash. `Adaflight.STM32.Flash` reads the
first 8 KB of the last sector, 128 KB at 16#080E_0000#, in place, and writes an image by unlocking
the controller, erasing the sector, programming 32-bit words and resetting the data cache. The image
of the core ends below that sector. At boot the main checks the region's structure (D158) and resets
the store when it is invalid, then loads every group from its defaults and its stored bytes through
the codec, takes the running features from the stored ones, runs the configuration's checks (D167)
over the hardware the board knows, takes the board's information in (D183), and resets the store
again when a group was missing, the stored version is not the core's or the identifier is another
board's. A reset writes the defaults and reads them back. A write runs the checks, encodes the
groups and saves the image when any group changed since its hash was taken, programs it and checks
the region's structure and version back, in up to three attempts. A store that still fails flashes
its code and resets the core. A message's write request ignores the pass's time for the scheduler,
writes and reads back before the reply, and the command line's `save` writes before its restart. The
core's own group layout keeps a reference image from loading (D158), so a board that ran the
reference starts from defaults.

The image is 838900 bytes of text, 3924 of data and 105832 of zeroed data. The bench check is a
setting written from the configurator or the command line surviving a power cycle, and `status`
reporting the configuration configured after a `save`.

Amended 2026-10-26: the store moved to sector 1, 16 KB at 16#0800_4000#, with the flash layout of
D389.

## D387. STM32F4 serial receiver link (2026-10-26)

The STM32F4 image takes a CRSF receiver on the serial port the stored configuration assigns.
`Adaflight.STM32.USART` now drives the four UARTs the board family brings out, USART1 and USART6 on
the 84 MHz bus and USART3 and UART4 on the 42 MHz bus, each with a blocking transmitter and a
receiver whose interrupt keeps the bytes with their arrival times in a ring of 256, so a protocol
sees each byte at the time it came in. `Adaflight.STM32.Radio` is the receiver link: at boot it
takes the receiver settings (D40) and the failsafe settings from the configuration, finds the port
with the serial receiver function through the serial feature map (D155) when the serial receiver
feature is on and the provider is CRSF, starts the receiver with the protocol's RSSI and link
quality claims, puts the arm switch's channel just outside its range, and opens the port at 420000
baud with the CRSF protocol (D42). An inverted or half-duplex port setting and the other serial
protocols leave the link closed until their drivers land. After the realtime tasks of each pass the
link feeds the received bytes to the protocol at their times, polls the frame status while the
receiver task is not past its check, and runs the receiver's frame check with the time since the
task last ran. At the ten millisecond mark the failsafe checks its data failure period and runs its
state machine, disarmed. The receiver task runs its state machine (D123) with the scheduler's rate
ignored on every step but the last. The check step calculates the channels and tells the failsafe
what the data was worth, then updates the RSSI and starts the failsafe's monitoring once five
seconds have passed. The modes and update steps stay empty until the modes and the arming reach the
board. The task's check function is the receiver's. The channels go into the RC reply, so the
configurator's receiver tab follows the sticks. The protocol's requests for telemetry, device
information, display port and MSP frames wait for the telemetry link.

The image is 849196 bytes of text, 4620 of data and 111984 of zeroed data. The bench check is a
CRSF receiver on UART3 assigned the serial receiver function in the ports tab, with the receiver tab
following the sticks and `status` reporting the receiver signal.

## D388. STM32F4 arming logic and modes (2026-10-26)

The STM32F4 image runs the arming logic (D24), the modes and the RC commands on the receiver task.
`Adaflight.STM32.Pilot` holds their states and settings from the stored configuration over the
selected PID and rate profiles (D187), with the sensors detected, the gyro's sample period and loop
ratio and a CRSF receiver as the facts beside it, and reads the settings again when a stick command
or the command line selects a profile and the mode conditions again when a message or the command
line changes them. The receiver task's check step, once the channels were processed, tracks the
frame rate for the RC command smoothing and runs the arming's receiver pass. The modes step runs the
arming's modes pass over the auxiliary channels with the task's delta time. The update step runs the
RC commands and the arming status (D123). What the arming logic senses comes from the board before
each step: the link and the failsafe, the attitude within the small angle once established, the
calibrations, the scheduler's late share, the filtered rates, the stick deflections and the command
line. No motor protocol runs yet, so arming stays disabled by that reason until the motors reach the
board. What the passes ask, the board serves: the gyro and accelerometer calibrations, the profile
selections, the trims and the saves, the first arming calibration, the headfree offset, the
failsafe's monitoring, which left the receiver link for this output, and the attitude task's rate
with the level modes. The adjustments, the beeper, the DShot commands, the statistics, the telemetry
ports and the VTX wait for their units on the board. The replies take the disable reasons, the
flight mode flags, the active boxes and the armed flag, and a message's disarm, accelerometer
calibration and mode change requests reach the units.

The image is 881216 bytes of text, 4628 of data and 114512 of zeroed data, 35 KB below the
configuration sector, which the next pieces will want moved (D386). The bench check is the
configurator's modes tab following a switch, `status` listing the arming disable reasons, and the
stick commands calibrating the gyro.

## D389. STM32F4 flash layout (2026-10-26)

The STM32F4 image lays out the flash of the F405 with the vector table alone in sector 0, sector 1
kept for the configuration store, and the code from sector 2 at 16#0800_8000#. The crate's linker
script is the runtime's section script with its memory map inlined and the vector table in a region
of its own, and the crate takes the runtime's `USER` loader setting so the runtime adds no script of
its own. The store (D386) moves from the last sector to sector 1, which erases in a fraction of the
time of a 128 KB sector, and the image gains the 128 KB the store took: it now ends 131 KB below the
flash's end. Flashing writes two files, the vector table at the flash's start and the code from
sector 2, so the stored configuration survives a new image.

## D390. STM32F4 control loop (2026-10-26)

The STM32F4 image runs the rate controller and the mixer on the PID task. `Adaflight.STM32.Control`
holds their states with the settings from the stored configuration over the selected profiles: the
mixer's configuration with its mode, table and output range (D159), the RPM limiter and the dynamic
idle without motor telemetry, and the controller from the PID profile with the loop's runtime
constants. It instantiates the PID loop pass (D191) over the yaw reset, the RC command, the
controller with the runaway check, and the mix. The launch wing, the PID audio, the servos, the
motors and the flight log take no step until their drivers reach the board. The pass reads the
arming and the modes, the filtered rates with the gyro's overflow and yaw spin detections, the
attitude with the accelerometer trims, the tilt and the throttle correction, the accelerometer's
jerk, the receiver's throttle channel, the failsafe and the 3D switch. The yaw command resets before
the RC command while the sticks arm at low throttle (D190). The controller's landing check reads the
mixer's RC throttle from the pass before. The arming's receiver pass sets the stabilisation and the
zero throttle I term reset, its modes pass the anti-gravity, and its controller pass runs the
runaway check over the controller's sums, with a disarm the board applies. A new throttle step in the
mixer moves the gyro's dynamic first lowpass on the board beside the controller's D term lowpass in
the mixer. The motor reply holds the mixer's outputs and reports zeros while no motor protocol
enables the motors.

The image is 918508 bytes of text, 4660 of data and 116680 of zeroed data. The bench check is the
command line's `tasks` listing the PID task at the gyro's loop rate with its time, and `status`
reporting the load.

## D391. STM32F4 battery meters (2026-10-26)

The STM32F4 image measures the battery. `Adaflight.STM32.ADC` drives ADC1 at a 10.5 MHz clock: a pin
in analog mode, and one conversion of its channel on request with 12 bits after 480 sample cycles,
about 47 microseconds. The reference scans its channels continuously into memory and reads the
latest sample, and a conversion at the read gives the same value without the scan. The board's
battery voltage, current and RSSI pins take their channels at boot, before the sensors start. After
the receiver the battery unit (D22, D136) starts with its settings from the stored battery, voltage
sensor, current sensor and selected battery profile groups, which each battery task reads again, as
the stored values may change while the board runs. The voltage task takes the battery voltage
channel's sample, the current task the current channel's with its time, and both read the arming,
the throttle status with the motor stop feature and the mixer's throttle for the virtual meter. The
alerts task runs the battery's presence check while disarmed, its states and no alarm, since the
board has no beeper yet (D192). A battery's connection selects the PID profile for the detected cells
while disarmed and resets the mixer's RPM limiter (D277). A channel that is off reads zero. The
receiver's check step reads the RSSI channel when the RSSI comes from the analog input.

The analog and battery replies take the display voltage, the charge drawn, the current, the cells,
the capacity, the overall state and the receiver's RSSI. The voltage meter reply lists the battery
meter, and the current meter reply lists the battery, virtual and MSP meters, with the configured
source's readings at its id. The status report's battery line takes the voltage, the cells and the
state. The low voltage cutoff reaches the RC commands, and the display voltage, the sag-filtered
cell voltage and the latest voltage reach the mixer. The task setup enables the voltage and current
tasks with their meters and the alerts task with an alert, at 200 Hz for the voltage with the sag
compensation. The task functions now read the arming flag, which the serial task needs to stop
evaluating other data while armed.

The image is 924664 bytes of text, 4764 of data and 116816 of zeroed data. The bench check is the
configurator's power tab showing the battery voltage within a few hundredths of a volt of a meter
across the pads, and `status` with the battery line.

## D392. Board hardware defaults (2026-10-26)

The configuration reset takes the board's hardware defaults. `Adaflight.Board_Info.State` contains a
record of them, which `Board_Info.Reset_Config` writes into the reset configuration after the
board's information: the battery voltage, current, RSSI and external analog inputs with their pin
tags, the beeper's pin, inversion and PWM frequency with the open drain output for a beeper that is
not inverted, the battery's voltage and current meter sources, and the voltage and current meters'
scales. The record's own values are the host build's, which names none of this hardware, so every
recorded vector keeps its values. The boot reset, the command line's `defaults` and the reset
message reach the hardware defaults through the board state the target holds.

`tools/boardgen.py` writes the pin tags of the inputs and the beeper, zero for none, and the meter
defaults from the board's configuration file, with no voltage meter, the virtual current meter and
the scales 110 and 400 where the file names none. For the CLRacing F4S the tags are 36, 50, 49 and
51 for B04, C02, C01 and C03, both meters read the ADC and the current scale is 250, matching a dump
of the board under Betaflight. The STM32F4 image builds the record from the board package and reads
its analog inputs through the configured pin tags, so a `resource` change takes effect at the next
boot. The battery meters of D391 read zero on a configuration from the host defaults, which this
entry corrects.

## D393. STM32F4 beeper (2026-10-26)

The STM32F4 image drives the beeper (D39). `Adaflight.STM32.Sound` takes the stored beeper device
settings at boot: at frequency zero a pin driven high or low, high when on for an inverted beeper and
low when on otherwise, with an open drain output when set, and at a frequency a square wave from the
pin's timer channel at half duty. For the CLRacing F4S that is TIM3 channel 1 on B04 at 3800 Hz, a 1
MHz count to 263 with the channel's compare at 131 when on and at zero when off (D392). A pin without
a channel the driver knows stays silent. The beeper task runs the unit's update at 100 Hz, sets the
output to the beeper's state and tells the scheduler when the update was short. The beeper settings
come from the stored beeper group at every use. The beeper reads the battery's presence, the beeper
boxes, the motors running while armed, the failsafe's link, the last disarm and a waiting arming,
with no USB, configurator link or GPS on this image.

The requests come from the units that make them: the arming logic's last request of each pass with
its count, a stick save's confirmation beep after the write and the read back, the battery alarm
while the voltage alerts are on, the end of the gyro calibration, and the failsafe's lost link
tones. After the sensors start, the LED flashes ten times with a 25 ms beep each, unless the system
init sound is off. The task setup enables the beeper task.

The image is 932688 bytes of text, 5068 of data and 116840 of zeroed data. The bench check is the
boot beeps, the arming tones and the battery alarm on a supply below the warning voltage.

## D394. STM32F4 accelerometer calibration store (2026-10-26)

A finished accelerometer calibration reaches the stored configuration. When the accelerometer's
calibration count reaches zero after its 400 samples, or its in-flight calibration saves, the image
writes the offsets into the accelerometer group, marks the calibration complete and resets the level
trims, then writes the configuration, reads it back and confirms with one beep (D386, D393). The end
of an in-flight measurement sounds the calibration tone. Before this a calibration from the sticks or
a message ran in memory and was lost at the next boot, and the stored calibration flag the arming
logic reads stayed clear.

The image is 932692 bytes of text, 5068 of data and 116840 of zeroed data. The bench check is a
calibration from the sticks with the board level, one confirmation beep, and the offsets in `dump`
after a power cycle.

## D395. STM32F4 failsafe inputs (2026-10-26)

The failsafe on the STM32F4 image reads the board in flight. Its check at the ten millisecond mark of
the realtime block takes the arming, the failsafe box, the throttle status and the controller's
crash recovery, with no configurator link and no autopilot on this image (D18, D387). A disarm that
its landed stage asks for reaches the arming logic with the failsafe as the reason. Its flight mode
reaches the arming logic's flight mode flags with a confirmation beep when it changes, so the flight
mode reply reports it. Before this the check read a record that was always disarmed and its disarm
went nowhere, which no motor output could act on yet.

The image is 933236 bytes of text, 5068 of data and 116840 of zeroed data. The bench check is the
receiver switched off while disarmed, with the lost link tones and the failsafe flight mode in the
modes tab.

## D396. Host target (2026-10-26)

`targets/host` builds the STM32F4 image's flight software as a Linux program. The crate compiles the
STM32F4 integration sources unchanged and gives the board's hardware packages host bodies through
its project file. Each UART is a TCP server on port 5760 plus its number, one client at a time. The
configuration store is an 8192 byte region loaded at start from `adaflight-eeprom.bin` in the
working directory, or from the file the environment variable `ADAFLIGHT_EEPROM` names, and written
back at each save. A reset ends the process with exit status zero. The gyro and the accelerometer
are the virtual sensors at 1 kHz, reading zero rates and one g on the vertical axis. Time comes from
the host's monotonic clock, with a cycle count at the board's 168 MHz derived from it. The pins, the
external interrupts and the beeper do nothing, SPI reads 16#FF# and the ADC reads zero. The core
builds in its validation profile with its checks and contracts on. The MCU's unique identifier and
reset moved from the flight package into `Adaflight.STM32.MCU`, so the host gives its own.

We added the host target to run the board integration on every push without a board. `host.do`
builds the image and runs `tools/host-smoke.py`, which starts it with an empty store and checks over
UART1: the MSP API version, the firmware variant and the sensor status, the command line's entry,
the arming flags of `status` and the task list of `tasks`, then a `set` and a `save`, which ends the
process. The script starts the image again and reads the value back from the stored configuration.
`verify.do` and the target workflow run the gate. A configurator connects at `tcp://localhost:5761`.

The first runs found two faults in the STM32F4 integration, which this change fixes. The receiver's
frame check ran only while a serial receiver was open, so with no receiver the receiver task never
ran and the arming status it computes stayed empty (D387). The arming reasons that other units
decide never reached the arming state: the receiver loss and the active failsafe, the command line's
hold, the arming block set over MSP, and the missing gyro (D388). The flight package now sets the
failsafe's two and the command line's hold before the receiver task and after the failsafe check,
the MSP block when its message arrives, and the missing gyro at start. The STM32F4 image is 933744
bytes of text, 5068 of data and 116848 of zeroed data.

Betaflight's SITL target exchanges sensor values and motor outputs with a physics simulator over
UDP. The host target has no simulator link yet.

## D397. OSD canvas fit (2026-10-26)

`Adaflight.OSD_Canvas.Fit` runs as the OSD's display starts. It sets the stored canvas to the
display's columns and rows, and moves an element placed past the last column or row onto it, with
the element's profile and variant bits kept. A display that reports no columns or no rows changes
nothing.

We proved the fit because every element's position comes from the stored configuration, which a
command or a message can set to any value, and the draw cycle places text at those positions. The
postcondition states that after a fit to a display with a size, the stored canvas is the display's
and every element's column and row lie on it.

The osdcanvas vectors replay 400 inits from a host build with OSD profiles on, as a board build has
them: stored canvases and positions drawn at random, then the sizes of PAL, NTSC and HD displays,
zero sizes and random sizes.

## D398. STM32F4 OSD chip (2026-10-26)

The STM32F4 image drives the three SPI buses of the STM32F405 and starts the MAX7456 OSD chip on its
configured bus. `Adaflight.STM32.SPI` takes the bus with each call. SPI2 and SPI3 run from a bus
clock of 42 MHz, so a divisor computed for 84 MHz is halved on them, and a device gets the same SPI
clock for the same divisor on every bus. The buses start before the gyro, after the OSD chip's
select pin is held as an input with its pull up, or driven high when the configuration asks for it.

The configuration reset takes the OSD chip's select pin and bus from the board (D392). For the
CLRacing F4S that is the tag 31 for A15 and SPI3, so `resource OSD_CS 1 A15` and
`max7456_spi_bus = 3` match a dump of the board under Betaflight.

With the OSD feature on and the display device setting at AUTO or MAX7456, the image starts the chip
and its display port after the battery, and fits the stored canvas to the display (D397). A chip
that does not answer leaves the port in place for a later start. A display device setting of MSP,
FRSKYOSD or FBOSD starts no display on this image, and the OSD feature stays off until the next
start. The OSD configuration reply reports the chip and its readiness, starting a chip that did not
answer first, and a font character write goes to the chip's character memory once the chip answered.
The command line's `status` names the display with its columns and rows. Nothing draws on the
display yet.

The defaults stay those of a Betaflight build with HD OSD support, the display device MSP and a
canvas of 53 by 20. The analog OSD on a board needs `osd_displayport_device` at AUTO or MAX7456.

The host target models the chip on SPI3 (D396): register writes and reads in pairs, the display
memory with its automatic increment, the character memory with its write and read commands, the
reset bit, the insertion register's default and a PAL signal. The host smoke check turns the OSD on
with the MAX7456 as its display, then after the restart reads the OSD flags with the chip found,
writes a font character and reads the display in `status`.

The image is 938848 bytes of text, 5084 of data and 118624 of zeroed data. The bench check is the
configurator's OSD tab showing the chip, and a font upload.

## D399. STM32F4 OSD task (2026-10-26)

The OSD task runs on the STM32F4 image at the stored frame rate over the MAX7456 display port
(D398). The flight hands the task its readings before each state: the arming with its reasons, the
failsafe, the arm, OSD and crash flip boxes, the flight modes, the attitude in decidegrees, the
acceleration in g, the throttle and the sticks, the RSSI, the battery in centivolts, centiamps and
milliamp hours with its state, the motors with their outputs, and the profile indexes. The task's
settings come from the stored configuration at start and again after an OSD message changes the
elements or the profile, which also analyzes the elements again. The craft name goes into the task's
own buffer, which the draw reads.

The display's answers for a state come from the display port before the state runs: the readiness in
the init state, the heartbeat before the heartbeat state, and a draw before the transfer state. The
state's operations then go to the chip: a clear, a string, a character, a layer selection, a layer
copy and a redraw. Transactions, system elements and background redraws are nothing on this chip.
The task reads its clock as an input, so a state's clock reading is its start plus the time the same
state took on its last run, and an element draw's end is its start plus the last draw's time.

The GPS, barometer, link quality, ESC, blackbox, video transmitter and clock readings stay at their
defaults, and no menu grabs the display yet.

The host target's chip model writes the display memory to a text file after a change, at most ten
times a second, sixteen lines of thirty characters with a dot for a code outside printable ASCII, in
the file the environment variable `ADAFLIGHT_OSD_SCREEN` names, `adaflight-osd.txt` in the working
directory when unset. The host smoke check sets a craft name and its element, and after the restart
finds the name on the screen once the boot screen has passed.

The image is 990468 bytes of text, 5172 of data and 123456 of zeroed data. Text and data fill 995640
of the 1015808 bytes of the code region, so 20168 bytes remain for the motors and the rest. The
bench check is a monitor on the board's video output showing the boot logo and version, then the
craft name and the elements the configuration places.

## D400. Settings table in flash (2026-10-26)

`Adaflight.Settings_Table.Infos` is the table of every setting's kind, scope, mode, limits, lookup
table, count and group, generated from the settings oracle. Its aggregate left the count, the
length, the lookup table and the write-once flag to the record's defaults with `others => <>`, which
the compiler builds at elaboration: 37872 bytes of RAM and 33150 bytes of elaboration code in the
STM32F4 image. The generator now gives every component, so the aggregate is static and the table is
read-only data in flash.

The record is packed, with the count and the shortest length in a byte and the group in two bytes:
15 bytes per setting instead of 48, 11835 bytes for the 789 settings. The clients read the record
into a local and take its fields, unchanged.

On the STM32F4 image the change moves 37872 bytes from RAM to flash and takes 20932 bytes from the
text: 969536 bytes of text, 5172 of data and 85584 of zeroed data, 974708 of the 1015808 bytes of
the code region. The settings vectors and every command line family replay unchanged.

## D401. STM32F4 OSD link readings (2026-10-26)

The OSD on the STM32F4 image reads the receiver link (D387, D399): the RSSI as the receiver's
percentage, the RSSI in dBm, the signal to noise ratio, the link quality raw and as a percentage
with its source, the RF mode and the uplink power, from the receiver state the CRSF link statistics
fill. The page's link quality source, the statistics, the alarms, the elements and the warnings take
them. Before this the link elements showed their defaults and the link quality alarm compared zero
against its threshold.

The image is 970560 bytes of text, 5172 of data and 85584 of zeroed data. The bench check is the
link quality and RSSI dBm elements following the transmitter's distance.

## D402. Board image without assertions (2026-10-26)

The core's project file appended `-gnata` to the compiler switches of every build profile, so the
board image, with the core in its release profile, still evaluated every precondition, postcondition
and assertion and compiled every ghost entity: 1387 ghost routines of 178454 bytes, plus the
contract code inside each subprogram, in an image of 970560 bytes of text. The project files of the
core and of the STM32F4 crate now add the switch in every profile but release.

The STM32F4 crate builds in its release profile as well: for size, without contracts and without
debug information, with the language's run-time checks kept in the target's own sources, which are
not proved. The host target and the tests keep the validation profile with its checks and contracts.

The image is 526584 bytes of text, 5172 of data and 85584 of zeroed data: 531756 of the 1015808
bytes of the code region.

## D403. STM32F4 menu system (2026-10-26)

The menu system runs on the STM32F4 image over the OSD display (D398). `Adaflight.STM32.Menu`
instantiates the menu navigation over the menu content's target, with the display's actions and
writes on the MAX7456 display port: the grab and release, the clear, the layer and background
selection, the redraw while disarmed and the heartbeat. The menu task runs at 20 Hz with the sticks
from the RC command channels, the aux channels for the RC preview, the arming, the paralyze and
stick command boxes, the sensors with their calibrations, the loop rate and the running features.
The stick gesture opens the quick menu, or the main menu when the setting asks for it, and the menu
holds arming while open.

The menus edit the target's copy of the configuration: the live configuration goes into it on every
pass while the menu is closed and comes back out while it is open, so an edit takes effect at once
and a save writes it. After each pass the flight carries out the menu's requests: the accelerometer
and gyro calibrations, the OSD's elements analyzed again, the OSD, PID and rate profiles changed to
the ones asked for, the configuration written, and the reset. The requests for a flash erase, the
mass storage, the LED strip, the gate, a charge restore and the motor endpoints have nothing to act
on yet, and the VTX menus find no device. The OSD task waits while the menu holds the display.

The navigation's state and the target, 26440 bytes, live in the core coupled memory through a linker
section, since the main RAM has no room for them. The image is 592496 bytes of text, 5276 of data,
109480 of zeroed data in the main RAM and 26440 in the core coupled memory. The host smoke check
feeds the stick gesture through the receiver stream and finds the quick menu on the screen with the
menu's arming hold in the status.

## D404. Menu content table in flash (2026-10-26)

`Adaflight.Menu_Content.Empty_Table`, the table of 192 label lines a menu loads before its own
lines, was built at elaboration: its aggregate called `Code` for the flags and left the other
components to their defaults, and an `others` aggregate of that size is expanded at run time unless
the unit asks for static elaboration. The aggregate now gives every component as a literal and the
body holds `pragma Static_Elaboration_Desired`, so the table is read-only data in flash.

On the STM32F4 image the change moves 18436 bytes from the main RAM to flash: 610936 bytes of text,
5276 of data, 91040 of zeroed data in the main RAM and 26440 in the core coupled memory. The menu
vectors replay unchanged.

## D405. STM32F4 GPS link (2026-10-26)

The STM32F4 image reads a GPS module on a UART. `Adaflight.STM32.GPS` finds the serial port with the
GPS function when the GPS feature is on, opens it at the link's rate and runs the GPS link (D387 for
the receiver's port lookup): the bytes received go through the link each run of the GPS task, the
bytes the link asks for go out, a rate change reopens the port, and the task runs at 1 kHz while the
link asks for the fast rate and at 100 Hz otherwise. The ready beep sounds on the first fix with
enough satellites. The board has no real time clock, so the link never sets one.

The readings reach the arming logic as the fix and the satellite count, the beeper as the GPS
feature and the fix, the OSD as the fix flags, position, speeds, dilution, home vector and distance
flown with the rescue's satellite minimum, the raw and computed GPS replies with the satellite list,
the status reply's GPS sensor flag, and the command line's `status` with the link's state, platform,
port rate, solution, time and satellite signals. The GPS rescue, the altitude and position holds and
the lap timer stay off this image.

The host smoke check assigns UART4 to the GPS with the NMEA provider, feeds GGA and RMC sentences
with a fix on its port at 5 Hz after the restart, and finds the fix, ten satellites and the position
in the raw GPS reply and the link connected in the status. The image is 623400 bytes of text, 5284
of data and 118640 of zeroed data. The bench check is a module on UART4 with the satellites in the
configurator's GPS tab.

## D406. Flight log header information (2026-10-26)

`Adaflight.Blackbox_Info.Sysinfo_Of` fills the flight log header's system information from the
stored configuration and the runtime's facts: each of the 262 values as the reference's line reads
it, from the active PID, rate and battery profiles and the groups, with a 32-bit word printed as the
reference prints it, the accelerometer lowpass in hundredths, and the wing and multirotor lines of
the other build at zero. The facts are what the header reads outside the stored configuration: the
recorder's intervals, the motor output range, the accelerometer's count for one g, the battery
reference, the loop time, the PID denominator, the DShot telemetry flag, the RC smoothing filter's
settings, axis and running cutoffs, the receiver's rate, the debug mode, the device identifier and
the build's texts. The craft name comes from the configuration and the debug mode's name from the
settings' table, UNKNOWN past it.

The bbinfo vectors come from the header oracle's random fields, 200 configurations, each field
reported with its setting name so the harness writes it through the settings layer before the
mapping runs. Four fields have no setting in that build and are written to their groups directly:
the gyro enable mask, the feature flags, the disabled field mask, and the TPA curve's five values.
The level feedforward's setting is a byte, so the oracle draws it within one.

## D407. Board image with link-time optimization (2026-10-26)

The board image compiles the core and the STM32F4 sources for link-time optimization, so the linker
optimizes the image as one program and drops the code and data no call reaches. The objects keep
their machine code beside the optimizer's form. The board links the core from an archive, and an
archive member with the optimizer's form alone leaves the binder's calls to the elaboration
procedures unresolved.

Trial builds of the D405 image compared the build modes. Compiling for `-Oz` in place of `-Os`
changed no byte, and dropping the cross-unit inlining switch added 512 bytes. Link-time optimization
took the image from 623400 bytes of text and 5284 of data to 601924 and 2380. It is the first step
toward the boards with 512 KB of flash, which need the rest from the tables the port writes as code.
The host target and the tests keep their profiles without it.

## D408. USB virtual serial port (2026-10-26)

`Adaflight.USB_VCP` contains the board's USB device as a virtual serial port, from the device library and the
communications class the reference builds for the F4: the standard requests on the control endpoint with
their transfer stages, the descriptors, the class's line coding and command requests, and the two buffers
between the host and the flight software, with a transmit started every sixteenth frame. The controller stays
with the target. Each event, a bus reset, a setup packet, an OUT packet, an IN transfer done, a frame, a
suspend or a resume, returns the endpoint operations it asks for in their order, and the target's driver
carries them out.

The device keeps the reference's vendor and product identifiers, so a host's serial driver binds to it, and
names Adaflight as its manufacturer and in its product name beside the board's name.

Five corrections differ from the reference (DIVERGENCES.md). A standard request that names an endpoint the
controller lacks is an error, where the reference indexes its endpoint arrays and the controller's registers
with the request's number. A class request's data stage is cut to the 8-byte command buffer, where the
reference moves the request's full length through it. The buffer from the host takes a packet only while it
stays one byte short of full, where the reference fills it to its size and its indexes then read empty. A
resume restores the status the suspend left, where the reference sets the device configured. The control
endpoint's halt ends at the next setup packet, as the controller's stall does, where the reference keeps the
flag after a request error.

The usbvcp vectors come from a host build of the reference's device library, class and port sources with the
corrections behind toggles, over stubs of the endpoint layer that keep its state and record its operations:
64 sessions of enumeration, line coding, data both ways, malformed requests and bus events, each event with
its operations and the state after it. Eight tampers fail the vectors.
## D409. STM32F4 USB virtual serial port (2026-10-26)

`Adaflight.STM32.USB` drives the F405's full-speed OTG controller for the device of D408, after the
controller code the reference builds for the F4: the disconnect pulse of the reference's port open (D+ held
low for 200 ms as an open-drain output, so a host still holding the previous connection sees a new device),
PA11 and PA12 on their alternate function at the very high output speed, the core reset on the embedded
transceiver with bus sensing off, device mode, the FIFOs (128 words to receive, 32, 64 and 64 words to send
on endpoints 0, 1 and 3), every endpoint disabled, and the interrupts. Its interrupt reads the
receive FIFO into the endpoint buffers, hands setup packets, finished transfers, frames, bus resets,
suspends and resumes to the device, and carries out the endpoint operations each one returns, writing a
packet into its transmit FIFO when the FIFO has room. The controller's state sits in CCM RAM.

`Adaflight.STM32.Serial` puts the UARTs and the virtual serial port behind one port type. The MSP and the
command line serve the virtual serial port and UART1, the virtual serial port first in the port list as
identifier 20, and the command line runs on the port it was entered from, with the MSP paused on every port
while it runs. A write to the virtual serial port goes out while the host has the port configured, retried
for up to 50 ms while a transfer runs. The host target serves the virtual serial port on TCP port 5780, and
the smoke check runs the MSP and the command line over it.

Two details differ from the reference. The device address goes into its field of the device configuration
register, where the reference ORs it into the register, so a second address request without a bus reset
leaves bits of both addresses (DIVERGENCES.md). The incomplete isochronous interrupts, which no endpoint of
the class raises, are cleared without the class callbacks the reference calls through null pointers.

## D410. Setting names in pools (2026-10-26)

The settings table keeps the setting names in one text, with a start and a length for each setting,
and the value names in another, with each lookup table's first value index and a start and a length
for each value. A name is a slice of its pool. The pools end with room for a longest name, and the
value index tables run past the last value by a longest table, so every slice and every index stays
within its bounds by the types alone, and the proof needs no fact about the tables' contents. The
starts take sixteen bits and the lengths eight. `Name` and `Value_Name` now state that a name is at
most the longest, 43 and 27 characters, which their callers get in place of the inlined literals.

The generator wrote the two functions as case expressions over string literals, one alternative per
setting and per value. Their code took 49102 bytes in the board image, and their 1293 literals and
their bounds more outside the named symbols. The pools and their index tables take 21912 bytes, all
of it read-only data, and the image dropped from 609936 bytes of text to 553112. The settings vectors
check every setting and value name against the oracle's dump, and four tampers of the slices fail
them.

## D411. STM32F4 flight log on a serial port (2026-10-26)

`Adaflight.STM32.Blackbox` runs the recorder of D93 on the board. The configuration names the port and
its rate, as the reference's settings do. The port opens at that rate, with two stop bits at 230400
baud, unless it is the MSP's, in which case it keeps the MSP's rate and the MSP leaves it while the log
holds it: from the start, and again at every log open, until the log closes. The flight gives the log
its facts before each PID pass: the time, the arming beep, the battery, the gyro rates filtered and
raw, the accelerometer, the attitude quaternion, the link's signal, the failsafe phase, the active
boxes as the log's flight mode word, the state flags, the GPS solution with its date as seconds since
1970, and the conditions of a log start. The log step after the mixer takes the controller's terms and
last setpoints, the RC commands, the mixer's throttle and motors, and the port's room, then runs the
recorder's iteration and queues its bytes on the port. The header's system information comes from
D406 once per log, built while the header is on its way. A disarm logs its event with the reason, then
ends the log.

The UART driver gained a transmit ring of 256 bytes per port, filled by the transmit interrupt. A
write queues its bytes and waits only for room, so a long command line reply no longer holds the
flight loop for its whole length, and the log's writer takes the ring's room as the device's.

The log names the firmware Adaflight in its type and revision lines, which the stock log viewer does
not know. The adaflight-blackbox-log-viewer fork reads them. The host target serves the port on TCP,
and the smoke check sets the device, the port and the always-on mode, then reads the header, the
field definitions and the first frames from UART6's port. The image is 591420 bytes of text.

## D412. STM32F4 Crossfire telemetry (2026-10-26)

The receiver link sends the CRSF telemetry of D71 back on its port. The telemetry task runs the
negotiation, then the frames due from the sources the flight gives it: the GPS solution with its date,
the battery with its cell voltage option, the attitude, the flight state with the mode word, the
arming hold, the switches and the rescue settings, the inertial sample and the craft name. The frames
leave through the port's transmit ring. The receiver's frames feed the telemetry as they arrive: a
ping schedules the device information reply, a response slot opens the next frame, a speed proposal
and a device information frame are handed over from the byte past the destination and origin, and
the default rate returns after repeated errors. A negotiated rate reinitializes the port and tells the
receiver its timing. The display port over CRSF waits for its menu.

The telemetry's configuration comes from the board's sensors, the telemetry group's disabled kinds and
inertial frames, the battery meters, the GPS and telemetry features and the negotiated rate option.
The task runs with the telemetry feature outside the command line. The smoke check's receiver reads
the port back and counts the frames by type. The image is 598016 bytes of text.

The GPS frames are timed on a change of the solution's time. The board stamps each solution with the
clock and gives the telemetry that stamp, so an NMEA module's solutions send their frames as a u-blox
module's do. The reference keys the frames on the solution time its NMEA parser never sets, so an NMEA
module sends no GPS telemetry over CRSF (DIVERGENCES.md). The flight log keeps the module's own time.

## D413. STM32F4 flight log on the SD card (2026-10-26)

`Adaflight.STM32.SD` puts the SD card driver of D367, the file system of D297 to D300 and the flight
log device of D301 on the board. The card's SPI device is the bus the stored configuration names, with
its select and detect pins from the configuration's tags. A sequence selects the card at its first
segment and after each segment that negated the select pin, a segment clocks its bytes over the polled
SPI driver, and the device has no DMA, so a block goes out 256 bytes at a time. The driver's completion
is kept in the device and delivered to the file system once the poll returns with the block, since the
driver holds the block while it polls. The file system reads no clock, so new entries carry its default
time. The board's defaults name the card: the board generator emits the card's select and detect tags,
its SPI bus, the detect pin's sense and the default flight log device, and the hardware defaults of
D392 apply them at a reset, with the card's mode SPI when the bus and the select pin are named. The
main task's poll runs the card's poll, the completion, then the file system's poll with the card's
readiness. The MSP SD card summary and the command line's SD information read the card's metadata and
the file system's state.

The flight log of D411 takes the card as its device. Before each pass the facts come from the file
system: whether it takes a log and whether it is full, the bytes its cache takes as the device's room,
and the calls the recorder's state asks for in the order the reference makes them: the log start step
while the log file is prepared, a flush until every sector is on the card while the cache flushes, and
while the log shuts down its end, then its flush while the shutdown timeout has not passed, which the core
now names in its spec. The iteration's bytes go to the log file as one text. The image is 614784 bytes of text, with the file
system and the card in CCM RAM.

The host target carries a model of a high capacity version 2 card on SPI2 over the image file the
environment variable `ADAFLIGHT_SD_IMAGE` names, answering while its select pin is low, which the
host's pin levels record, with the registers of a card named ADAFL, block reads and writes against the
file, and runs of writes ended by the stop token. The detect pin reads a card while the variable is set.
The smoke check writes a 20 MB FAT16 image with a partition table, sets the flight log device to the
card, restarts the image, reads the MSP summary and the command line's information with the card ready,
then reads the log file's first cluster from the image through the LOGS directory and checks the
header.

## D414. STM32F4 real time clock (2026-10-26)

`Adaflight.STM32.RTC` keeps the core's clock of D74 over the board's millisecond clock. The
configurator sets it through the MSP clock message, as milliseconds since 1970, and the GPS link sets
it from the first fix's date while it has no time, as the reference does on a published solution. The
time zone comes from the stored configuration at each serial pass, so a command line change shows at
once. The log header's start line formats the local time with its offset, the OSD's clock element
reads the date and the zone each frame, the MSP clock reply gives the date once a time was set, and the
card's new file entries take the local time. A reboot loses the time, as in the reference, which keeps
it across a reboot only into the mass storage mode. The smoke check sets the clock over MSP, reads the
date back and finds it on the OSD screen.

## D415. STM32F4 flight log on the flash chip (2026-10-26)

`Adaflight.STM32.Flash_Chip` puts the SPI flash chip driver of D330, the flash layer of D331 and the flash
file system of D137 on the board. The chip's SPI device is the bus the stored configuration names with its
select pin, which the board's defaults take from the board generator, as the SD card's. A segment list
runs as the reference's bus runs it: the select pin low at the first segment and after each negation, a
segment's bytes from its command or a buffer, idle bytes for a read, the callback after it, a busy answer
repeating the segment and an abort skipping the rest. The bus has no DMA, so a program ends inside its
call, and the end of a program reports its bytes to the file system. Initialization identifies the chip on
a 5 MHz clock, lays the file system over the flash file system partition, searches for the start of the
free space in 16-byte probes and seeks there. Each file system call lists its operations, which the
package carries out on the chip in their order: a ready wait, a page program, a sector or chip erase, a
read into the caller's buffer, and the LED's toggle and off during the erase. The main task runs the erase
step.

The flight log of D411 takes the chip as its device. The facts are the write buffer's room and usable
size, whether a file system sits on the chip and whether its volume is full, the chip's readiness while
the volume erases, and the forced flush while the cache flushes and while the log shuts down inside the
shutdown timeout. The recorder's device flush, erase and close requests, counted in its state, become
the file system's flush at the end of every logging iteration, its erase and its close, and the header
writer's flush requests, counted when the buffer has no room for a reserve, become a forced flush. The
MSP flash summary and the command line's flash tools, which the console bound to the core's placeholders
before, read and drive the chip.

The host target carries a model of a 16 MB W25Q128FV on SPI3 beside the OSD chip, each answering while
its select pin is low, over the image file the environment variable `ADAFLIGHT_FLASH_IMAGE` names. The
host's pins record their rising edges, so the model ends a command when its select pin rose between two
transfers. The
smoke check writes a blank image, sets the flight log device to the chip, restarts the image, reads the
MSP summary and the command line's flash information and read, then finds the header at the start of
the image.

## D416. STM32F4 video transmitter control (2026-10-27)

`Adaflight.STM32.VTX` runs the video transmitter control of D84 to D86 on the board. The device is the
one the stored configuration names, on the UART its `vtx_uart` setting names. SmartAudio opens the port
at 4800 baud with two stop bits, half duplex on the transmit pin, push-pull with a pull-down. Tramp opens
it at 9600 baud, half duplex and open drain with a pull-up when `vtx_halfduplex` is on, full duplex
otherwise. `Adaflight.STM32.USART` gained the half duplex line for this: the transmit pin alone at low
speed with its drive and pull, and the half duplex selection bit. The transmitter takes its port after
the receiver and the GPS link, and the port is refused when either holds it. The MSP leaves UART1 and the
serial flight log leaves its port when the transmitter holds it, since in the reference the MSP and the
log open their ports after the transmitter.

The start builds the running table from the stored one and starts the control layer, which saves the
configuration when it made the settings whole. The VTX task runs at 5 Hz with the stored settings, the
arming state, the failsafe, the command line's state and the pit mode and control disable boxes. It
hands the control layer the bytes the device sent, keeps the bytes a Tramp reply left unread for the
next call, queues the frames on the port, follows a SmartAudio rate change, and writes the settings the
layer changed back to the configuration. The channel switches of D85 apply after each mode pass. The MSP
VTX configuration and device status replies and the configuration write read the device, its readiness,
its pit mode and the running table, a pit mode write goes to the device, and `vtx_info` lists the
SmartAudio power levels.

The smoke check releases UART6 from the serial flight log, names it for a SmartAudio transmitter,
restarts the image and plays a SmartAudio V2 transmitter on the port: it answers the settings request,
the pit mode frequency request and each command. The MSP configuration reply names a ready SmartAudio
device, a configuration write of 5800 MHz reaches the transmitter as a frequency command, and
`vtx_info` lists the power levels.

## D417. STM32F4 PINIO outputs (2026-10-27)

`Adaflight.STM32.PINIO` drives the board's PINIO outputs with the PINIO boxes of D131. The board generator
emits each output's pin, configuration byte and box by permanent id, the push-pull mode and no box where
the board names none, and the hardware defaults of D392 apply them at a reset: on the CLRacing F4 boards
the first output is PA14 on the USER1 box. The start makes each configured pin a push-pull output, high
before the switch when its configuration inverts it, then sets it to its idle level, high when inverted.
The boxes map from their permanent ids after the modes start. The PINIO box task runs at 20 Hz while one
of the named boxes has a mode condition, which the flight checks again whenever the modes reload from an
MSP write or the command line. Each run sets the assigned outputs from their boxes, inverted outputs low
when the box is on, and a pin changes only when its level does.

The host's pins keep their levels, so the image runs the same code. The smoke check sets a USER1 range
with the command line and finds the PINIO box task in the task list after the restart.

## D418. STM32F4 DShot motors (2026-10-27)

`Adaflight.STM32.Motors` drives the mixer's motors in DShot 150, 300 or 600 from the timers, with the
frames of D58. Each motor's pin is the stored one at its place in the output order, and the board
generator emits the board's motor pins, which the hardware defaults of D392 apply at a reset. The pin's
timer channel is the occurrence the board's timer map names among the processor's timer outputs, in the
order of the processor's timer table, and its DMA stream is the option the map names among the
channel's streams. On the CLRacing F4 boards the four motors are TIM1 channel 2N on PB0, TIM8 channel
3N on PB1, and TIM2 channels 4 and 3 on PA3 and PA2, on DMA2 streams 6 and 2 and DMA1 streams 6 and 1.
A missing pin, map entry or stream leaves every motor undriven.

The start configures each motor: the pin on the timer's alternate function at
the 50 MHz speed with a pull-up, or a pull-down when inverted, the timer counting at the protocol's bit
clock with twenty counts a bit when it is the timer just added, the channel in PWM mode 1 with its
compare preload, the complementary output on for an N channel with the main output stage on, and the
stream from memory to the channel's compare register with its FIFO. The writes start at the end of the
flight software's start. A write converts each motor's value to its frame, loads the sixteen bits as
seven or fourteen counts high, then two zero slots, and arms the motor's stream, then each timer
restarts with its period reloaded and asks for the transfers. The reference ends each stream and the
timer's request in the transfer complete interrupt. Here the next write ends them before it arms the
stream, which leaves the pin's waveform the same, since a frame takes 30 microseconds and the loop
runs every 125 or 250 microseconds.

The mixer gets the motors' enables, the MSP motor configuration reply counts the mixer's motors, and
the MSP motor reply gives each enabled motor's value in the external range, the stop at 1000 while
disarmed. The configurator's motor test is D419 and the DShot commands are D421. The bidirectional
telemetry and the analog protocols are later steps. The host target keeps the motor path without timers, and the smoke check
reads the motor count and the stop values over MSP. The branch waits for a bench check with the
propellers off before it lands.

## D419. STM32F4 motor test (2026-10-27)

The board's control unit keeps the values the motors take while disarmed, which start at the mixer's
disarm output. While disarmed, each pass of the mixer ends with every motor of the mix set to its
disarmed value. The MSP motor
write sets each motor of the mix from its request, converted from the external range as the core's MSP
unit converts it, and the command line's motor command sets one motor or every motor. The values return
to the disarm output when the command line closes. The motors run while armed or while a disarmed value
differs from the disarm output, which the flight log, the OSD and the beeper read, where the board
passed the arming alone before.

The smoke check writes 1100, 1200, 1300 and 1400 to the four motors over MSP, reads them back from the
motor reply while disarmed, and writes the stop again.

## D420. DShot command queue (2026-10-27)

`Adaflight.DShot_Command` keeps the DShot commands for the ESCs in a ring of four entries, which holds
three commands at most. Each entry has its state, the motor output cycles it still waits, the delay
after it, its repeats and a command for each motor. An inline command enters the queue while the motors
stream. It waits for every motor to idle, waits 10 ms, goes out in place of the motor values once for
each repeat with 1 ms between them, and waits 1 ms before the next command goes out. The commands that
change an ESC setting go out ten times, the others once. The first streaming command waits until 3 s
after the motors enable, for the protocol detection of the ESCs. The waits are counted in motor output
cycles of the PID loop time, rounded up, and the loop time's subtype starts at 1 microsecond, so the
division is proved defined where the reference divides without a check.

A blocking command runs while the motors are disabled, from the command line. It stands in the queue's
current entry, so the timer layer's write sends it, and `Adaflight.DShot_Command.Blocking_Run` sends it
through the caller's motor table: a 9 ms wait, then for each repeat a 1 ms wait, the telemetry decode, a
telemetry request and a write for each motor, and the end of the update, then the wait after the
command, 100 ms after a beacon and 1 ms after the others, and the entry back to the stop. The generic is
proved through a motor table of steps that do nothing. The board's motor writes take the queue in the
next step.

The oracle compiles the reference queue with the motor layer stubbed and draws the protocol, the motor
enables and their time, the clock, the motor count, the PID loop time, inline and blocking writes, motor
updates through a model of the timer layer's write, and queries. Every third sequence is a bench session
with the motors mostly disabled and the writes mostly blocking, and the clock lands next to the end of the
protocol detection delay. The vectors replay every write and query, each entry's state after each step,
and the motor table's calls in order.

## D421. STM32F4 DShot commands (2026-10-27)

`Adaflight.STM32.DShot_Output` drives the motors' DShot output through the command queue of D420, and
`Adaflight.STM32.Motors` keeps the frame load and the transfer start. Each motor's write sends the
queue's current command in place of the mix's value while one is processing, with a telemetry request
when it is not the stop. The value stays as the motor's idle state for the queue's idle wait, and the
frame takes the request. The update starts the transfers only when the queue is empty or its output
gate opens. The queue counts its waits in cycles of the PID loop time, set each time the PID settings
are configured, and the motors' enable time starts the first streaming command's detection delay.

The command line's dshotprog and the MSP DShot command message send blocking commands with the motors
disabled around them, through a motor table of the board's busy waits, telemetry requests, writes and
update ends. Telemetry decoding is a later step, so the decode before each repeat returns at once. The
arming logic's spin direction and extended telemetry commands and the beeper's beacon enter the queue
as inline commands. The arming logic's boot grace check reads whether streaming commands are enabled,
and the board asks the queue only while the boot grace flag is set past the grace time with a DShot
protocol, where the check reads it, since the first answer past the detection delay ends the delay for
good. The command line's environment reports the DShot protocol, which dshotprog needs.

The host target writes each command frame its transfers send to the file the environment variable
ADAFLIGHT_DSHOT_LOG names. The smoke check queues a beacon over MSP and finds it once on each motor with
a telemetry request, then runs dshotprog 0 7 and finds the spin direction command ten times on motor 0
alone.

## D422. STM32F4 ESC sensor (2026-10-27)

`Adaflight.STM32.ESC_Sensor` reads the ESC telemetry of D60 on a UART. With the ESC sensor feature on, the
port that esc_sensor_uart names opens at 115200 baud, over its transmit pin alone when
esc_sensor_halfduplex is on, unless the receiver or the GPS holds it, and the readings start as not yet
received. The video transmitter, the flight log's serial port and MSP on UART1 leave a port the ESC sensor
holds. The UART's transmitter is on as well and sends nothing, where the reference opens the port to
receive only.

The ESC sensor task runs at 100 Hz: it takes the bytes received since its last run into the frame in
flight, then polls the motors, and a poll's request goes out as the telemetry request in the motor's next
DShot frame. The battery's ESC meters read the reading over every motor, the MSP ESC sensor and motor
telemetry replies read each motor's reading, and the command line knows the feature is on. The rate in
revolutions per minute uses the pole count as the DShot telemetry does, and a negative rate, which no
motor reaches, reports none. The ESC information read of dshotprog is D423 and the OSD's ESC elements are
D424.

The host smoke check enables the feature on UART6, sends a frame every 30 ms as the ESCs, and reads the
temperature, rate, voltage, current and consumption back from the MSP replies.

## D423. STM32F4 ESC information read (2026-10-27)

`Adaflight.STM32.ESC_Sensor` serves the read behind dshotprog's ESC information command. The read's start
passes the bytes received so far to the telemetry frame in flight, as the receive interrupt would have, and
the bytes that arrive during the blocking command and the 10 ms wait after it fill a 64-byte information
frame. The read's end takes the bytes received since, gives the frame and its count to the command line,
and later bytes go back to the telemetry frame. The reference leaves its receive buffer on the command
line's stack after the read, a declared divergence with an upstream write-up.

The host smoke check plays an ESC that watches the image's DShot frame log for the information command to
motor 0 and answers with a KISS version 2 frame, then reads the type, serial number, firmware and 3D state
from dshotprog's output.

## D424. STM32F4 ESC sensor on the OSD (2026-10-27)

The board's OSD reads the ESC sensor of D422 at each frame while the ESC sensor feature is on. The reading
over every motor gives the ESC temperature element, the temperature alarm, and the statistics' highest
temperature and rate. Each motor's reading gives the ESC rate elements and the ESC warning, which flags a
motor's rate only while its output is above the mixer's disarm output. The rate factor comes from the pole
count, and a negative rate counts as none. With the feature on, the active element list takes the ESC
elements in.

The host smoke check places the ESC temperature element and finds the ESC frames' 42 degrees on the
host's OSD screen.

## D425. STM32F4 LTM telemetry (2026-10-27)

`Adaflight.STM32.LTM` sends the LTM stream of the core's LTM telemetry unit on a UART. With the telemetry
feature on, the first telemetry provider set to LTM with a port names the UART, at the provider's rate, or
19200 baud for the automatic rate. The port's sharing comes from the serial functions the configuration
assigns it. A port with no other function sends at once. A port shared with MSP sends while armed, or while
the telemetry box is on when the box has a range, and MSP on UART1 stops while the stream holds the port.
The arming logic's shared port transitions check the state again, and UART1 returns to the MSP rate with a
fresh MSP framing when the stream gives it up. A port another board function holds stays closed to the
stream.
The port handling is the generic `Adaflight.STM32.Telemetry_Port`, instantiated per protocol with its
provider number, serial function and default rate.

The telemetry task runs the stream outside the command line. The inputs are the attitude, the flight modes
in the stream's order of precedence, the arming, the failsafe, the battery, the RSSI and the GPS solution
with its home. The GPS frame's altitude is the position estimate of D426.

The host smoke check sets the first provider to LTM on UART3 and reads attitude frames ten times a second,
status frames that report the craft disarmed in rate mode, and an origin frame every tenth cycle.

## D426. STM32F4 position estimate (2026-10-27)

The board runs the position task of `Adaflight.Position_Estimator` (D81) at 100 Hz, which the task setup
enables with the GPS feature. The estimate reads the accelerometer's filtered values with their scale, the
attitude's rotation, and the GPS as its link keeps it: the sensor and fix flags, the solutions' stamp and
rate, the location, the north, east and down velocities, the horizontal, speed and vertical accuracies,
and the cosine of the home latitude. The CLRacing F4 boards have no barometer, so the estimate runs on the
accelerometer and the GPS. The position hold and rescue modes ask for the horizontal axes. The settings
come from the position and position hold configuration, and the estimator starts after the flight log.

The displayed altitude and the climb rate, rounded and with its 10 cm/s deadband, go to the MSP altitude
reply, the CRSF vario frame, the LTM GPS frame, and the OSD's altitude and vario elements, statistics and
altitude alarm. The OSD takes the altitude held to its 400 km bound. The rescue and the hold modes are
later steps.

The host smoke check climbs the NMEA fix by 10 m and reads the climb from the MSP altitude reply.

## D427. STM32F4 GPS home on arming (2026-10-27)

The board resets the GPS home position for each home reset the arming logic asks for when the craft arms
with the GPS feature on: the home takes the current fix when it has the rescue's minimum satellites,
unless the home is kept once set, its longitude scale follows, a u-blox module's satellite reports turn
off, and the distance flown restarts. The board had dropped these resets, so the home position never
formed. The GPS package's send of the link's bytes serves both the task and the reset.

## D428. STM32F4 MAVLink telemetry (2026-10-27)

`Adaflight.STM32.MAVLink` runs the core's MAVLink telemetry and command units on the telemetry port of the
first provider with the MAVLink protocol, at its rate or 57600 baud, through the telemetry port generic of
D425. When the port opens, the arming report starts over, the frame parser restarts, and the stream
intervals start again from the settings. Each telemetry task takes the bytes received into a 512-byte
buffer, gives the command unit up to 64 of them, sends its replies, keeps the rest for the next task, then
sends the stream messages due. The board has no MAVLink receiver, so the streams go out 20 ms after the
last pass. The telemetry task runs the LTM stream before the MAVLink one.

The ground station's requests run after the drain in their order: a disarm by serial command, the mode
overrides through the arming state, a home reset or a home position, and a reboot once the port's queued
bytes have left or 100 ms have passed. A reboot to the bootloader goes through the ROM bootloader reset of D429.
The inputs take the battery and its meters, the RSSI and the first eight channels, the attitude, the GPS
solution with its accuracies and home, the estimated altitude of D426, the mixer, the arming, the
failsafe, the flight modes as the flight mode word the MAVLink unit decodes, the clock and the disable
reasons.

The host smoke check sets the first provider to MAVLink on UART3, checks the heartbeat and attitude
messages' CRCs, and requests the autopilot version, which comes back with its acknowledgement.

## D429. STM32F4 reboot into the ROM bootloader (2026-10-27)

`Adaflight.STM32.MCU` keeps seven persistent words in the RTC backup registers, which a system reset
leaves alone: the magic word, then the reset reason at index 3. At the start, before any of the board's
devices, the words are kept over a software reset with the magic word and cleared after any other reset,
and the reset flags are cleared. A reset reason of 1 is a request for the ROM bootloader: it is cleared,
the interrupts and the system tick stop, the NVIC's enables and pending bits clear, the clocks return to
the internal oscillator with the PLL and the external oscillator off as a reset leaves them, the system
memory is mapped at address zero, and the code jumps to the bootloader with its stack. The check runs after
the runtime has set up the clocks, where the reference checks before its clock setup, so the board puts the
clocks back first.

MSP's reboot into the ROM bootloader, the command line's `bl`, and MAVLink's reboot to the bootloader
write the request and reset. The MSP reboot into the flash bootloader leaves the board running, since the
board has no flash bootloader. The host image ends with status 2 on a bootloader request, and the host
smoke check asks for one over MSP and over the command line.

## D430. STM32F4 in-flight adjustments (2026-10-27)

The board runs the core's in-flight adjustments in the receiver task's modes step whenever the arming
logic's modes pass asks for them, which it does outside the command line and outside the paralyze box
while disarmed. Each pass rebuilds the step and dial lists when the stored adjustment ranges changed, takes
the active rate profile, battery profile, LED profile and LED brightness from the configuration, runs over
the four stored rate profiles and the current PID profile, and writes back each rate, expo, gain, D max,
horizon strength, feedforward transition and master multiplier the pass changed, so a stored value the pass
did not touch keeps its own even where the runtime profile holds it to a range. The selections go back to
the configuration. A pass that changed a gain or a rate, or the rate profile, configures the pilot and the
controller again from the configuration, a battery profile change rebuilds the battery settings, and the
pass's confirmation beeps sound. The changes stay unsaved until a save.

The OSD's adjustment element shows the function's name and value for two seconds after a change. The OSD
name holds 16 characters, so the master multiplier's 24-character name shows its first 16, a difference
to remove when the element takes longer names.

The host smoke check sets an RC rate adjustment on AUX1, holds AUX1 high for 2.5 s, and reads the RC rate
three to seven steps higher from the MSP RC tuning reply.

## D431. STM32F4 flight statistics (2026-10-27)

The board keeps the core's flight statistics. Each arming the arming logic reports notes the time and the
GPS distance flown, and each disarm moves the stored totals of flights, armed seconds, metres flown and
charge used on when the flight lasted the minimum armed time, and asks for a save half a second later
unless one waits already. The serial task runs the waiting save once its time has come: the configuration
is written with the disarm beep while the craft is disarmed, still within the save move limit, and holds
no unsaved adjustment, the save is asked again half a second later while the craft moves, and nothing
happens otherwise. Every configuration save clears the unsaved adjustment flag. The OSD's statistics page
shows the stored totals.

The host cannot arm yet, so no smoke check covers the statistics.

## D432. STM32F4 altitude hold (2026-10-27)

The board runs the core's altitude hold in its own task at 100 Hz. The task's check function wakes it on
each update event of the position estimate, or after twice its period without one, so mode changes still
reach the hold when the estimator stops. Each run takes the interval the scheduler measured since the last
run, the altitude hold flight mode, the RC throttle command and its low status, the failsafe, the
estimate's control altitude, climb rate and vertical acceleration, and the cosine of the tilt. The arming
logic sees the altitude estimate's validity, so the altitude hold mode engages on an armed board once the
throttle was raised. Under the mode the mixer takes the altitude controller's throttle, and the
controller's landing disarm reads whether the estimate is below the autopilot's landing altitude. The board
keeps the platform's position control law off until it runs the position hold, which keeps the position
hold mode from engaging.

The host cannot arm, so no smoke check flies the hold. The host smoke check reads the task list with the
GPS feature on and finds the altitude hold task at 80 to 120 Hz, a rate only the estimator's update events
give: the fallback alone runs it at 50 Hz.

## D433. Autopilot yaw in the RC setpoints (2026-10-27)

The RC processing takes the autopilot's yaw as an input: whether its yaw controller holds the yaw in a mode
it serves, the rate it asks for, and the stick deadband from the autopilot settings. While the autopilot
holds the yaw and the yaw command stays inside the deadband, the yaw's raw setpoint is the autopilot's rate
within the axis's rate limit, its deflection is zero, and the largest deflection leaves the yaw out. A yaw
command at the deadband or past it hands the yaw back to the stick. The input defaults to no autopilot, so
a caller without one keeps its setpoints.

The oracle's RC generator draws the autopilot's yaw in its own family: held in one step of two, a rate
within 250 or 1000 degrees per second, and a deadband on the yaw command's magnitude, one past it, or
anywhere in its range, so the deadband's edge and the rate limit both appear.

## D434. STM32F4 position hold (2026-10-27)

The board runs the core's position hold in its own 100 Hz task, which the position estimate's update
events wake, or twice its period without one, as for the altitude hold. Each run takes the arming, the
failsafe, the position hold, rescue, autopilot and magnetometer modes, the measured interval, the
estimate's east and north position, velocity and acceleration with its height and validity, whether the
estimate's source needs a heading, the attitude's heading, the pilot's pitch and roll setpoint rates with
their maxima, the yaw command, and the pitch and roll deflections. The hold flies over an idle navigator,
since the board has no flight plan, and asks the estimator for its horizontal axes when its controller
starts. The arming logic's position control law is on, so the mode engages on an armed board once the
throttle was raised. Under the mode the controller flies the autopilot's angles while the autopilot holds
the position, and the pilot's angles within the autopilot's angle limit otherwise, and the mixer keeps the
motors running. The RC processing takes the controller's yaw rate in the modes the controller serves, with
the modes read when the RC processing runs. The OSD's position hold ready element, its failure warning and
the CRSF flight mode's failure flag read the hold.

The board has no compass, and the attitude estimate takes no GPS course yet, so the heading is never
valid. With the GPS as the estimate's source the hold needs a heading, so on this board the hold engages
with level angles and reports a failure until the attitude takes the GPS course.

The host smoke check finds the position hold task at 80 to 120 Hz with the GPS feature on.

## D435. GPS course in the attitude estimate (2026-10-27)

The attitude estimate takes the GPS course over ground as a second heading reference, which D31 left for
the GPS port. Each update reads whether a present module has a fix with more than four satellites, its
ground speed and course, the latest filtered yaw rate, and whether the craft is a fixed wing. The first
usable update faster than one metre per second sets the attitude from the last roll and pitch with the
course as the heading, unless a calibrated compass holds the heading. Later updates weigh the course error
by the ground speed. The yaw rate suppresses the weight and recovers over about a second, roll beyond ten
degrees suppresses it, or beyond twenty-five on a fixed wing, a flat or backward pitch suppresses it on a
multirotor, and a calibrated compass cuts it to a tenth. The course error is the sine of the angle between
the nose and the course within a quarter turn, and one toward the shorter turn beyond it. The weighted
error joins the compass's error in the Mahony update. Until the GPS heading is good to fly by, a confidence
follows the weight while the nose lines up with the course within about fifteen degrees, with a two-second
time constant, and the GPS heading becomes good to fly by once the confidence passes one and a half. It
stays so until a restart. The heading is valid with a calibrated compass or a GPS heading good to fly by.

The yaw rate suppression's last value is held at or above minus 2 to the 14, the course's error share
within 2 to the 14, and the confidence within 2 to the 60. These are declared deviations: the suppression
and the confidence extrapolate with the update interval, and only an interval of many seconds reaches the
bounds. The error ranges in the Mahony update widened for the course's share.

The oracle's attitude generator flies a GPS module in its own family, with the module present or not, a fix
or not, the satellite count, a ground speed, a course near the estimate's heading in three steps of four,
and the latest yaw rate. Every other sequence flies steadily forward so the confidence can build, and seven
of the forty sequences reach a usable GPS heading.

## D436. STM32F4 attitude on the arming state (2026-10-27)

The board's attitude task passes the pilot's arming state, the angle or horizon mode, and the headfree mode
to the estimator. Since the scheduler increment the task had passed a disarmed craft and no modes, before
the board had its arming logic. In flight the estimator would have kept the disarmed gain schedule, ten times
the configured gain or the reconvergence after a disarm, and the throttle angle correction would never have
applied. The headfree mode now reaches the attitude's headfree frame. The sticks do not turn in headfree mode
on the board yet.

The host cannot arm, so no smoke check covers the change.

## D437. STM32F4 GPS course in the attitude (2026-10-27)

The board's attitude task passes the GPS course to the estimator: usable while a present module has a fix
with more than four satellites, the ground speed and the course, the filtered yaw rate, and whether the mixer
is a fixed wing's. The board has no compass, so the attitude's heading is good to fly by once the GPS course
has matched it long enough, and the position hold takes that heading. The first usable fix faster than one
metre per second turns the attitude's heading to the course.

The host smoke check's GPS reports 22.4 knots on an 84.4 degree course, and the MSP attitude reply's heading
reads 84 degrees once the fix arrives. The host's accelerometer reads level, so the course's weight stays at
zero and no smoke check reaches a usable GPS heading.

## D438. STM32F4 GPS rescue (2026-10-27)

The board runs the core's GPS rescue in its own 100 Hz task while the rescue is configured, as the failsafe
procedure or by its mode box. Each run takes the rescue mode, the arming, the GPS stamp, health, fix, home
fix and satellites, the heading's validity, the altitude estimate's control and smoothed values with its
validity, vertical speed and acceleration, the horizontal estimate the position hold reads, the attitude's
heading and tilt, the crash recovery, and the receiver link. The rescue drives the autopilot's altitude
controller, which the altitude hold owns, and the position controller, which the position hold owns and
which flies the rescue's angles and yaw. Under the rescue mode the controller takes the autopilot's angles
within its angle limit and the mixer takes the altitude controller's throttle. A disarm the rescue asks for
is a failsafe disarm, with the arm switch's disable reason set when the rescue asks for it. The OSD's
warnings read the rescue mode and the rescue's health, availability and heading.

The host cannot arm, so no smoke check flies a rescue. With the rescue as the failsafe procedure, the host
smoke check finds the rescue task at 80 to 120 Hz, which shows the task runs but not the rescue's update,
since a disarmed rescue has nothing the replies show.

## D439. STM32F4 headfree sticks (2026-10-27)

In headfree mode the board turns the RC commands into the attitude's headfree frame between the command
update and the arming status update, the receiver task's update step. The roll and pitch commands turn,
and the yaw command turns too unless an angle, horizon, altitude hold, position hold or rescue mode is on.
The core's turn scales the commands back together where a deflection would pass one (D6), and the headfree
offset comes from the arming or the headfree adjust box as before. D436 gave the attitude the headfree mode.

The host reports no RC command that the turn changes, so no smoke check covers it. The core's turn has
its own recorded vectors.

## D440. STM32F4 configurator activity (2026-10-27)

The board tells the beeper and the failsafe when a configurator is active: a byte on the USB port's or
UART1's MSP within the five-second activity timeout. The failsafe's lost link tones stay silent while one is
active, and the beeper's on-USB flag silences the beeper on the bench, with no battery, while a configurator
is active or the USB cable is: its detect pin reads high, or a host has configured the port. The board pulls
the detect pin down as an input at boot, after the ESC sensor, where its configuration names one, and the
board generator gives its tag. The board had passed no USB link and no configurator.

The host reports no beeper state, so no smoke check covers it.

## D441. STM32F4 SBUS receiver (2026-10-27)

The board reads an SBUS receiver on the UART the configuration assigns to the serial receiver: 100,000 baud,
or 200,000 with the fast SBUS setting, eight data bits with even parity and two stop bits, and an inverted
line unless the setting says the receiver's line is not inverted. The bytes go through the core's SBUS
frame assembly at their arrival times, the frame status after the realtime tasks, the eighteen channels to
the receiver's processing, and the frame time to the RC smoothing. The RSSI comes from the frame errors
when that source is set. The CRSF telemetry and the PID settings' CRSF case stay with a CRSF receiver.

The UART driver gains even parity, a ninth word bit with parity control, and the board's inverters: the
board generator gives each UART's inverter tag, the boot drives every inverter low after the beeper, and a
port opened inverted drives its UART's inverter high where the board has one. Without an inverter the line
stays as the UART reads it, so an inverted SBUS line needs UART1 on this board. Half-duplex SBUS waits.

The host smoke check sets SBUS on UART3 with a fresh store, sends SBUS frames about every 14 ms, reads the
roll, pitch, yaw and throttle channels back over MSP, and finds the signal loss cleared.

## D442. STM32F4 IBUS and SUMD receivers (2026-10-27)

The board reads an IBUS or a SUMD receiver on the serial receiver UART at 115,200 baud, eight data bits
without parity, inverted only when the setting asks. The bytes go through the core's IBUS or SUMD frame
assembly at their arrival times and the frame status after the realtime tasks, eighteen channels each,
with the frame time to the RC smoothing. The IBUS frame status's telemetry request goes unanswered until
the board sends IBUS telemetry, which needs a half-duplex port. A CRSF port now opens inverted when the
setting asks, through the board's inverter, where it had stayed closed.

The host smoke check runs its receiver phase for SBUS, IBUS and SUMD, each with a fresh store and its own
frames carrying the same channels, and reads the channels back over MSP.

## D443. STM32F4 Spektrum and XBUS receivers (2026-10-27)

The board reads a Spektrum satellite at 1024 or 2048 resolution, seven or twelve channels, or an XBUS
receiver in mode B, at 115,200 baud, or mode B RJ01 at 250,000, twelve channels, all eight data bits
without parity and inverted only when the setting asks. The Spektrum frame status takes the RSSI channel
setting, and its frame time goes to the RC smoothing. The XBUS frame status gives no frame time, so the
smoothing measures the frames' arrivals. A VTX control word in a Spektrum frame goes unused until the
board's VTX control takes one, and SRXL waits for its half-duplex telemetry.

The host smoke check's receiver phase adds Spektrum 2048 and XBUS mode B frames with the same channels.

## D444. STM32F4 half-duplex receiver ports (2026-10-27)

The board opens the serial receiver on its UART's transmit pin alone when the half-duplex setting asks,
for every protocol it reads but CRSF, which takes both pins whatever the setting. The single wire is
push-pull with a pull-down when the line is inverted, and open drain with a pull-up otherwise. The link
keeps its inversion and its line, so a CRSF baud change reopens the port as it was opened, where it had
dropped the inversion.

The host smoke check's IBUS phase sets the half-duplex setting, and the channels still arrive.

## D445. STM32F4 FPORT receiver (2026-10-27)

The board reads an FPORT receiver's control frames on the serial receiver UART at 115,200 baud, eight data
bits without parity, inverted only when the setting asks and on one wire when the half-duplex setting asks.
The bytes go through the core's FPORT unstuffing into its ring of frames, and the frame status after the
realtime tasks checks each frame's length and FrSky checksum, decodes the SBUS channel block and the RSSI,
and keeps the frame time for the RC smoothing. The RSSI comes from the protocol unless another source is
set. The core runs without its telemetry layer, so telemetry requests go unanswered and the reply window
stays unused until the board sends SmartPort telemetry over FPORT.

The host smoke check's receiver phase adds FPORT control frames, stuffed and checksummed, with the same
channels.

## D446. STM32F4 SmartPort telemetry (2026-10-27)

The board answers a FrSky receiver's SmartPort polls on the telemetry port of the first provider with the
SmartPort protocol, at 57,600 baud whatever rate the provider names, inverted unless the telemetry's
inversion setting says otherwise, and on one wire when the telemetry's half-duplex setting asks. The core's
SmartPort stream builds its value tables at boot from the sensors the configuration leaves enabled, the
battery meters configured, the accelerometer and the GPS feature. Each telemetry task run takes the bytes
received up to a complete poll, keeps the rest for the next run, and sends the next value when the poll
names this sensor, within one pass over the tables. The values come from the battery, the altitude and
climb rate, the attitude, the accelerometer, the arming and the modes, the GPS, the ESC sensor, and the
current profiles' gains and rates. SmartPort runs before LTM and MAVLink in the port checks and the task.

The telemetry port generic gains a fixed rate, the inversion default and the half-duplex setting for a
protocol that takes it. LTM and MAVLink now follow the telemetry's inversion setting.

The host smoke check sets SmartPort on UART3 with a fresh store, polls the sensor every 12 ms, and finds
checked data frames with the battery voltage among them.

## D447. STM32F4 FrSky hub telemetry (2026-10-27)

The board sends the FrSky hub telemetry stream on the telemetry port of the first provider with the FrSky
hub protocol, at 9,600 baud whatever rate the provider names and inverted unless the telemetry's inversion
setting says otherwise. The core's hub stream sends its burst of frames every 125 ms from the clocks, the
accelerometer, the combined ESC reading, the GPS, the battery, the altitude estimate with its climb rate,
and the heading. Its settings come from the telemetry and motor groups with the accelerometer's scale and
no barometer, and the GPS counts as present with the GPS feature on, where the reference asks whether the
GPS sensor reports at each cycle. The hub stream runs first in the port checks and the telemetry task.

The host smoke check sets the hub protocol on UART3 with a fresh store and counts six to fourteen
acceleration frames in 1.3 s.

## D448. STM32F4 Ghost receiver (2026-10-27)

The board reads an ImmersionRC Ghost receiver on the serial receiver UART at 420,000 baud on the transmit pin
alone, push-pull, with a pull-down when inverted and a pull-up otherwise, inverted only when the setting asks.
The bytes go through the core's Ghost frame assembly into its pair of buffers, and the frame status after the
realtime tasks checks each frame's CRC and asks for processing. The receiver's channel calculation runs the
protocol's processing first, so the board calls the Ghost processing before it reads the raw channels when the
receiver holds a processing request. The processing decodes the link statistics, with the RF protocol that
lets the channels decode, and the twelve-bit primary channels with the aux channels. The RSSI and the link
quality come from the protocol unless other sources are set. The Ghost telemetry waits, so the processing
never finds a reply queued.

The host smoke check's receiver phase adds Ghost frames in turn, one with the link statistics and the normal
RF protocol, one with aux channels 5 to 8, each with its CRC8.

## D449. STM32F4 Jeti EX Bus receiver (2026-10-27)

The board reads a Jeti EX Bus receiver on the serial receiver UART at 125,000 baud on the transmit pin
alone, open drain with a pull-up or push-pull with a pull-down when inverted, inverted only when the setting
asks. The bytes go through the core's EX Bus frame assembly at their arrival times, and the frame status
after the realtime tasks decodes the sixteen channels once a channel frame's CRC reads zero and keeps the
frame's time for the RC smoothing. The EX Bus telemetry waits, so the request frames go unanswered.

The host smoke check's receiver phase adds EX Bus channel frames, each with its reflected CRC16, with the
same channels.

## D450. STM32F4 iBus telemetry (2026-10-27)

The board answers a FlySky receiver's iBus sensor polls on the telemetry port of the first provider with the
iBus protocol, at 115,200 baud whatever rate the provider names, always on the transmit pin alone, and
inverted when the telemetry's inversion setting asks. Each telemetry task run hands every byte received to
the core's iBus sensors, which find a request through a four-byte window, skip the echo of each answer by
its length, and answer from the sensor table the configuration names, with the first address polled as its
base. The values come from the battery, the arming, the throttle and the modes, the accelerometer, the
attitude, the climb rate and the GPS, with no barometer and no gyro temperature on the board. iBus runs last
in the port checks and the telemetry task, after the CRSF telemetry. The telemetry port generic gains the
single-wire choice for a protocol that always takes one wire.

The host smoke check sets iBus telemetry on UART3 with a fresh store, sends a discovery, a sensor type and a
measurement request for address 1, echoing each answer back as the single wire would. It finds the discovery
answered and the type and value replies.

## D451. STM32F4 Ghost telemetry (2026-10-27)

The board sends Ghost telemetry on the Ghost receiver's wire when the telemetry feature is on and a Ghost
link is open at boot. The schedule comes from the configuration: the battery pack frame when a configured
voltage or current meter has its telemetry sensor enabled, and the two GPS frames when the GPS feature is
on with their sensors enabled. The board has no barometer and no magnetometer, so the frame with the heading
and the barometric altitude never enters the schedule.

The receiver's link statistics turn the telemetry on when they name the normal, race, long range or race 250
RF protocol. From then on the telemetry task builds the next frame in the schedule once 100 ms divided by
the schedule's length has passed since the last one, after the CRSF telemetry and before iBus. The frame
waits in the radio until the Ghost processing finds the receiver's quiet window, between 1 and 2 ms after
the end of a received frame, and the radio writes it on the same wire. A newer frame replaces one still
waiting. The values come from the battery, the arming, the GPS with its home, the altitude estimate and the
attitude's heading. MSP over the Ghost link is not on the board, so the receiver's MSP frames go unanswered.

The host smoke check turns the telemetry feature on with the Ghost receiver on UART3 and a fresh store,
sends the two Ghost frames in turn, and finds at least ten 14-byte frames addressed to the receiver with a
CRC8 that checks, all of them the battery pack frame.

## D452. STM32F4 MSP over CRSF (2026-10-27)

The board answers MSP requests that arrive over the CRSF link, which tuning scripts on the transmitter use. A
request or write frame from the receiver goes, past its destination and origin, into a 96-byte buffer behind
its length when the buffer has room, and makes a reply to its origin due. The next telemetry task run after
the speed negotiation serves the buffer in place of the scheduled frames and restarts the telemetry's cycle.
Each frame goes through the core's MSP tunnel in order, a completed request goes through the board's MSP
processor with the views taken fresh as the serial task takes them, and the reply goes back in MSP response
frames of up to 58 bytes behind the tunnel's status byte, one chunk per run. A reply under way holds back the
requests waiting behind it until a new request frame makes a reply due again. A reboot that a request asks
for happens before its reply goes out.

The tunnel's reply takes a full 512-byte payload when the verdict is not an error, so the processor's largest
reply passes whole. The error byte still needs one byte of room.

The host smoke check sends an API version request and an adjustment ranges request as CRSF MSP frames from
the transmitter's address. It finds the API version answered to that address, and the 300-byte adjustment
ranges in six chunks under the jumbo size with their sequence numbers in order, equal to the serial MSP reply.

## D453. STM32F4 available mode boxes (2026-10-27)

The board computes the mode boxes it offers, which the MSP box names and box ids replies list thirty-two to a
page and the status reply's flight mode flags count. The board had handed the switched-on boxes in their
place, so both replies came back empty with no switch on and the mode flags sat at the wrong positions.

The arm, prearm, failsafe, beeper, beeper mute, OSD, paralyze, stick commands disable, ready, blackbox,
blackbox erase, camera control, video transmitter, autopilot, waypoint capture, PID audio, launch control,
lap timer reset and chirp boxes are always offered. The air mode box joins without the air mode feature, anti
gravity when a PID profile has an anti gravity gain and the feature is off, and the telemetry, LED low, 3D and
camera stabilization boxes with their features. An accelerometer adds angle, horizon, altitude hold, position
hold, headfree, heading adjust, FPV angle mix, acro trainer and, with its feature, in-flight calibration. The
GPS feature adds the satellite count beep and, without 3D and a fixed-wing mixer, the GPS rescue. A wing
mixer adds passthrough, a custom airplane the three servo boxes, a DShot motor protocol the crash flip, a
PINIO output the user box it watches, and the MSP override its box when it names channels. The board has no
magnetometer. The set follows the build's options: acro trainer, flight plan, camera control, video
transmitter control, PID audio, launch control, lap timer and chirp are in, and the wing build is out. The
board sets it at each configuration load and again once the sensors and the mixer are known.

The host smoke check reads the box names from ARM, ANGLE, HORIZON, ALTHOLD and HEADFREE on, without AIR MODE
under the air mode feature, thirty-two ids on the first page and the lap timer reset and waypoint capture ids
on the second.

## D454. STM32F4 MSP over Ghost (2026-10-27)

The board answers MSP requests over the Ghost link. The receiver task's Ghost processing hands an MSP request
or write frame's payload, past its address, length and type, to the MSP tunnel the CRSF link uses, and a
completed request goes through the board's MSP processor at once. The receiver step becomes a generic over the
processor, as the telemetry step is. Any request the tunnel answers makes a reply due. The next Ghost
telemetry run restarts its cycle and, while no frame waits for the quiet window, queues the reply's next chunk
in place of the scheduled frames: six bytes of the tunnel behind the response type, zero-filled to the
frame's ten-byte payload, with its CRC8. The board processes the requests with the telemetry feature off as
well, but their replies need the feature and an RF protocol with telemetry.

A reply that fills its chunk exactly ends with an empty chunk holding only its status byte, so the API
version takes two frames.

The host smoke check sends an API version request and an adjustment ranges request as Ghost MSP frames in
place of channel frames. It finds the version in two chunks and the 300-byte ranges in sixty-one, equal to the
serial MSP reply.

## D455. STM32F4 RunCam device (2026-10-27)

The board controls a RunCam camera on the UART the camera setting names, at 115,200 baud, when the receiver,
the GPS, the ESC sensor and the video transmitter leave that UART free. The start asks the camera for its
device information. The camera task at 20 Hz hands the core's RunCam unit every byte received, keeps the bytes
the unit does not take for the next run unless a request flushed them, and sends what the unit writes. The
camera boxes press the camera's WiFi, power and mode buttons once per activation, the WiFi and mode buttons
only while disarmed and while no runaway or crash disarm holds the arming. The sticks drive the five key cable
under the same arming conditions, with the menu closed and the stick commands enabled, and the cable's
connection beeps when it opens and closes. A camera that offers the attitude feature gets the attitude in
decidegrees on its requests.

The host smoke check runs a camera on UART4 that answers the device information request with protocol 1.0
and its three buttons. It finds the request at the start and one WiFi button press after the camera control 1
box on AUX1 switches on.

## D456. STM32F4 Jeti EX Bus telemetry (2026-10-27)

The board answers an EX Bus receiver's telemetry requests when the telemetry feature is on and an EX Bus link
is open at boot. The telemetry task runs the core's EX Bus telemetry after the LTM telemetry and before
MAVLink, over the receiver's request frame. A request older than 3 ms is dropped, one that is not a telemetry
request or fails its CRC is dropped, and a fresh one gets its answer on the bus, which ends the receiver's
permission to transmit. The receiver port hands its bytes to the protocol as they arrive, so the check for
bytes waiting on the port always finds none. The first 255 answers describe the sensors, and the answers after
them carry the values of the enabled sensors.

The sensors read the battery, the altitude estimate and its climb rate, the attitude, the GPS with its home,
the accelerometer and the ESC sensor's motor readings. The board keeps no debug values, so with a debug mode
set the debug sensors read zero.

The host smoke check sends EX Bus channel frames and telemetry requests in turn on UART3. It finds at least ten
answers with a CRC16 that checks, each with the request's packet id and the EX telemetry header. One 4 s run
on the host answered 28 of about 140 requests.

## D457. STM32F4 MSP display port (2026-10-27)

The board draws the OSD and runs the menu over the MSP display port, which digital video goggle systems take
on a UART. The OSD start takes the MSP device for an HD video system whatever the display device setting
says, otherwise for the MSP setting, or for the automatic one when no MAX7456 answers, and the OSD feature
stays on with it. The port's canvas is the stored canvas for HD, else the PAL or NTSC lines and the standard
columns with the profile's adjustments, and the stored canvas fits to it. The OSD task's operations become
display port payloads sent as MSP replies with command 182: the heartbeat, the clear, the strings and
characters with the profile's font per severity and the device blink, the system elements, and the draw for
a redraw or a draw. The port has no layers, background, logo or transactions, and it is always ready and
never mid-transfer. The menu grabs it with a heartbeat and a clear, releases it with the release payload, and
spends the free transmit room of UART1 on its writes, each costing the frame it queued.

The frames go to the serial port the OSD's port setting names when the display device setting is MSP, else to
the first UART with an MSP video transmitter. The board serves MSP on UART1 alone, so the frames reach goggles
only there, and a frame that does not fit the transmit buffer is dropped. The display's UART, and one with an
MSP video transmitter or a lidar, carries a device's stream: its bytes never open the command line, ask for a
reboot or count as configurator activity.

The stored default video system is HD, so a MAX7456 board draws over MSP until the video system is set to an
analog one, as the configurator's OSD tab does when analog video is chosen.

The host smoke check sets the MSP device on UART1 and finds the heartbeat, clear, string and draw payloads
with the craft name, and UART1 still answering MSP. The MAX7456 phase now sets the PAL video system.

## D458. STM32F4 UART1 holders (2026-10-27)

The board serves MSP on UART1 only while no other device holds it: the receiver, the GPS, the ESC sensor, the
video transmitter, the camera, the flight log and the telemetry ports. The list had left out the receiver, the
GPS and the camera, which can all take UART1. With a receiver there, the MSP framing read the receiver's bytes
as well, so the receiver lost them, and a hash mark in the stream opened the command line on UART1, which
stops MSP on the USB port. The MSP framing also acts on the reboot character while the board is disarmed,
which resets it. The CLRacing F4S boards carry their receiver inverter on UART1, so SBUS takes that port.

The host smoke check puts a CRSF receiver on UART1 and finds its channels in the MSP reply over the USB port.

## D459. STM32F4 TF lidar rangefinder (2026-10-27)

The board reads a Benewake TFmini, TF02 or TFnova lidar on the UART the rangefinder setting names. The start
runs after the gyro, as the sensors start before the receiver: the hardware setting picks the core's TF
driver, which opens the port at 115,200 baud, sends the 100 Hz command to a TFmini or TF02, and reports a
10 ms period, the range and the cone. The rangefinder filter starts on that range and cone, and the
rangefinder task, enabled with the rangefinder feature, runs at the period the driver asked for. Each run
hands the driver every byte received through its frame parser, then filters the last reading through the
median and the signal ratio and corrects it by the cosine of the craft's tilt into an altitude.

The MSP status reply sets the rangefinder sensor bit, and the sonar altitude reply carries the last altitude.
The lidar's UART counts among the devices that keep UART1 from MSP. The OSD's distance element, the FrSky hub
telemetry and the flight log field do not read the rangefinder yet.

The host smoke check streams TFmini frames of 150 cm on UART4 and finds the sensor bit and a 150 cm sonar
altitude.

## D460. STM32F4 rangefinder in the flight log (2026-10-27)

The flight log takes the rangefinder: the header lists the `surfaceRaw` field when a rangefinder was found,
and each frame logs the rangefinder's distance after the median filter and before the tilt correction. The
reference logs the corrected altitude there, under a comment that says it stores the raw value (finding F299),
so the board follows the comment and the field's name. The MSP sonar altitude stays the corrected one.

The host smoke check's lidar phase sends the flight log to UART6 and finds `surfaceRaw` among the frame fields.

## D461. STM32F4 OSD lidar distance (2026-10-27)

The OSD's lidar distance element draws the rangefinder's altitude, the tilt-corrected one the MSP sonar reply
carries, in centimetres behind its label, or dashes while the rangefinder reads none. The board had left the
renderer's rangefinder input at zero, so a placed element showed dashes with a rangefinder working.

The host smoke check's lidar phase places the element on the MAX7456 with the PAL video system and finds
`RF:150` once the boot logo clears.

## D462. STM32F4 FrSky hub altitude from the rangefinder (2026-10-27)

The FrSky hub telemetry sends its vario and altitude frames when a barometer, a rangefinder or a GPS is
present. The board has no barometer and had passed no altitude sensor at all, so with the GPS feature off the
hub never sent them. A rangefinder found at the start now counts. The frames carry the estimated altitude
and climb rate, as with the other sensors.

The host smoke check's FrSky hub phase adds a TFmini on UART4 and finds the vario frame and both altitude
frames beside the acceleration frames.

## D463. STM32F4 Nooploop TOFSense rangefinder (2026-10-27)

The board's rangefinder also takes the six Nooploop TOFSense models on the rangefinder UART. The hardware
setting picks the driver: the TF lidars or the TOFSense through the core's Nooploop driver, which opens the
port at 115,200 baud, reports a 10 ms period, the model's range and a 90 degree cone, and parses the 16-byte
frames behind the 0x57 and 0x00 sync bytes. The TOFSense hands a new reading to the filter once, and between
frames the filter gets no new data and keeps its last altitude. After 200 ms without a frame the driver
reports a hardware failure. The HC-SR04, the MicoAir MTF and the UP-T1 wait for their drivers.

The host smoke check streams TOFSense F2 frames of 1234 mm on UART4 and finds a 123 cm sonar altitude.

## D464. STM32F4 SmartPort telemetry over FPORT (2026-10-27)

An FPORT receiver's telemetry requests get SmartPort values back in the FPORT reply window. The receiver opens
with its telemetry on whatever the telemetry feature says, and the SmartPort tables are built from the
configuration and the sensors right after it opens. The serial SmartPort telemetry then stays off, since the
FPORT receiver holds the SmartPort telemetry. When the receiver task processes a frame with a request waiting
and the window open, between 0.5 and 2 ms after the request, one pass of the SmartPort telemetry takes the
next value and writes it as the reply, with the reply's length and type in front and both counted in the
checksum. A pass that finds nothing to send leaves the window to the empty reply. MSP over FPORT waits.

The core's SmartPort writer gains the FPORT framing and a public frame writer for the empty reply, and its
transmit buffer grows to the 18 bytes an FPORT reply takes at most. The SmartPort oracle runs in an FPORT mode
with the FPORT receiver's reply writer copied from the reference source, and the sportfp vectors check 12,000
reply windows over ten configurations and the empty reply. The SmartPort unit proved with 172 checks and no
assumption. Five tampers of the framing (the length, the type, the checksum over the length, the order of the
two, and the serial framing in place of the FPORT one) all fail the vectors.

The host smoke check sends FPORT control frames and telemetry requests in turn on UART3 and finds SmartPort
replies with checksums that check, among them the battery voltage.

## D465. STM32F4 OSD custom text (2026-10-27)

A UART named by the custom text port setting sends the messages the OSD's custom serial text element shows. The
port opens after the GPS at the custom text rate, or at 115200 baud when that setting is automatic or past the
rate table, and stays closed when the rangefinder, the receiver or the GPS already holds that UART. The custom
text task runs at 100 Hz over every byte received since its last run, with a null or a line feed ending each
message as the terminator setting names. The element draws the first 31 characters of the last message, or
three dashes before the first message and after an empty one. With the custom text on UART1, MSP leaves UART1
to it, the same as for the other devices on that UART.

The core custom text unit and the element's rendering already replay their vectors, so this increment adds no
core change and no vectors.

The host smoke check sends messages on UART4 and finds on the OSD screen the text without its carriage return,
a message sent in two parts joined, and the dashes after an empty message. A second boot with the text on UART1
finds the text on the screen, no MSP reply on UART1 and MSP replies on the USB port.

## D466. STM32F4 gimbal control (2026-10-27)

A gimbal on the UART the gimbal port setting names gets its command frames from the gimbal task at 100 Hz. The
port opens at 115200 baud after the video transmitter, when the rangefinder, the receiver, the GPS, the custom
text, the ESC sensor and the video transmitter leave that UART free. A head tracker on the same UART sends its
frames to the board. Each frame whose CRC checks goes on to the gimbal at once, with its angles scaled to the
gimbal's range, mixed with the sticks, offset and limited by the gimbal settings. Other bytes pass through
unchanged, a lone first opcode byte as itself (D128). With no head tracker bytes for 250 ms, each run sends a
frame from the sticks alone. Without a port the task stops on its first run. With the gimbal on UART1, MSP
leaves UART1 to it.

The core gimbal unit already replays its vectors, so this increment adds no core change and no vectors.

The host smoke check puts the gimbal on UART4 and reads checked frames about every 10 ms with no roll or yaw,
mode 0 and sensitivity 15. A head tracker frame with a roll of 900 comes back at once with the gimbal's roll of
500, and the bytes `AB`, 16#A5# and 16#41# come back unchanged.

## D467. STM32F4 GPS lap timer (2026-10-27)

The GPS lap timer runs on the board with the GPS feature. It starts at boot from the stored gate. Each new GPS
solution with a fix goes to it in the GPS task, right after the home vector: the distance and bearing to the
gate, then the gate average while the gate is being set, the reset while the lap timer reset box is active, or
the lap detection. The board's GPS task reports a count of solutions, so it calls the lap timer once per new
solution stamp, and two solutions completed in one task run reach it as the last one. At 10 Hz solutions this
takes a GPS task held off for 100 ms. The OSD's current, previous and best three lap elements, the home arrow
and distance turned to the gate while the timer runs, and the best lap and best three statistics read the
timer. The GPS lap timer menu's set position entry starts the gate setting on entry and ends it on exit. The
averaged gate then goes into the configuration and into the menu's copy of it, so a save from the menu stores
it, and the entry shows the readings taken and the distance to the gate.

The lap timer measures laps on the solution's time. The NMEA parser of the reference never sets that time
(F297), so with an NMEA module the reference's lap timer reads zero at every fix: the first gate pass starts the
timer and no lap is ever recorded (F300). The board gives the lap timer and the current lap element the clock at
each solution as the time for an NMEA module, and the module's time of week otherwise (DIVERGENCES.md). The
flight log keeps the module's own time, as D412 has it.

The core lap timer, its OSD elements, its statistics and its menu already replay their vectors, so this
increment adds no core change and no vectors.

The host smoke check sets the gate at the GPS phase's fix with a one-second minimum lap and sends NMEA fixes at
the gate for 0.6 s and 185 m north of it for 1.4 s in turn. The OSD shows a previous lap of about two seconds.
With the module's time in place of the clock, the same check shows 0.00, the reference's result.

## D468. STM32F4 menu on a CRSF transmitter's screen (2026-10-27)

The menu system runs on a Crossfire transmitter's screen through the CRSF display port. With the telemetry
feature on and a CRSF receiver open, the board registers the transmitter's display with the menu after the
OSD's, at the largest screen of 9 rows by 32 columns. A display port command from the transmitter opens the menu
on its display at the rows and columns the command names, closes it, or polls it. The open selects the
transmitter's display and opens the start menu over the live configuration, and the transfer then waits 400 ms.
The menu's draws on that display go into the CRSF screen, and the CRSF telemetry sends the screen's changes as
run-length encoded chunks while the menu shows there and the transfer delay has passed. The CRSF display has no
layers, background or heartbeat, and its writes cost nothing against the draw budget. The menu stick command
moves an open menu between the OSD and the transmitter.

The board runs a command after the receiver step that took it, in the receiver task, where the reference runs it
in the CRSF byte handler. The core's display model keeps at least 8 rows, so a transmitter screen of fewer rows
gets the menu laid out on 8 rows and loses the rows past its own. A size from an open command that arrives while
the menu is open waits for the menu to close.

The transmitter's close leaves the menu on the display it shows on (F301, DIVERGENCES.md). The reference exits
with the transmitter's display, so a menu moved to the OSD and then closed from the transmitter leaves the OSD
held and frozen on the last menu frame.

The core's menu navigation gains the display select. A registered display becomes current, and an unregistered
one leaves the current display after a full turn, the last display when none was current. The select requires a
closed menu, as both reference callers have it. The unit proved through the menu navigation's shape (304 checks,
no assumption). The menu oracle runs the select alone in a select mode with none to four displays and 40 selects
per sequence, and the menusel vectors check 12,000 selects for the answer and the current display. Three tampers
(the last display's fallback set to the first, the fallback dropped, and the registered test off by one) all fail
the vectors.

The host smoke check opens the menu from a CRSF receiver emulator and decodes the quick menu, the start menu by
default, from the display port frames. A close brings the screen's clear frame. A second open, the menu stick
command and a close then show the menu on the OSD and the OSD drawing its elements again. With the transmitter's
display registered, a menu stick command held past its 500 ms pause moves the menu on to the next display, so the
smoke check's stick commands hold for 0.3 s.

## D469. STM32F4 OSD PID and profile name elements (2026-10-27)

The OSD's roll, pitch and yaw PID elements and its PID and rate profile name elements read the current profiles.
Each OSD frame takes the current PID profile's P, I, D, D max and feedforward gains for the three axes and the
names of the current PID and rate profiles from the live configuration, so an adjustment, an MSP write or a
profile change shows at the next frame. The board had left these inputs at their defaults, so a placed PID
element showed zeros and a named profile showed its number.

The host smoke check sets distinctive roll gains and both profile names, places the three elements, and finds
`ROL  47  83  31  42 125`, `SNAPPY` and `FREESTYL` on the screen. The previous image shows zeros, `PID_1` and
`RATE_1`.

## D470. STM32F4 OSD watt hours drawn (2026-10-27)

The OSD's watt hours element and the statistics page's used watt hours read the battery's energy drawn, which the
battery adds up from each change of the drawn charge times the battery voltage. The board had left both inputs at
zero. The element's range starts at zero, so an energy below zero, from a current sensor reading below zero,
shows as zero.

The host smoke check takes the battery's voltage and current from the ESC sensor, whose emulator reports 16.1 V
and 77 mAh drawn per ESC, and finds a nonzero energy on the element. The previous image shows 0 mWh. The value
depends on the filtered voltage when the ESCs' charge first arrives, so the check asks for a nonzero energy only.

## D471. STM32F4 OSD flight log status (2026-10-27)

The OSD's log status element shows while the flight log box is active, and the board now gives it the box and
the log device's state. The device works as a serial port while the log holds it open, as an SD card that is
inserted and working with its file system ready, and as a flash chip that is ready. The element shows an
exclamation mark for a device that does not work, a greater-than sign for a full one, and else the largest log
file number on an SD card. The device's state is read only while the box is active, so the flash chip's ready
check runs only then. The board had left these inputs unset, so the element never showed.

The host smoke check logs to an SD card image with the box on AUX1 over its whole range, and finds log number 1
beside the log symbol once the card's log opens. The previous image leaves the row blank.

## D472. STM32F4 OSD aux value (2026-10-27)

The OSD's aux value element shows the configured aux channel, scaled, with the configured symbol. Two links were
missing. The core's OSD task gave the renderer the timer clocks and not the aux value its page refreshes once a
second, so the element always showed 0. The task's draw context now takes the page's aux value too. The board
never gave the page the aux channel's pulse, so the page kept its 1500 us default. The board now reads the
channel the aux channel setting names, after the four flight channels.

The aux channel setting takes 1 to 18 while there are 14 aux channels. The reference reads past the end of its RC
data for the settings 15 to 18 (F302). The board reads such a setting as the lowest pulse, so the element shows 0
(DIVERGENCES.md).

The OSD task oracle now draws the aux value element with a random symbol and aux channel and writes the symbol at
the start of each sequence, and the regenerated osdtask vectors check it. Without the draw context's aux value,
98 of their draw checks fail. The OSD task unit proved with 89 checks and no assumption. The host smoke check
holds AUX1 at full deflection from a CRSF receiver emulator and finds `A200` on the MAX7456 screen.

## D473. STM32F4 OSD flight state elements (2026-10-27)

The OSD's flight state inputs that the board had left at their defaults now come from the flight. The READY
element reads the ready box, and the flight mode element's ATRN reads the acro trainer box. The flights element
reads the stored total flights. The crash flip arrow reads the crash flip state, whether the craft is upright and
the small angle. The up and down reference reads the earth's up in the body frame, the attitude rotation's up
row. The RSSI dBm element reads the CRSF link's active antenna. Whether the craft is upright is one function now,
which the arming checks and the flight log read as well.

The host smoke check puts the two boxes on AUX1 and stores seven flights, and finds READY, #7 and ATRN on the
screen. The previous image shows no READY, #0 and AIR. The crash flip arrow, the up and down reference and the
antenna need a tilted craft or a CRSF link's statistics, which the host check does not provide.

## D474. STM32F4 OSD video transmitter element (2026-10-27)

The OSD's transmitter channel element reads the transmitter through the board now: whether a device is present,
its status word when the device answers, its power index when the device knows it, the VTX table and the
transmitter control disable box. The status word holds the pit mode in bit 0 and, for Tramp, the race lock in
bit 1. It comes from the common status query, apart from Tramp, whose race lock only its driver reports. The
board had left these inputs at their defaults, so the element showed question marks with any device.

The host smoke check stores a one-band VTX table with band 1, channel 1 and the first power level, runs the
SmartAudio emulator, and finds A:1:25 on the screen. The previous image shows ?:?:?.

## D475. STM32F4 OSD names and custom messages (2026-10-27)

The OSD reads the pilot name and the four custom messages from the stored configuration at each frame, and its
craft name buffer starts each task state from the stored craft name. The board had set the names only when it
configured the OSD: at boot, after a menu change and after an MSP write of an element or a profile. A name written
over MSP showed only after the next of these, and the custom message elements never got their text.

With the craft name messages on, the warnings element writes its text into the craft name buffer, and the craft
name element draws from that buffer. The flight now writes the buffer back into the stored craft name after each
state, so the MSP name reply, the command line and the flight log header show the warnings text too, and a save
stores it.

The host smoke check places the custom message, craft name and pilot name elements over MSP, writes a message and
both names over MSP while the image runs, and finds them on the screen. It then turns the craft name messages on
and finds the link quality text in the MSP name reply and in the craft name element. The previous image keeps the
placeholders after the writes and replies with the stored craft name.

## D476. Battery meters at the measured supply (2026-10-27)

The battery's analog voltage and current meters scale their counts by the analog supply in millivolts,
given with the other meter inputs. The core had used a fixed 3300 mV. On the STM32F4 the reference measures
the supply through the internal reference channel (D477) and scales both meters by the measured value.
The supply input ranges from 0 to 16000 mV, which keeps the current within its centiampere range at every
current scale. The voltage product wraps in 32 bits as the reference's does.

The battery generator draws the supply each step from its own random stream, so the other draws stay as they
were: 3300 mV in every fifth sequence, else a level from 2900 to 3600 mV with a 15 mV jitter, and in one
sequence kind a reading anywhere up to 16000 mV one step in 40. The sequences at 3300 mV replay the earlier
vectors line for line with the supply column added. Every voltage, current, state, energy and percentage of
the regenerated battery, sag and event vectors replays bit for bit.

## D477. STM32F4 core temperature and measured supply (2026-10-28)

The board converts two internal channels of ADC1 as an injected sequence of 480 sample cycles each: the band gap
reference on channel 17, then the temperature sensor on channel 16. Scan mode and the sensors are on. The
calibration comes from the stored overrides, or from the chip's words where an override is zero. Nine passes of
the internal ADC task at startup fill the averages, the first of them on the empty result registers. The task then
runs at 1 Hz: once the started conversion ends, it hands both readings to the internal ADC unit (D75) and starts
the next conversion.

The measured supply scales the battery's analog meters (D476), held to 16000 mV. The core temperature reaches the
MSP status reply, the command line's status line and system values, the OSD's core temperature element and
warning, and SmartPort's T11 sensor. A conversion of an analog pin now clears only its own end of conversion flag,
so it leaves the flag that ends the internal sequence alone.

The slope is eighty degrees in thousandths over the difference of the two sensor calibration readings, zero for
equal readings as the processor's division gives (F303), and held to the internal ADC unit's bound of ten thousand
(F96). Only overrides fewer than eight counts apart reach the bound.

The host model reads 1489 and 973 once the first conversion starts, with calibration words of 1489, 940 and 1200,
a supply of 3300 mV and 40 degrees. The host smoke check finds Vref=3.30V and Core temp=40degC in the status
line, 40 in the MSP status reply, and Cz 40 on the OSD's core temperature element.

## D478. Servo mixer (2026-10-28)

The servo mixer unit contains the servo setup, the mixing and the order of the servo writes without the
outputs. The setup marks the mixer as driving servos when its mode does, with the servo tilt or channel
forwarding feature on, or when any servo forwards a channel. It loads the mode's rules, or in the custom
airplane and custom tricopter modes the custom rules up to the first with a zero rate, and starts each servo's
lowpass filter at the PID loop's period when a cutoff is set.

Each update mixes every rule without a box or with its servo box on. The rule's output follows its input at the
rule's speed when one is set, scales by the rule's rate, holds to the rule's share of the servo's span and adds
to the servo, reversed where the servo reverses that input. Each servo then takes its rate and adds its middle,
or its forwarded channel scaled to its span. With the servo tilt feature the gimbal pair take their middles or
channels and, while the camera stabilization box is on, the attitude, mixed in the mixed tilt mode. The servos
hold to their limits, pass the lowpass filter rounded to even when a cutoff is set, and hold to their limits
again. The writes follow in order: the mode's servos, the gimbal pair with the tilt feature or in the gimbal
mode, each forwarding servo not yet written, then the aux channels from the first forwarded channel. The
bicopter, dualcopter, helicopter and singlecopter writes come only in builds with the uncommon mixers.

The reference's 16-bit stores wrap, and the unit wraps them the same way. A rule naming a servo past the eight or
an input past the fourteen, which the configuration's checks never let in, is skipped where the reference would
index past its arrays. A forwarded channel scaled past the 16-bit range, or a filter output past 2 to the 24th,
holds at the bound where the reference's conversion is undefined. No recorded vector reaches these guards.

The harness replays 60 sequences of 200 updates recorded from the reference across fifteen mixer modes, with
drawn features, servo parameters, custom rules, filter cutoffs, gimbal modes and receiver settings. Every setup
result, servo value, write index and write value replays bit for bit.

## D479. Resource and DMA commands (2026-10-28)

The command line contains the resource command and the DMA command. The resource table lists each pin owner the
build names, how many pins it has and the configuration field that keeps each one, in the order the reference's
table lists them. Without arguments the command prints the pins set. With an owner's name, matched without case,
and an ordinal it prints, sets or frees that pin, and a single pin takes its ordinal or none. A pin is a port
letter from A to I and a number from 0 to 15, read as the C library reads it, and pins exist on the F405's ports A
to F. Setting a pin notes each other owner holding it and clears it where the same owner holds it at another
ordinal. The dump prints the resources after the craft name, each pin against its default, with a changed pin's
default first after a number sign.

The DMA command lists the sixteen DMA streams of the STM32F4 with the motor each drives, or free. The board fills
each DShot motor's stream. Its other peripherals run without DMA and hold no stream.

The resource table has no ESC serial entry: that pin belongs to the ESC serial driver, which adaflight does not
port, and the configuration has no ESC serial group. resource show lists no pins, since the board does not track
each pin's owner yet. resource show without a second word reads no word as not all, where the reference compares a
null pointer (F304).

The command line oracle builds with resource management on, an F405 pin model for the pins the resource command
accepts, and the F4's DMA display functions with every stream free. The resource family holds 1200 commands: names
in any case and past the table, ordinals inside, at and past each owner's count, pins on and off the F405,
malformed pins, none, conflicts, the show and DMA commands and dumps and diffs between them. The help, completion,
dump, diff and every-profile families gain the two commands and the resources section, replayed from their
recorded inputs through the new oracle. Every reply replays byte for byte.

## D480. Menu tables cleared line by line (2026-10-28)

A menu cleared its table with a copy of `Empty_Table`, a constant of 192 label lines in flash (D404). `Clear` now
sets each of the table's lines to one constant label line and the count to one, and the table constant is gone. The
postcondition of `Clear` states each line's value, for the proofs of the menu loaders.

On the STM32F4 image the change removes 18852 bytes of text, from 749820 to 730968. The menu vectors replay
unchanged.

## D481. Name texts in pools (2026-10-28)

Fourteen functions returned a name from a case expression over string literals: the flight log header's labels and
field names, the command line's command words and names, its feature, beeper, mixer, gyro and resource owner names,
the MSP box names, the scheduler's task names, the serial claim names, the arming reasons and the board's adjustment
labels. GNAT compiles each alternative of such a function to a secondary stack allocation and a copy of its literal,
about 22 bytes of code per alternative, and each literal keeps its own bounds. Each function now slices one text of
its names by a start and a length from two tables, the layout D410 gave the settings table. A name already in the
text takes the start of that copy, and the command names take theirs in the command word text. The arming reasons
and the header's field names moved from the specifications to the bodies, each with a postcondition on its length.
The resource owner names keep their first index of one.

On the STM32F4 image the change removes 23944 bytes of text, from 730968 to 707024, 10072 of them for the header's
labels. The vectors and the host smoke check replay unchanged.

## D482. Help texts in a pool (2026-10-28)

The help command called its entry printer once per command with the command's name, description and argument list
as literals, 4260 bytes of code in the board image. The descriptions and argument lists now sit in one text with a
start and a length for each, the names come from the command name table, and the command walks the commands in a
loop. The argument lists keep their line breaks and tabs as characters of the text.

On the STM32F4 image the change removes 3872 bytes of text, from 707024 to 703152. The help vectors replay
unchanged.

## D483. Setting values through the codec (2026-10-28)

`Get` and `Set` (D164, D165) read and wrote each setting through its own alternative of a case over every setting,
20096 bytes of code in the board image. A setting's value now lives in the bytes of its group in the codec's layout
(D166). `Get` encodes the setting's group, or its profile's element, into a buffer and reads the setting's bytes at
its offset. `Set` writes the bytes there and decodes the group back. The generator gives each setting its offset in
that layout and a format: one, two or four bytes, signed or not, a bit of such a word, or a text the numbers leave
to `Get_Text` and `Set_Text`. The format takes the field as the reference's command line reads it through the
setting's type: the low bytes of a wider field, a Boolean's byte, and the field's own sign where the setting's type
is as wide or wider. A write stores the bytes the read takes, which truncates the value as the reference's
assignment through the setting's type does.

The codec's encoder and decoder walk the registry and each profile group's profiles through one dispatcher per
direction, which the setting accessors share, and a profile group's array has no codec of its own. The storage image
keeps its layout.

On the STM32F4 image the change removes 12028 bytes of text, from 703152 to 691124. The setting, write and storage
vectors replay unchanged.

## D484. Command line output in pieces (2026-10-28)

The command line wrote 190 of its lines as one concatenation: the literals, the numbers from `Decimal` and the names
joined on the secondary stack, then one `Put`. GNAT builds each concatenation with its lengths, an allocation and a
copy per operand, about 80 bytes of code a line in the board image. These lines now put each run of literals and
each other operand in turn, and an error line starts with `Put_Error` on its first part. The setting lines of a dump
were already written this way, and every line's text is the same.

On the STM32F4 image the change removes 15516 bytes of text, from 691124 to 675608. The command line vectors replay
unchanged.

## D485. Menu line builders (2026-10-28)

Twenty-eight places in the menu content built an empty text with `Label ("")`, the line builder's default for its
shown text among them, and each of the line builder's 131 calls inlined its expression body. The empty text is now a
constant, and the line builder is a function called out of line whose postcondition states the line it builds, for
the proofs of the menu loaders.

On the STM32F4 image the change removes 4524 bytes of text, from 675608 to 671084. The menu vectors replay
unchanged.

## D486. Settings info in six bytes (2026-10-28)

The settings table kept each setting's info as a packed record of 15 bytes, two thirds of it the minimum and maximum
of 34 bits each and the group number. The generator now gives the distinct pairs of limits and the distinct group
numbers a table each, 155 pairs and 81 groups for the oracle's build, and each setting's packed record keeps an index
into each, six bytes in all. `Describe` builds the full record from the three tables, so its callers read the same
info.

On the STM32F4 image the change removes 4872 bytes of text, from 671084 to 666212. The settings vectors replay
unchanged.

## D487. Setting names in pair codes (2026-10-28)

The 789 setting names took 13947 characters of flash. The generator now merges the most frequent pair of codes into
a new code, 128 times, as byte pair encoding does, so a name is a run of codes: one below 128 is its character, a
higher one stands for the token text of its merge. The names take 7566 codes and the tokens 367 characters. `Name`
decodes a name's codes up to its length into a new string, and the codes and the tokens end with room for a longest
name and token, so every read stays within them by the types alone. The codes sit in a function whose body is outside
the proof: the decoder needs no fact about them, and a proof that took in all 7566 values ran out of memory.

On the STM32F4 image the change removes 5612 bytes of text, from 666212 to 660600. The settings and command line
vectors replay unchanged.

## D488. Flight log labels from setting names (2026-10-28)

170 of the flight log header's 229 labels are a setting's name. Those labels now come from the settings table's
names (D487) through a table of each label's setting, and the header's own text keeps the 59 other labels in 824
characters, where it held all of them in 3777.

On the STM32F4 image the change removes 2428 bytes of text, from 660600 to 658172. The flight log header vectors
replay unchanged.

## D489. Static flight log header tables (2026-10-28)

The flight log header's field tables and line lists were aggregates of calls to small constructor functions, so
GNAT built them in RAM at elaboration with 3928 bytes of code. They are now plain record aggregates of static
components, which GNAT places in flash, and the constructors are gone.

On the STM32F4 image the change removes 1124 bytes of text and 2536 bytes of zeroed data, from 658172 to 657048 and
from 154592 to 152056. The flight log vectors replay unchanged.

## D490. Codec by runs of bytes (2026-10-28)

The codec (D166, D483) wrote and read every field of every record through its own procedure call, 16 KB of code in
the board image. The generator now lays out each group's record as GNAT does, every component at the next offset its
alignment allows, and merges the fields that lie next to each other into runs, 241 for the oracle's build. Each run
is an offset, a byte count and whether its bytes are Booleans. The codec copies a run's bytes between the
configuration record and the data through an overlay at the record's address, and a Boolean byte read from the data
becomes false for zero and true for any other value. Both targets are little-endian, and the data's layout keeps its
order and widths.

The board's debug information gives the same offset for each of the 4591 bytes as the runs, in all 101 groups. On
the STM32F4 image the change removes 22328 bytes of text, from 657048 to 634720. The codec, storage and setting
vectors replay unchanged.

## D491. Table elements at their width (2026-10-28)

A beeper sequence kept each of its 65 steps, from 0 to 255, as a 32-bit integer, and each MAVLink message entry its id
and three bytes as four 32-bit integers. The sequences now take 8 bits per step, and the entry record is packed into
24 bits of id and 8 bits for each byte, 6 bytes where it took 16.

On the STM32F4 image the change removes 5788 bytes of text, from 634720 to 628932. The beeper and MAVLink vectors
replay unchanged.

## D492. Menu value names in a pool (2026-10-28)

Sixteen menu name tables and the active elements table held their names as labels that calls built at elaboration:
66 value names and 77 element names, each label 36 bytes of RAM, set by 2660 bytes of elaboration code. The names now
sit in one text of 1092 characters. Each table holds a start and a length for each of its names, and `Pooled` builds
the label when a menu line asks for it. The active elements table keeps each element beside its name's start and
length, in flash.

On the STM32F4 image the change removes 2384 bytes of text, from 628932 to 626548, and 5448 bytes of RAM. The menu
runs recorded before replay unchanged. A new oracle run pages down through the active elements menu twice and turns
every fifth element over, so the vectors now draw 137 of the 138 names. SmartAudio's offline status name is the one
left out.

## D493. Command line numbers and names put directly (2026-10-28)

The command line passed 226 decimal numbers to `Put` as the result of `Decimal`, and 51 more texts from seven other
functions the same way. GNAT returns such a result on the secondary stack, so each of the 277 call sites marked the
stack and released it, about 20 bytes of code per site. Each of the eight functions now has a `Put_` procedure that
calls `Put` with its result, and the call sites call that procedure. The procedures stay out of line, so the stack
handling sits in eight places.

On the STM32F4 image the change removes 5648 bytes of text, from 626548 to 620900. The command line vectors replay
unchanged.

## D494. Command line argument text taken once (2026-10-28)

The command dispatcher passed each command its argument text as `Text_At (Buffer, Arguments)`, in 44 branches of its
case statement, each a copy on the secondary stack with its own mark and release. A block around the case statement
now takes the text once into a constant, empty for an unknown command, and every branch passes that constant.

On the STM32F4 image the change removes 516 bytes of text, from 620900 to 620384. The command line vectors replay
unchanged.

## D495. Name and value lines put from their values (2026-10-28)

The environment and status listings passed 34 values to `Put_Name_Value` as texts from `Decimal`, `Text_Of` and
`Signed_Text`, each a copy on the secondary stack at the call. `Put_Name_Decimal`, `Put_Name_Text_Of` and
`Put_Name_Signed_Text` take the value itself and make that text once inside, out of line.

On the STM32F4 image the change removes 1024 bytes of text, from 620384 to 619360. The command line vectors replay
unchanged.

## D496. Fields and padded numbers put directly (2026-10-28)

The task list and the DShot telemetry listing each declared a local `Field` that right-justified `Decimal (V)`, and 29
calls put its result, each two copies on the secondary stack. The gyro register listing put `Zero_Padded` 13 times
the same way. `Put_Field` and `Put_Zero_Padded` now do it once out of line, and the local `Field` functions are gone.

On the STM32F4 image the change removes 1040 bytes of text, from 619360 to 618320. The command line vectors replay
unchanged.

## D497. Board identifier compared without the character maps (2026-10-28)

The board compared the stored board identifier with `Ada.Characters.Handling.To_Upper`, the image's only use of that
package. The package brings the runtime's character maps and sets, which the runtime builds at startup with 2136
bytes of elaboration code. The comparison now raises ASCII letters to upper case in its own loop. The board identifier
is ASCII, so every stored value compares the same: a Latin-1 letter that `To_Upper` would raise stays outside ASCII
and matches no character of the identifier either way.

On the STM32F4 image the change removes 2552 bytes of text, from 618320 to 615768, and 384 bytes of RAM. The host
smoke check's restarts keep their stored configuration through the new comparison.

## D498. Motor protocol reason follows the motor outputs (2026-10-28)

The board's arming inputs reported the motor protocol as not enabled at every pass, a placeholder from when the arming
logic reached the board before the motor outputs did (D388). The reason kept arming off after the DShot outputs
arrived. The input now reports the protocol enabled when the board drives motor outputs, which it does for DShot150,
DShot300 and DShot600, so arming follows the reference's other reasons. The reference enables every protocol it
knows. A board set to PWM, OneShot, MultiShot, Brushed or ProShot1000 keeps the reason here and stays disarmed until
those outputs are ported.

## D499. MSP port allocation (2026-10-28)

`MSP_Allocation.Allocate` opens MSP the reference's way: the three MSP slots in order, each at its baud rate with the
automatic rate at 115200, then each port a feature that talks MSP implies, at 115200, unless MSP is open there
already. A port opens only when the board offers it and no function opened it earlier, and a soft serial port only up
to 19200 baud. Each opened port keeps the rate and options asked of its driver, bidirectional in half duplex and the
transmit check on a UART otherwise, and whether its functions share it with telemetry. `Default_Slots` is the fresh
configuration's claim: the board's first port, then the target's MSP UARTs, each once and at most three.

A new oracle run draws the slots, the implied features, the board's ports and the ports other functions hold, and
records the reference's allocation over stub port drivers with its reset claims. The vectors compare 1600 cases.

## D500. MSP UARTs named at reset (2026-10-28)

A reset names the board's first port, the USB one, then the board configuration's MSP UART, its other MSP UART and its
MSP display port UART in the MSP slots, through `Default_Slots` (D499). The board generator writes those three defines
into the board package with the reference's port names mapped to identifiers, and it takes NAME=VALUE arguments that
set a define over the file's. A CLRacing F4 names none, so its fresh configuration keeps the USB port alone in the
slots. The host target names UART1 as its MSP UART, so its fresh configuration names UART1 in the second slot, and the
host smoke checks that put another function on UART1 clear that slot first, as a user of the reference would.

## D501. MSP ports from the MSP slots on the board (2026-10-28)

The board served MSP on its USB port and UART1 at all times and stepped off UART1 while another function held it. It
now opens its MSP ports as the reference does, after the serial functions the reference opens first: the allocation of
D499 over the board's ports, with a port busy while one of those functions holds its UART. Each port runs at its rate,
half duplex when the MSP configuration asks for it. The rules that were UART1's follow each line's UART: a line pauses
while a function or a telemetry stream holds its UART, a device streaming MSP on it makes it a peripheral line, and a
telemetry stream that lets go of it opens it again for MSP. The MSP display port draws on whichever board UART it
names.

A CLRacing F4 serves MSP on its USB port alone until a slot names a UART, as the reference does. The host smoke check
moves MSP from UART1 to UART4 through the slots and draws the display port on UART4 through its implied port.

## D502. Sea level altitude on the OSD (2026-10-28)

The altitude element's sea level variants drew zero on the board, which never set the renderer's sea level altitude.
The board now passes the GPS solution's altitude, which is what the reference draws there, bounded to the renderer's
altitude range. A new host smoke check draws the variant at the simulated GPS module's 545.4 m.

## D503. Build features (2026-10-28)

A 512 KB board has room for fewer features than the CLRacing F4S image contains, so a build now selects its features.
`tools/featuregen.py` writes `Adaflight.Build_Features` before each build of both targets, one Boolean constant per
selectable feature, on when the board MCU's flash size reaches the feature's size. At 1024 KB and up every feature is
on, and the CLRacing F4S image keeps its 617388 bytes of code. At 512 KB the gimbal control, the rangefinders, the
iBus, LTM and MAVLink telemetry and the Jeti EX Bus and SUMD receivers are off. The reference's local builds leave the
same features out at that size, and the gimbal control at every size. The menu system is on at every size, as the
reference builds it with every OSD, and it is selectable on its own, since it is the largest feature a 512 KB board can
drop and keep its OSD. `FEATURES` adds or removes features by name over those defaults, and `FLASH_KB` replaces the
MCU's flash size.

The flight file tests a feature's constant where it calls into the feature's package, and the radio tests a
receiver's constant in its protocol cases, so the compiler drops those statements and the linker drops the code only
they reached. The rangefinder's task steps are generic actuals of the task functions, so its package tests the
constant at its own entry points. The scheduler takes its menu, rangefinder and gimbal task options from the constants.

Code size of the CLRacing F4S image in bytes: every feature 617388, without the menu system 563072, the 512 KB set
590064, the 512 KB set without the menu system 535608. The target workflow builds the 512 KB set after the image, so
the left-out paths keep compiling. The host smoke reads the feature package beside the image and skips the checks of
features the build leaves out, so `FLASH_KB=512 bash host.do` checks the rest of the 512 KB set. A build without a feature still contains its settings, serial functions and MSP
commands, and the build information still lists no options. A list has to name every option the image supports,
since a configurator hides the tabs of options a nonempty list leaves out.

## D504. Board crate checks under 1024 KB (2026-10-28)

The board crate keeps its run-time checks in the CLRacing F4S image, and a board with less than 1024 KB of flash now
builds it without them, for the room the image needs there. The feature generator (D503) treats the checks as one more
entry, `Board_Checks`, on at 1024 KB and up, and writes `gen/adaflight-checks.adc` beside the feature package:
`pragma Suppress (All_Checks)` when the entry is off, a comment otherwise. The board's project file names it as the
local configuration pragmas of the board crate, so the core keeps the release profile it already builds with, and the
host image keeps its checks. The board crate catches no exception, so no path depends on a check firing. On the
CLRacing F4S image the 512 KB set's code drops from 590064 to 571860 bytes, and without the menu system from 535608 to
518096, 520944 with its initialized data. A 512 KB board has 480 KB after its vector and configuration sectors, and
about 507 KB when the image also fills the vector sector past the vector table, as the reference's F722 layout does.

## D505. Serial passthrough command (2026-10-28)

The command line gains serialpassthrough, one of the two commands the reference's F405 build contains and the port
lacked. The timer command, the other, waits for the timer tables. The passthrough reads up to seven words: the first
port by a word holding esc_sensor, by cli, by a port name or by a number, its baud rate as atoi reads it on a 32-bit
target, its mode with options and the DTR action, then the second port with its baud rate and mode, the command line's
own port when there is none. Each port is checked against the board's ports, then opened at its baud rate, 57600 when
none is given, or taken as it is open with a new baud rate or mode and its receive callback removed. The USB port's
line coding then sets the first port's baud rate when the command gave none, its DTR resets the board or switches a
PINIO, an ESC sensor passthrough disables the motors and holds their outputs idle, and the forwarding starts.

The board's ports come through new generic formals and the environment gains the command line's own port. The board
fills the formals with steps that do nothing for now, so it answers that the first port could not be opened. The
forwarding follows in a board change. A new oracle family, cliserpass, records the replies and the port calls over
scripted port states through wrapped port functions. The oracle runs on a 64-bit host, where strtol and atoi past the
32-bit range differ from the board's, so its words stay inside that range.

## D506. USB control line state (2026-10-28)

The USB port keeps the control line state the host last set, DTR in its lowest bit, with the count of the requests
that set it, so the serial passthrough can act on each one. The reference hands the state to a callback when its port
control receives the set control line state request with a two-byte value: the request's own value without a data
stage, the two data bytes with a data stage to the device, and the command buffer's first two bytes with one to the
host. The port takes the same value at the same three places.

The USB oracle sets a recording callback at each event, since the VCP's start clears it, and each line now ends with
the last state and the count. A new set of sessions sends the request with a two-byte data stage and reads it back,
and the earlier sessions' lines are unchanged before the two new fields.

## D507. Passthrough escape (2026-10-28)

The serial passthrough's forwarding ends with a reset when the host sends three plus signs, the first after a second
without a host byte, unless the host is on the USB port, which resets through DTR instead (D506).
`Adaflight.Passthrough_Escape` keeps the count and the time of the last host byte, the gap taken with the clock's
wrap. It is SPARK as a state machine whose reset the forwarding acts on.

A new oracle runs the reference's forwarding loop over a silent device port and a host port with drawn bytes and
times, leaves it by longjmp at the reset or when the bytes run out, and records the byte that reset. All 4000 cases
match, 959 of them with a reset.

## D508. Board serial passthrough (2026-10-28)

The board fills the passthrough's port formals (D505). A port's state comes from the UART driver, which now keeps each
port's settings at its last start, with the receiver's and the ESC sensor's ports counted as ports whose bytes a
function takes as they arrive. The USB port is always open. A port opens with its options as UART settings: inversion,
two stop bits, even parity and a half duplex line, push-pull when asked. A mode change or a callback removal leaves
the port as it is, since the board's UARTs run both ways and the forwarding is the only reader once it starts.

The forwarding moves each port's bytes to the other, runs the host's bytes through the escape (D507), follows the
host's line coding when the command gave no baud rate, and acts on each control line request (D506): a reset when DTR
is down, or the PINIO set at DTR's opposite. An ESC sensor passthrough drives the motor pins high as plain outputs. A
pass that moves no byte waits 100 microseconds, which the 256-byte receive rings cover at any baud rate, so the host
image's listener tasks get the locks the loop takes. gpspassthrough forwards between the GPS port and the command
line's port through the same loop, where the board answered that the forwarding failed. The image grows from 619244 to
622752 bytes of code.

The host image counts each connect and disconnect of its USB port's TCP client as a control line request, with DTR set
while a client is connected. The host smoke checks the forwarding both ways between UART4 and the USB port, and the
reset when the client disconnects from a passthrough started with a reset on DTR.

## D509. Board servo outputs (2026-10-28)

The board drives the servos. The servo mixer (D478) runs in the PID loop pass after the mix when the mixer drives
servos, with its settings from the configuration and the build's features, the receiver's channel count and the PID
loop's period. Its inputs come from the arming, the passthrough flight mode, the servo and camera stabilization boxes,
the RC commands, the PID sums, the attitude, the first motor through its DShot conversion and the receiver's channels.
Its writes go to the servo outputs in their order. On each pass the mixer reads the servo parameters, the tricopter's
unarmed servo, the first channel forwarded, the lowpass cutoff, the mixed tilt and the receiver's middle and aux
channel count from the live configuration, so the configurator's servo changes take effect at once. An MSP servo rule
write loads the custom rules as the mixer's rules in any mode. The MSP servo reply and the flight log take the mixer's
servo values, and the flight log's servo condition follows the mixer's own use of servos, which servo tilt and channel
forwarding also turn on.

The timer table, the register layout and the clocks move from the motor driver to `Adaflight.STM32.Timers`, which also
keeps an owner for each entry of the board's timer pin map. A pin takes the timer channel that its first map entry's
option counts among the pin's entries in the timer table, and a channel another output holds is refused. The motors
claim their channels first, then each servo with a pin in servo order, and the first servo refused ends the setup. A
servo's timer counts at 1 MHz over the period of the servo rate, its channel starts in PWM mode 1 with its preload and
a cleared compare register, and a write rounds the pulse to the nearest microsecond with ties to even.

The host image claims the same channels and logs each servo's setup and each change of its pulse. The host smoke sets
up a flying wing with two servo pins: the outputs start at 50 Hz, the flaperons rest at their middle, passthrough roll
moves them apart in the MSP reply and on the outputs, a configurator servo write lowers a flaperon's limit at once,
and a servo on the motor's pin is refused with the rest of the setup. The image grows from 622752 to 627612 bytes of
code, most of it the servo mixer, which the board did not link before.

## D510. Board analog motor outputs (2026-10-28)

The board drives PWM, OneShot125, OneShot42, MultiShot and brushed motors from the timers. `Adaflight.PWM_Output`
gains their timing: the configured update rate with continuous updates, which PWM and brushed motors always take, or
else the protocol's rate with a margin of four pulses, 1000, 2977 or 10000 Hz, then the smallest prescaler that keeps
the period within 16 bits, the counting rate and the period, and the scale and offset that turn a motor value into a
pulse. A write rounds the pulse to the nearest count with ties to even, and the servos take the same rounding with
their 1 MHz period. A division by zero, which needs a zero rate that the configuration's limits never let in, gives
zero as the processor's divider does. The unit is SPARK for its bounded float arithmetic and its narrowing
conversions.

A new oracle family runs the reference's STM32 PWM output file over a recording timer library: drawn motor and servo
setups at the board's clocks and at clocks around each prescaler step, then drawn writes. All 77092 lines match. A
one-shot rate off by one and a servo period off by one count each fail hundreds of lines.

On the board the motors claim their channels through the pin map owners (D509) in output order, and a motor without a
channel leaves none driven. Each channel starts as a PWM output at the motor's timing and idle pulse, inverted when
the configuration asks, and the servos now take the same channel setup. A motor update writes each pulse, and without
continuous updates each timer's first motor forces an overflow that starts the pulses before every compare register
clears. Disabling the motors clears the pulses. The MSP motor reply truncates an analog motor value as the reference's
conversion does.

Before a reboot from the command line, MSP, the menus or MAVLink the motors now shut down: the pulses clear, the
writes stop, and the board waits 1.5 ms, half a second more for PWM, OneShot and MultiShot so their ESCs disarm. A
reboot from the menus first writes the disarm output to every motor and waits 50 ms.

The host image claims the same channels and logs each analog motor's setup and pulse changes. The host smoke sets
OneShot125 and PWM: the motors start at their timers' rates, idle at the minimum command's pulse, report microseconds
over MSP and follow a motor test. The image grows from 627612 to 628808 bytes of code.

## D511. Board LED strip (2026-10-28)

The board drives a WS2811 LED strip. The strip's pin takes its timer channel through the pin map owners (D509) after
the motors and servos, and its stream from the map's DMA option, refused when a motor's stream holds it. The board's
strip pin is a new hardware default, which the board generator reads from the board's configuration. The timer's
prescaler aims at 48 MHz rounded to the nearest, which gives 42 MHz on the F405's timers, and the period is the 800
kHz carrier's in those counts, with a one at two thirds of it and a zero at one third. The stream writes one compare
value per bit from a buffer of 32 bits for each of the 32 LEDs and a 42-slot low tail that latches the colors. Each
LED's color is packed for the strip's format, GRB, RGB or GRBW with the white channel at the smallest of the three,
most significant bit first. `Adaflight.WS2811` contains the timing and the packing, and is SPARK for its 16-bit
narrowing.

A new oracle family runs the reference's STM32 strip buffer over drawn colors, formats and LEDs, with the F4 timer
helpers drawn over clocks around each rounding step. All 39716 lines match.

The LED strip task runs at 60 Hz when the LED strip feature is on. Each call that finds the last transfer done takes
the strip's settings from the configuration, runs the strip's update (D70) and sends the colors when they changed. A
command or an MSP write that changes the LEDs evaluates the layout again. The stream's end of transfer is read from
its enable bit, where the reference takes it from the transfer complete interrupt.

The host image claims the same channel and logs each change of a LED's color. The host smoke turns the feature on with
a red and a white LED and checks the strip's colors and the board's strip pin. The image grows from 628808 to 635608
bytes of code, most of it the LED strip unit, which the board did not link before.

## D512. Board identifier terminator (2026-10-28)

The board keeps a stored configuration only when the stored identifier matches the board's over the name and the zero
after it, ASCII letters compared in upper case. A stored identifier with a character after the name, such as F4051,
now resets the configuration. The board compared the name alone before and kept it.

## D513. Build options list (2026-10-29)

`Adaflight.Build_Options` contains the option numbers a configurator reads from the build information reply and the
options command (D307): the receivers, the telemetry, the features and the motor protocols, in the reference's order.
`In_Order` lists the numbers of a selection with its length, at most the option count, which the proof bounds against
the room of 64 the replies keep. The board selects the options its image drives: the CRSF, FPORT, Ghost, iBus, SBUS,
Spektrum and XBUS receivers, the FrSky hub and SmartPort telemetry, the altitude and position holds, the chirp, the
GPS, the LED strip, the OSD chip and the display port, PINIO, the servos, the video transmitter, and the brushed, DShot,
MultiShot, OneShot and PWM protocols, with the Jeti EX Bus and SUMD receivers, the iBus, LTM and MAVLink telemetry and
the rangefinders as the build's features (D503) select them. The command line and the build information reply read
the one list, which was empty before, so a configurator that gates its tabs, the compass section of its GPS tab and
its motor protocol choices on a nonempty list keeps those the image contains and hides the rest.

The list leaves out what the image cannot drive: a compass, the acro trainer, the battery continue feature, the
dashboard, the ESC serial bootloaders, the flight plan, the optical flow sensor, the HoTT, SRXL and Spektrum
telemetry, the SRXL2, SUMH, PPM and MAVLink receivers, soft serial, a camera control, the FrSky OSD, the race pro
features and the wing feature set, each until a board drives it.

The checker derives the command line oracle's list from the table and the oracle build's selection, and every number
and its position replays against the recorded options lines. The host smoke reads the options command and the build
information reply for the numbers the image's features imply.

## D514. Initialization order (2026-10-29)

The board's start follows the reference's three phases step for step, with the differences below kept. First the
persistent words and a pending bootloader request, the clock, the LED, the inverters, then the configuration with its
structure check and the board identifier (D512), PINIO, and now the Spektrum satellite bind at power-up, before any
delay, since the satellite's bind window closes 140 ms after power. Then the USB port, the ports, the beeper, the
inverters off, the ADC, the buses with the flash chip and the SD card, the gyro with its selection and the fix of its
configuration, the filters, the accelerometer, the attitude and the gyro calibration start, the rangefinder, the
internal ADC, the boot flashes with the beeper, the receiver with the failsafe before it, the GPS, the custom text, the
ESC sensor, the USB detect, the gimbal and the camera, the pilot with the arming reasons, the boxes, the control with
the motors, the servos, the LED strip, the battery, the OSD, the scheduler, the flight log, the MSP lines, the position
estimator, the holds, the navigator, the rescue, the telemetry, and the motors enabled last.

Kept differences: the LED and the inverter pins come from the board, where the reference reads a status LED
configuration; the USB port starts before the ports, where the reference starts it after its second phase; the flash
chip and the SD card start before the gyro, where the reference starts them after the sensors; the gyro calibration is
started with the filters, where the reference starts it after the flight log, which changes nothing since the
calibration counts samples the gyro task takes once the scheduler runs; the OSD starts before the MSP lines, where the
reference starts it after; the unused pins are left as the reset leaves them, where the reference sets them on its
PICO and ESP32 platforms alone.

`Adaflight.Spektrum_Bind` contains the bind's decisions, SPARK for their place in the start: a start binds when its
bind plug, where the board has one, reads low, the start is not a software reset and the bind count is one to ten;
the pulses go out on the override pin when one is set, else on the receiver port's line, the transmit pin on a
half-duplex line, or for the SRXL receiver only when the telemetry is on and does not share the port, and the receive
pin otherwise; the count returns to zero, to be saved, when no bind plug exists, the autoreset setting is on and the
start is not a software reset. The board reads the plug through a pull-up after 10 us, holds the line high for the 60
ms window, sends the count's pulses of 120 us low and 120 us high with the LED off and on, holds the override pin 50
ms more and leaves it floating, and writes the configuration with a confirmation beep when the count returned to
zero. The software reset is the reset register's flag, kept at the persistent words' start. The board drives no SRXL
telemetry, so an SRXL receiver's line is left alone, as the reference leaves it when the telemetry shares the port.

A new oracle family runs the reference's bind over drawn plugs, resets, counts, pins, ports and providers, with the
bind and SRXL telemetry defines restored after the platform drops them, as every STM32 build keeps them. All 8000 lines match. The host smoke sets a bind count
with the autoreset, saves, and reads the count back as zero after the restart. The image grows from 635760 to
636776 bytes of code.

## D515. Boards of the configuration repository (2026-10-29)

The board crate builds for any F405 board of the pinned configuration repository, not the CLRacing F4S family
alone. The board generator writes every UART's and SPI bus's pins, a placeholder where the board lacks the port, with
a presence constant for each, and the UART driver covers the six ports of the F405 with their bases, bus clocks,
alternate functions, clock bits and interrupts. A port the board lacks does not start, and the modules that look
for a port by its identifier loop over the ports the board has, so a configuration that names an absent port finds
none. The command line's port list, the MSP port list and the serial lines follow the board's set, the inverters start
from the board's tags in one place, and the buses start where the board has them. The target workflow builds the
Lumenier LUX F4 and the Omnibus F4 images beside the CLRacing F4S one. The CLRacing F4S image grows from 636776 to
638960 bytes of code for the two added ports, the LUX F4 image is 639052 and the Omnibus F4 image 639036.

## D516. STM32F7 crate (2026-10-29)

`targets/stm32f7` builds the flight software for the F7 boards of the configuration repository, the Kakute F7 first.
The crate reuses the F4 crate's sources with its own main, and generates three things before each build: its run-time
library, its board package and its memory layout. The run-time library comes from the toolchain's STM32F746 Discovery
runtime, copied beside the crate with its board parameters set to the board's crystal, a system clock of 216 MHz, the
flash latency of that speed and the PLL divisor that gives the USB its 48 MHz, then built with the runtime's own
script; a copy whose stamp names the same source and parameters is kept. The memory layout follows the MCU: the vector
table alone in flash sector 0, sector 1 for the configuration store, the code from sector 2, the main RAM at its F7
address and the data tightly coupled memory in the place of the F4's core coupled memory. The board generator now
writes the pins the crate reads by name with a placeholder where a board lacks them, as it does for the ports.

This slice builds the image; the F7's UART, SPI, flash and USB register sets differ from the F4's, so the drivers of
those come next, with the caches the F7 start enables. The target workflow builds the Kakute F7 image after the F4
boards. The Kakute F7 image is 634140 bytes of code with 3836 of initialized data.

## D517. STM32F7 drivers (2026-10-29)

The F7 crate gets the drivers whose register sets differ from the F4's, each an F7 body the crate's project names in
place of the F4 one: the UART with its control registers first, its status in ISR with a clear register and its data
split into RDR and TDR, the overrun flag cleared through the clear register before the bytes are read; the SPI with
its frame size and receive threshold set to eight bits and its data register accessed as one byte, since a word write
would send two; the flash with the ART accelerator's cache reset after programming in place of the data cache's; and
the USB device with the VBUS detection left off and the B session forced valid, since the boards do not sense VBUS.

The clocks and the DMA buffers' section come from a platform package each crate provides: the F4's 168 MHz with its
buses at 42 and 84 MHz and its timers at twice that, the F7's 216 MHz with 54 and 108 MHz, as the generated run-time
library divides them. The DMA buffers of the motors and the LED strip go to the platform's section: the main RAM on
the F4, whose core coupled memory the DMA cannot reach, and the data tightly coupled memory on the F7, which the DMA
reaches and the data cache the F7 start enables does not cover. The configuration sector, the bootloader and the
unique identifier addresses come from the memory package the layout generator writes beside the memory layout, so
the flash and MCU bodies serve both families. The Kakute F7 image is 634172 bytes of code; the F4 images are
unchanged at 638960.

## D518. Gyro bus from the board (2026-10-29)

The gyro's SPI bus comes from the board's configuration, SPI1 when it names none, and the SPI driver covers the six
buses of the F4 and F7 families with their bases, clock bits and alternate functions, the two on the slower bus
halving their divisor as before. The board generator writes the six buses' pins with their presence and the gyro's
bus number beside the OSD chip's, the SD card's and the flash chip's, the devices accept a bus up to the sixth, and
the flight starts every bus the board has. The Kakute F7's gyro is on SPI4.

## D519. Board barometer (2026-10-29)

The board detects its barometer on the bus the configuration names and reads it in the 40 Hz cycle of the barometer
task (D124). The I2C buses the board has start with the SPI ones, as masters at 400 kHz; the F7's I2C body drives the
newer peripheral through its timing register, a register read as a write of the register with the transfer kept open
and a read of the bytes ended automatically, a register write as one two-byte transfer, and a missing acknowledge or a
wait past 25 ms failing the transfer and restarting the peripheral. The F4 crate drives no I2C bus yet, so a device on
one is not found there. `Adaflight.I2C_Timing` contains the timing register's computation from the bus clock, the
speed and the filter length, the reference's single precision arithmetic with a prescaler search, SPARK for its
bounded loops; a new oracle family draws clocks, speeds and filters, leaving out the cases whose data hold delay the
reference computes below zero, and all 6824 lines match.

The barometer's bus comes from the board's configuration through the hardware defaults: SPI when the board names one,
else I2C when it names one, with the bus's device, the chip select or the address, and the conversion end and reset
pins, else no bus with the hardware set to none, the stored configuration's values standing for a build without a
board. The board's barometer unit serves the drivers' bus device over the I2C and SPI buses, a started read or write
running at once so the bus never reports busy, scans the drivers the board names, the BMP280 alone so far, and runs
the task's step with the elapsed time of each device call. The altitude feeds the position estimator, the flight log,
the telemetry, which gains the Ghost link's barometer frame, and the replies, the status names the barometer on its
bus, and the power-on calibration starts with the flight log. The host image models a BMP280 on its first I2C bus
answering the datasheet's worked example, which the smoke reads through the status, the sensor flags and the altitude
reply. The Kakute F7 image grows from 634216 to 637284 bytes of code for the I2C driver and the barometer, the
CLRacing F4S image from 638992 to 639512 for the hardware defaults, its barometer code dropped by its constants.

## D520. Configuration group set of a board build (2026-10-29)

The configuration's group set, the groups' fields, the settings table and the defaults now match a board build of the
reference with the port's feature set. We took the reference's own compile lines for the CLRacing F4 from a dry run of
its make, compiled the parameter group sources with the GNAT ARM compiler at the debug level, read every group's type
from the debug information, and compared them with the host settings oracle's. The oracle lacked three groups, the
camera control, the ESC serial pin and the timer pin map, the ADC group's DMA options, seven settings (the camera
control's six and the SD card's SPI bus), and the aux channel count default, 14 on a board with an FPU where the host
build read 6. Every other difference is the compiler's: the ARM compiler stores an enumeration in one byte and a
character unsigned, the host in four bytes and signed. The port's records had the board's widths already but for one
enumeration (D521), since the generator sized an enumeration by its values and a character as a byte, and the settings
oracle now compiles the groups with the board compiler's two conventions, so its layouts equal a board build's byte for
byte and the port's codec, stored image (D158) and vectors did not change.

The host oracle's generic F405 target now defines the STM32 platform's timer management and DMA specification, the
SD card's SPI bus, the CLRacing F4's timer pin map, camera control pin and ADC DMA option with its pins as raw tags,
and the FPU flags the aux channel default reads; the ESC serial group comes through a shim, since its driver does not
build on the host, and the settings table compiles with the same defines as the groups. A script rebuilds the oracle
and its dump files (the settings, the defaults, the group variables in registry order, the lookup table names and the
layout), the three generators write the port's groups, codec and settings table, and a second script reruns the
recipes of the families that hash the configuration, replaying the recorded inputs where a recipe no longer draws
them. The codec grows from 4591 to 4677 bytes; stored images keep loading, since the store keys groups by number.

The board's hardware defaults gained the timer pin map, the camera control pin, the ADC devices' DMA options and the
ESC serial pin, which the board generator reads from the configuration repository and the flight writes into the
stored defaults, so a Kakute F7 stores its own map. The resource table gained the ESCSERIAL and CAMERA_CONTROL owners
in the reference's order, and the build option list names camera control, as the reference does when the board has
the pin. The timer and dma commands and the dump's timer and dma sections wait for the next increment: the command
line oracle compiles with those conditionals turned off while the groups stay registered. The Kakute F7 image builds at
638272 bytes of code and the CLRacing F4S one at 640496; the host smoke (400 checks), style and the vectors pass.

## D521. Timer and dma commands (2026-10-29)

The command line contains the timer command, the dma command's full form, and the dump's timer and dma sections after
the resources. `Adaflight.Timer_Tables` contains the STM32F405's data for them, generated from the reference's tables:
the full timer table of 70 channels in its order, which a pin's occurrence numbers count along, each timer channel's DMA
stream options and each peripheral's, and the fourteen timers in their listing order. The oracle gets the same tables as
a host shim from the same generator, with the timers and the DMA streams as stand-in addresses.

The timer command without arguments lists the map's entries, each with its channel's detail; a word starting list is not
implemented and one starting show lists the timers with the channels the board's map entries hold, whose owners and
ordinals the environment reports; else a pin on the board takes its own map entry or the first free slot, and prints its
line alone, its channel options for list, or sets its channel by alternate function with af, or none, the entry's DMA
option cleared, with the change noted. The dma command with a word starting show lists the streams as before; alone it
lists the options set, list is not implemented, and a device by name and ordinal, or a pin on the board, prints its
option alone, its stream options for list, or sets an option by number or none with the change noted, an option the
device or the pin's channel lacks refused. The devices are the SPI buses' output and input under two names each, the
ADCs and the UARTs' transmit and receive sides, in the reference's order, with no SDIO device (F305). A pin without a
map entry lists no option and every option is refused for it (F306). The dump's timer section prints each map entry
against the default entry of its pin and the default entries the map dropped; the dma section prints every device's
option against its default, then each map entry's, equal only with the same channel or no option, then the default
entries with an option whose slot has no pin. The board's timer map entries report their owners through the environment,
the motors, servos and LED strip with their ordinals; the host checker holds every timer free.

The command line oracle builds with timer management and the DMA specification on, the reference's timer helpers, the
generated tables, F305 to F309 fixed, and timer owners free. The timer family holds 1200 commands: the listings, pins on
and off the board, channel options, alternate functions present, absent and malformed, devices and ordinals inside and
past their counts, stream options present and absent, none, and dumps, diffs and the active resources between them. The
command line families were regenerated through the new oracle, the recorded ones by replay. The Kakute F7 image builds
at 649800 bytes of code and the CLRacing F4S one at 652528; the host smoke (402 checks, the dma show, dma and timer
listings among them), style and the vectors pass.

The regenerated families' configuration hashes exposed the one record field wider than the board's: the dashboard's I2C
device, an enumeration with a negative member, which the group generator typed in four bytes by its values while the
board compiler stores it in one. The generator now sizes an enumeration by the layout's width and signedness, the field
is a signed byte, the codec's image holds 4674 bytes, three fewer (D158), and the configuration and command line
families were regenerated with the one-byte layout's hashes. The command line oracle prints its configuration image on a
probe line, which located the field.

Three more reference behaviours stay out as divergences, found by the regenerated families: the dma option number and
the passthrough port number read as signed bytes, so 256 passed as option 0 and 2147483647 failed its parse as port -1
(F307, F308), and the OSD group reset that writes the live warnings when the serial command or the setting information
reply resets a copy for a default comparison (F309). The port checks both numbers at their full width and its printing
changes nothing. The oracle fixes the three.

## D522. Timer allocation from the configured map (2026-10-29)

The timer drivers allocate their channels from the configuration's timer pin map, so the timer and dma commands take
effect at the next boot. `Adaflight.Timer_Allocation` holds the reference's timer management as a SPARK package over the
map and an owner per entry: an entry's channel is its pin's tag at the entry's occurrence in the timer table (D521),
none for an empty entry or an occurrence past the pin's channels; a pin's first entry answers for the pin; a channel's
owner comes from the first entry whose channel it is; an allocation takes the pin's first entry when its channel is
free, and the entry holds the owner and its ordinal from then on, even when the entry has no channel, in which case the
owner gets no channel back. The entry's DMA option is the motor's or the LED strip's. The STM32 timer driver loads the
map at boot after the configuration, allocates through the package with the resource owners, and reports the owners to
the command line, which the resource and timer listings print. The crate's own copy of the timer table went away with
the static board map lookups; the board map only seeds the configuration's defaults (D520).

The timer allocation oracle builds the reference's timer management as source over the settings oracle's F405 target and
the timer shim of D521, draws the board's default map with random entries rewritten, then a run of allocations by owner
and ordinal and queries of a pin's configured channel and its owner, and prints the owners after the run. The timer
allocation family holds four seeds of 200 cases. The Kakute F7 image builds at 648964 bytes of code and the CLRacing F4S
one at 651692, both below D521 with the crate table gone; the host smoke, style and the vectors pass.

## D523. DShot telemetry capture decode (2026-10-29)

`Adaflight.DShot.Decode_Edges` decodes a motor's telemetry reply as the reference's timer DShot driver reads it from the
edge times its timer captured at sixteen counts per bit, the first edge falling. Each gap rounds to a run of bits, a one
then zeros, the gap taken as the reference's signed difference of the counts. The last run is padded to twenty-one bits
when the line ends high, since the return to idle closes a reply that ends low. A run past the word, a gap below half a
bit or a word short of twenty-one bits gives the invalid value, else the word goes through the group decode of D58, the
GCR table, the nibble checksum and the value above it. This is the first of the bidirectional DShot increments: the
timer driver's input capture, the DMA direction switch after each frame, the deadtime and the telemetry state follow.

The capture decode oracle takes the decode out of the reference's driver source at build time, since the rest of that
file needs the processor's registers, and draws replies of random values through the GCR codes with the closing edge,
jittered within and past half a bit, with a missing or a spurious edge, with a wrong checksum, and random edges within a
frame's span. The capture family holds four seeds of 500 cases. The decode has no caller on the boards yet, so the
Kakute F7 image stays at 648964 bytes of code and the CLRacing F4S one at 651692. The host smoke, style and the vectors
pass.

The reference's timer driver decodes a five-bit code outside the GCR alphabet as a zero nibble and keeps the word when
its checksum holds, where its bitbang driver rejects it. In the oracle's 2000 draws the timer driver's table kept 12
damaged or random words as values. The port takes the bitbang decoder's table and check, a divergence (F310), and the
oracle fixes the extracted decode the same way.

## D524. DShot telemetry read after a frame (2026-10-29)

`Adaflight.DShot.Read_Replies` is the reference timer DShot driver's read of the motors' replies after a frame, the step
the motor update runs before it writes the next values. Without telemetry it does nothing. Else each motor in order
stops the read when the time since the channels switched to input, taken as the reference's signed difference of the
microsecond counts, is under the motor's deadtime, so the motors before it have already been read. A motor in input with
more than seven captured edges counts a read and decodes them (D523). A valid value is kept as the motor's raw value,
unless it is the extended telemetry acknowledgement while the motor's current command enables extended telemetry, which
marks the state events kind received. An invalid reply counts as such and the first motor's edges are saved for the
command line. Every reply counts in the motor's quality (D58). Each motor read leaves input. After the last motor the
raw values wait for processing, the switch time clears, and the driver enables the channels again.

The core takes the captures as values: whether the channel is in input, its deadtime, the edge count and the edge times,
which the driver reads from the DMA stream's counter and buffer before the call, since the reply is complete once the
deadtime has passed. The read reports how many motors left input, in order from the first, so the driver switches those
back to output. The read has no caller on the boards yet. The driver's input capture follows.

The telemetry read oracle takes the read and the quality update out of the reference's sources at build time over the
capture decode of D523, with the DMA counters, the direction switch and the clocks as stubs. Each of 30 cases per seed
resets the state and runs 25 steps of drawn captures: replies of random values and of the acknowledgement, damaged
sometimes, few or random edges, inputs on and off, deadtimes of the three DShot rates that differ between motors at
times, switch times before, at and after the deadtime, and wrapping clocks. The family holds four seeds. The Kakute F7
image stays at 648964 bytes of code and the CLRacing F4S one at 651692, as in D523. The host smoke, style and the
vectors pass.

## D525. DShot telemetry on the motor path (2026-10-29)

The motor update reads the last frame's replies before it writes the next values, as the reference's motor write does
for its timer DShot driver: the read of D524 over each motor's capture, the motors' current commands from the command
queue and the clocks, with the motors it reports switched back to output. The blocking command writes read the same way
between their frames. The filter task decodes the raw values into the motors' kinds, rates and filtered frequencies
(D58) before the gyro filtering, as the reference's filter task does, and dshot_telemetry_info reports the reads, the
invalid replies, each motor's values and the saved edges. The telemetry's rates and filters start with the motors when
DShot telemetry or the ESC sensor runs.

The boards' timer driver captures no replies yet, so their frames stay plain DShot whatever the telemetry setting, and
the telemetry stays off until the input capture with its direction switch follows. Betaflight's automatic DShot driver
setting picks its bitbang driver on the F7 and, with bidirectional DShot, on the F4, where the port runs the timer
driver. The host's motors answer each frame with a reply at sixteen counts a bit, zero eRPM at the stop and thirty eRPM
for each throttle step above the first, so the host smoke reads the telemetry of a motor test: the spinning motor's eRPM
and RPM, the stopped motors at zero, and no invalid reply. The RPM filter, the dynamic idle, the arming check and the
flight log's RPM fields take the telemetry in the next increment. The Kakute F7 image builds at 649476 bytes of code and
the CLRacing F4S one at 651484. The host smoke, style and the vectors pass.

## D526. DShot telemetry for the RPM filter, the dynamic idle and arming (2026-10-29)

The motors' DShot telemetry feeds the flight path's consumers of the reference. The RPM filter takes the motors'
filtered frequencies each filter task, the dynamic idle the slowest motor's frequency and the RPM limiter the average
RPM each mixer pass, arming waits while bidirectional DShot runs and a motor does not report, an arming clears the
replies and the read counts when the ESC sensor is off, and the flight log's header and RPM fields take the driver's
telemetry flag and each motor's eRPM. The reference sets that flag at the start of its DShot device setup, ahead of the
gyro filters and the PID setup that read it, so the port takes it from the configuration before its loop units start:
the configured telemetry with a DShot protocol on an output that captures the replies, which the boards' timer driver
does not yet do (D525). The host smoke checks that arming does not wait for the telemetry when every motor reports. The
Kakute F7 image builds at 649956 bytes of code and the CLRacing F4S one at 651964. The host smoke, style and the vectors
pass.

## D527. DShot telemetry in the OSD and MSP replies (2026-10-29)

The motors' DShot telemetry reaches the reporting consumers. The OSD's ESC RPM and frequency elements, its average RPM
statistic, its highest ESC temperature from each motor's hottest reply, its ESC temperature alarm and element, and the
element list take the telemetry while bidirectional DShot runs. The ESC warning reads each reporting motor's eRPM,
current and temperature, the last two only with the extended kinds, while the setting asks for DShot telemetry. The eRPM
factor of the OSD's rates comes from the pole count when the ESC sensor or the telemetry setting is on. The MSP motor
telemetry reply gives each motor's RPM, invalid share and extended values, and the ESC sensor data reply the temperature
and RPM without the ESC sensor. The SRXL telemetry and the debug modes have no board path yet, so their telemetry inputs
wait for them. The host smoke reads both MSP replies during a motor test. The Kakute F7 image builds at 650468 bytes of
code and the CLRacing F4S one at 652988. The host smoke, style and the vectors pass.

## D528. Motor timer owners by pin (2026-10-29)

A motor's timer channel takes the number of the motor pin it drives as its owner's ordinal, so the timer listing shows
the same owner on a pin whatever the output order. The motor setups gave the mixer's motor number until now (D521),
which differed from the reference once the order changed. The host smoke swaps the first two outputs and checks the
listing. The Kakute F7 image builds at 650468 bytes of code and the CLRacing F4S one at 652988, as in D527. The host
smoke, style and the vectors pass.

## D529. DShot input capture on timers (2026-10-29)

STM32 timer DShot captures each motor's telemetry reply. With bidirectional DShot and a DShot protocol, frames go out
inverted with an inverted checksum, each pin keeps its configured inversion's pull, and each compare register starts at
its top so lines idle high. A motor's stream raises its transfer complete interrupt, whose handler stops stream and
timer request, waits for the stream to stop, clears its flags and turns it to peripheral-to-memory without interrupt.
The handler then notes when a first motor switched, sets its timer counting to top and its channel to input capture at
both edges with a two-sample filter, and restarts its stream for 22 edges with request on. A read before motor writes
(D524, D525) takes each motor's edges from its stream's remaining count and buffer, stops each input motor's request,
resets its stream to memory-to-peripheral with interrupt, and sets its channel back to PWM. Once every motor is read,
switch time clears and channel outputs go on, and next transfers reload periods. Deadtime is 35 microseconds plus
sixteen bits at protocol bit clock. Handlers cover every stream a motor's timer channel can use on F405, on both DMA
controllers, at lowest interrupt priority like other handlers.

Capture runs only on hardware. Host motors model replies (D525), and vectors check read and decode (D523, D524), so this
driver waits for a bench check on Kakute F7 and CLRacing F4S. Kakute F7 image builds at 654748 bytes of code and
CLRacing F4S image at 657268. Host smoke, style and vectors pass.

## D530. Bit-band sample decode on F4 (2026-10-30)

Reference F4 builds decode a bit-banged port's reply samples through the processor's bit-band alias, one word per sample
bit, with an edge search alternating between rising and falling edges. F7 builds compare each sample with its last level
(D58). Adaflight keeps one sample decode for both. A bit-band decode oracle runs reference F4 decode on a 32-bit host,
since board pointers wrap, over an emulated alias region with draws of the sample decode family, and adaflight's decode
gives its results, preamble skips, margins and check times on all of them. Its unrolled reads past an edge in reach
change no result, since an edge counts only with a sample after it within reach.

## D531. Bit-banged DShot port buffers (2026-10-30)

`Adaflight.DShot_Bitbang` builds a GPIO port's output buffer for reference bit-banged DShot: three words per bit, which
a timer-paced DMA stream writes into its port's bit set and reset register, and three hold words after each frame. Each
motor pin adds its set word at every bit start and its reset word at every bit end, inverted output swapping halves,
with middles and last two hold words cleared. Each update clears middles, then every motor frame sets its pin's middle
at each zero bit, so a pin falls a third of its way into a zero and two thirds into a one. SPARK proves buffer indices.
An output oracle extracts all three builders from driver source at build time and draws port pins and inversion with
three updates of frames. Its family holds four seeds of 200 cases.

## D532. Bit-banged DShot reply read (2026-10-30)

`Adaflight.DShot_Bitbang.Read_Replies` reads motor replies after a bit-banged frame. Each motor in order whose port
finished sampling decodes its pin from port samples through sample decode (D58), one decoder memory serving every motor.
A reply found counts a read and keeps its value, or marks extended telemetry acknowledged when its value is an
acknowledgement and its motor's command enables it, or counts an invalid reply. Each found reply counts in motor
quality, and a pin without a reply counts nothing. Raw values then wait for processing, and used ports' abort marks
clear. A read takes one clock reading for every motor decode, where reference reads its clock at each decode, so
half-second margin checks can move by microseconds between two decodes. SPARK proves indices, decoded value range and
cleared marks. A read oracle extracts reference read from driver source at build time over sample decode and quality
count, and draws ports, pins, aborted waits, short sample counts and commands with steps of replies, invalid and garbage
samples and steady lines. Its family holds two seeds of 20 cases of 10 steps, and ten mutations of the read each fail
it.

## D533. Bit-banged DShot setup (2026-10-30)

`Adaflight.DShot_Bitbang.Configure` sets up bit-banged DShot. At motor start each motor in order takes the pin of its
place in output order, and a pin without a timer map channel, or one already held, stops the start with a pin conflict.
Motor output flags are a channel's complementary flag with inversion and telemetry applied. After other owners take
their timers and streams, each of four port group slots takes the first pacer channel its timer setting allows, from
TIM8 channels 1 to 4 then TIM1 channel 1 twice, 2, 3 and 4, whose timer no map owner holds, whose channel no earlier
slot has, and whose DMA stream is free. Each motor in order then joins its port's group or starts a new one. A fifth
group stops setup with too many ports, a slot without a pacer stops it without a pacer, and a pacer stream another group
took stops it with status unchanged. A started group owns its stream, sets output and input periods, reply timeout and
frame time from timer clock, and adds its channel's DMA request to its pacer timer. `Active` gives driver choice:
setting on, or automatic with a protocol other than ProShot, F4 needing telemetry too. SPARK proves indices and that
pacer timers never outnumber groups.

Reference pacer search reads the timer of an earlier slot that found no pacer, a null pointer (F311). An STM32 reads its
boot alias there and matches no timer, and adaflight leaves such a slot out of its check, matching an STM32.

A setup oracle extracts reference start, post start, pacer search, port groups and timebase from its source at build
time over F405 timer and DMA tables, with stand-ins for DMA stream and pin owners. It draws maps with owners, streams
and pins already taken, motor pins and order, and settings. Its family holds four seeds of 250 cases, and twenty
mutations of setup each fail it.

## D534. Blocking DShot commands on bit-banged DShot (2026-10-30)

A blocking DShot command, as command line and MSP send them, writes frames through driver update hooks. With bit-banged
DShot each repeat clears port buffers before writes, waits for replies before completion, and decodes replies after
completion, where timer DShot decodes before writes. `Adaflight.DShot_Command.Blocking_Run` takes driver choice and both
hooks. Command oracle runs a second time with bit-banged DShot active over its bench sequences, and adaflight's steps
match it.

## D535. Bit-banged DShot driver on STM32 (2026-10-30)

STM32 crate runs bit-banged DShot when configuration chooses it (D533): setting on, or automatic with a DShot protocol,
F4 needing bidirectional DShot. At motor start, setup checks pins, and each pin becomes a push-pull output pulled toward
its idle level. After LED strip takes its stream, setup finds pacers and groups, and each running group gets its TIM8 or
TIM1 channel at output period with a compare at ten counts, plus its DMA2 stream. A motor update clears group frames,
sets each motor frame (D531), waits for replies to end or time out, turns any group still in input back to output, and
starts every stream and pacer request. Each stream writes its group's 51 set and reset words into its port, one per
pacer period. With bidirectional DShot a stream's transfer complete turns group pins to inputs and samples port input
register 140 times at input period, and each update reads replies from those samples (D532) after its transfers start. A
transfer error leaves its stream for next update to reload. Transfer complete interrupts of DMA2 streams 1, 2, 3, 4, 6
and 7 serve timer DShot captures or groups, whichever runs. Blocking commands follow D534, and arming check takes driver
choice and setup status.

Adaflight reads replies only for motors setup gave a group, where reference reads every motor and goes through a null
group for a motor its setup stopped before (F312). Adaflight keeps no pin owners at motor start, so a motor pin another
device holds does not stop start with a pin conflict. F7 keeps frames and samples in data tightly coupled memory outside
data cache, where reference cleans and invalidates cache lines.

This driver runs only on hardware and waits for a bench check on Kakute F7 and CLRacing F4S. Host keeps its timer DShot
model. Command line timer and dma listings do not show bit-banged owners yet.

## D536. Bit-banged owners in timer and DMA listings (2026-10-30)

`dma show` names each stream's owner among drivers adaflight runs on DMA: a motor by its number, LED strip, or a
bit-banged group by its port's number, else FREE. `timer show` names for each channel its first map entry that holds it,
with owner and ordinal, else a bit-banged group the channel paces, by port number. Flight code fills owners after
bit-banged post start, once servos and LED strip hold their timers. It took timer owners right after motors before, so
listings left out servos and strip, and a free map entry ahead of a held one on one channel hid the held one. Setup
oracle prints reference listings for each case over map owners, LED strip streams and setup groups, and adaflight's
listings match them. Reference `dma show` also names ADC, SPI and UART streams, which adaflight does not run on DMA.

## D537. ADC on DMA (2026-10-30)

Analog inputs come from a continuous scan. After motor start, a configured converter scans battery, current, external
and RSSI inputs in that order, each one on with a pin its converter reaches, at 480 cycles each, and a circular DMA
stream writes every result into its input's slot. Its stream comes from its converter's DMA option, unless a timer DShot
motor took it. Without a stream its converter stays stopped and every input reads zero. A read takes its slot's last
result, where adaflight converted each input on request before at about 48 microseconds a read. LED strip refuses an ADC
stream as it refuses motor streams, bit-banged pacer search counts it busy, and `dma show` lists it as ADC with its
converter number. Setup oracle draws ADCs with their numbers among stream owners, and adaflight's listings match its
listings. ADC1 still converts internal reference and temperature channels on request, between scan conversions. Scan
runs only on hardware and waits for a bench check on Kakute F7 and CLRacing F4S.

## D538. F7 code in flash sector 0 (2026-10-30)

F7 images place code in flash sector 0 beside their vector table. Its linker script holds a second code section in
sector 0, and `--enable-non-contiguous-regions` lets each function that does not fit there go to its code region from
sector 2. Read-only data stays in that region, since merged string sections cannot move between regions. Both crates
now link their link-time optimized code in one section per function and per object, so placement works function by
function and `--gc-sections` drops functions no caller reaches: F4 image 1044 bytes smaller, F7 512 KB set 1656. Kakute
F7 holds 29768 bytes of code in its 32 KB sector 0, 32192 in its 512 KB set. An F722's 16 KB sector 0 takes about 15.8
KB, room Betaflight's F722 layout leaves empty. Flashing writes sector 0's file with vector table and code last, so its
bootloader leaves through that vector table. An image too big for its regions now fails with ld's relaxation message
about a merged string section in place of an overflow count. F4 images keep their vector table alone in sector 0, since
1 MB has room. Speed is unchanged: both sectors are one flash behind one cache.

## D539. Menus off under 1024 KB (2026-10-30)

Menu system is now on from 1024 KB, so 512 KB builds leave it out by default and keep their OSD. After size work
(D480 to D497, D503, D504, D538) an F722's 512 KB set stays about 100 KB over its room, and its menu system is the
largest feature an OSD board can drop. F7 512 KB set loses 54208 bytes of code (610536 to 556328), F4's 54768 (612180
to 557412). `FEATURES=+Menus` keeps menus in a 512 KB build. Boards with 1 MB or more keep every feature, so their
images do not change. Build options leave out CMS when menus are off (D513), and host smoke skips menu checks.

## D540. LED strip off under 1024 KB (2026-10-30)

LED strip is now a build feature on from 1024 KB, so 512 KB builds leave it out by default, as Betaflight's builds
under 1 MB do. Its task, start and build option test its constant, so strip code drops out of those images, while its
settings, MSP messages and command line parts stay. F7 512 KB set loses 5960 bytes of code (556328 to 550368), F4's
5480 (557412 to 551932). `FEATURES=+LED_Strip` keeps it, and host smoke skips its checks when a build leaves it out.

## D541. SD card logging off under 1024 KB (2026-10-30)

SD card logging is now a build feature on from 1024 KB, so 512 KB builds leave it out by default, as Betaflight's
builds under 1 MB do. A Talon F7 has no SD slot and keeps its flight log on its flash chip. SD card's start, poll and
log writes test its constant, so card protocol and FAT file system drop out of those images, while settings, MSP
messages and command line parts stay and SD card status reads as no card. F7 512 KB set loses 13564 bytes of code
(550368 to 536804), F4's 13528 (551932 to 538404), and a CLRACINGF7 image now runs 33788 bytes over its 491520 of
room. `FEATURES=+SD_Card` keeps it, and host smoke skips its checks when a build leaves it out.

## D542. Simulator FDM packets (2026-10-30)

`Adaflight.Sim_FDM` contains a first part of a simulator link for host target: decode of a 144-byte flight dynamics
packet, eighteen little-endian doubles, and state update Betaflight's SITL runs for each one. A packet more than 500 ms
of host time after its predecessor restarts timing and asks for a motor update, and one with an older timestamp is
stale. Any other gives accelerometer and gyro counts at 256 per g and 16.4 per degree per second, pressure, attitude
quaternion, a synthetic magnetometer from a fixed earth field and a virtual GPS solution, then a sim rate from
simulation and monotonic time while packets arrive faster than 50 Hz. Gazebo's bridge keeps its yaw rate sign, derives
pressure from altitude, takes back its conjugated attitude and mirrors GPS position around its first position. Older
bridges send pressure and attitude as they are. Scale constants round as a C compiler rounds them, and `pow`, `atan2`
and `sqrt` come from C library, so results match bit for bit. Where C conversions are undefined, adaflight drops a
packet with a NaN, infinite or larger than 1e6 field, or an attitude component past 2, and saturates pressure,
coordinates, speeds and velocities (F313). Simfdm oracle extracts SITL's update from Betaflight's platform source,
builds it once per bridge with its virtual GPS conversion included, and replays 48 sequences of 160 packets over
scripted clocks. Host UDP link, sensor feeds and motor packets come next.

## D543. Simulator attitude (2026-10-30)

`Adaflight.Attitude` gains simulator target's attitude, second part of a simulator link for host target.
`Set_From_Simulator` takes a packet's quaternion as it is, computes its rotation, negates west and up rows' body X
entries for older bridges, whose pitch and yaw are mirrored, then marks attitude established and updates its angles.
`Update_Simulated` runs in place of an estimate: it holds GPS heading usable, since a simulator's attitude is ground
truth, and corrects throttle angle as an estimated attitude would. Where a quaternion is longer than unit length,
pitch's cosine is clamped to [-1, 1] as for an estimated attitude, while Betaflight takes `acos_approx` of a value past
one, NaN through `lrintf` (F314). `Sim_FDM`'s attitude bound tightens from 2 to 1.4, so Gazebo's turned attitude stays
within attitude's component bound of 2. Imusim oracle builds Betaflight's IMU for its simulator target once per bridge,
with that clamp behind a toggle, and replays 40 sequences of 160 quaternions near unit length or up to 1.98 a component,
with arming, angle and headfree mode changes.

## D544. LZSS decode (2026-10-31)

`Adaflight.LZSS` decodes LZSS with no entropy stage, first part of packed data for 512 KB builds: a 32-bit big-endian
length, then tokens read most significant bit first, each a flag bit and either an 8-bit literal or a 12-bit distance
less one and a 4-bit count less three copied from output already written, so its window is 4096 bytes and its matches 3
to 18 bytes. A stream that ends early, a header of another length, a copy from before output's start and a copy past its
end each report their own status, with output written so far kept and rest zero. Its proof covers every read and copy
index. `tools/lzss.py` encodes streams, taking longest match among last 64 positions with same three bytes ahead, and
writes its vectors: 240 drawn inputs of random bytes, words, sparse data, records, runs and copies across a full window,
plus 60 malformed streams, each hex string in chunks the checker can hold. On a 512 KB F7 image this format takes cold
tables from 38144 bytes to 19612. Betaflight's builds hold no compressed data, so this unit has no reference and its
vectors come from its own encoder.

## D545. Packed data in 512 KB STM32F7 builds (2026-10-31)

A 512 KB STM32F7 build keeps cold tables and initialized data compressed in flash and unpacks them into RAM at start,
second part of packed data. Its linker script places tables that command line, MSP, a configuration reset or a log start
read, and that compress below 80 percent, in RAM by their input sections, with initialized data after them, both loading
from a staging region that is never flashed. After its link, `tools/datapack.py` compresses that range with
`tools/lzss.py`, checks that it decodes back and that it fits between `__rom_end` and flash's end, and writes
`sector0.bin` and `code.bin` with the stream at `__rom_end`. `Adaflight.STM32.Data_Pack` decodes it with
`Adaflight.LZSS` from an `.init_array` entry, which the run-time library calls once clocks run and before elaboration,
and stops there on a bad stream. Ada constants and their proofs are unchanged, and the flight loop reads no packed
table. A 512 KB set built for KAKUTEF7 moves 38148 bytes of tables and 4388 of data into a 20115-byte stream, and a
CLRACINGF7 image now runs 11875 bytes over its room, from 33788, with RAM use 38148 bytes higher. Larger builds keep
plain tables, with 20 bytes of unpacker beside them. `featuregen.py` chooses packing below 1024 KB and lists the tables,
and a packed build reports its flash left or its overflow in place of ld's message. The target workflow builds a packed
KAKUTEF7 image. Boot runs only on hardware, so a first F722 flash checks unpacking.

## D546. F722 device identifier address (2026-10-31)

`tools/memorygen.py` gave STM32F722 images the unique device identifier address of STM32F745 and F746, 0x1FF0F420, where
an F722 maps nothing. Flight's elaboration reads that identifier for board identity, so a Talon F7 BB took a precise bus
fault before `main`, and the run-time library's fault handler is an endless loop with every interrupt masked: its status
LED stayed dark after unpacking, delays and tasks never ran, and its USB core, powered before the fault, attached to the
host without answering. F722 identifiers now read from 0x1FF07A10, as RM0431 gives them. Found on the bench with a trace
written to flash by a fault hook in the run-time library's copy, after Renode runs on an F746 model, which returns zero
for that address, showed nothing. D538's claim that an F722 image fits sector 0 stands; this image now boots there.

## D547. Core coupled memory zeroed at start (2026-10-31)

`Adaflight.STM32.CCM_Clear` zeroes the core coupled memory's `.bss.ccm` section before elaboration, from an
`.init_array` entry that runs first. The run-time library's start clears main RAM's `.bss` alone, so objects placed in
core coupled memory by section name, the USB controller's protected object and the menu's state, started with whatever
that memory held since power-up. Both board images carry the unit, and the host image leaves it out, having no such
section.

## D548. ADC calibration word addresses (2026-10-31)

`Adaflight.STM32.ADC` read its reference voltage and temperature sensor calibration words at the STM32F405 addresses
0x1FFF7A2A to 0x1FFF7A2E on every crate. No F7 maps them, so an F7 image took a precise bus fault at its first read of
them, after the barometer's start. `tools/memorygen.py` now emits `Calibration_Address` in `Adaflight.STM32.Memory` per
MCU, 0x1FFF7A2A on F405, 0x1FF07A2A on F722 and 0x1FF0F44A on F745 and F746, as their datasheets give them, and the ADC
unit places its three words there.

## D549. USB device attachment (2026-10-31)

The STM32F7 OTG core resets with its soft disconnect bit set (`DCTL.SDIS`), and `Init` never cleared it, so an F7
image's device stayed off the bus however complete its setup: a register snapshot in the bench trace showed `DCTL` at
its reset value of 2 after `Init`. The F405 core resets with the bit clear, which is how F4 images attached without the
step. `Init` now clears the bit after the global interrupt enable, on both crates; on an F405 the write changes nothing.

## D550. USB handler stack (2026-10-31)

`Handler`, `Out_Endpoints`, `In_Endpoints` and `Bus_Reset` each declared a `U.Actions` record of near 1 KB as a local,
and they nest two deep at an endpoint event, on a 2 KB interrupt stack. Overflow ran into the idle task's stack below,
and the first USB suspend interrupt left a zero frame there: a usage fault for an invalid state on return, with every
later interrupt masked, so a board attached and fell silent. The record is now one component of the `Controller`
protected object, which runs its operations one at a time, so its handlers share it. The F4 body had the same locals.

## D551. STM32F7 instruction cache (2026-10-31)

The F7 run-time library leaves both Cortex-M7 caches off: its `setup_pll` writes F4 flash accelerator bits (ART enable
sits in their place on an F7 and serves ITCM fetches alone) and nothing writes `CCR`. Code at 0x08000000 runs over AXI
at seven wait states, uncached: on a Talon F7 BB, PID took 525 us per pass with its loop at 700 to 960 Hz against a
125 us period. `Adaflight.STM32.Cache` invalidates and enables the instruction cache from an `.init_array` entry before
elaboration, so unpacking and elaboration run cached too. The data cache stays off until DMA buffers move to DTCM,
which no cache covers. The F4 run-time library enables its flash accelerator already.

## D552. Uptime in the command line path (2026-10-31)

`Status.Uptime_Ms` was set in `Process_Command` alone, so `status` on a port that had seen no MSP request printed
"System Uptime: 0 seconds" at any uptime. `Refresh_Views` sets it now from the millisecond clock it reads for every
pass, before MSP or command line replies read it.

## D553. Board identifier per MCU (2026-10-31)

The configuration's board identifier was the constant "F405" on every crate, so an F722 image printed "(F405)" in its
version line and accepted a configuration stored by an F405 board. `tools/memorygen.py` now emits `Board_Identifier`
beside its memory layout, "F405", "F722", "F745" or "F746", and `Flight` stores and checks that. A configuration stored
under "F405" on an F7 board resets to defaults at its next start, and `Reset_Configuration` writes the board's
identifier into a fresh configuration, since the core default stays "F405" for the host.

## D554. Device counts and store sizes in status (2026-10-31)

`status` and the board information reply gave zero SPI and I2C devices and a configuration of 0 bytes in 0 bytes of
storage: `Flight` never filled those fields. `Count_Bus_Devices` counts gyro, barometer on its bus, flash chip, OSD
chip and a configured card slot once devices have started. Storage size comes from `Adaflight.STM32.Memory.Config_Size`
and configuration size from `Check_Structure`, after loading at boot and after every write.

## D555. STM32F7 data cache (2026-10-31)

`Adaflight.STM32.Cache.Enable` invalidates and enables data cache beside instruction cache. DMA buffers (motor frames,
bit-bang frames and samples, ADC results, LED strip) already sit in `Platform.DMA_Section`, which the F7 crate maps to
`.bss.ccm` in DTCM, memory no cache covers, so DMA and core see one copy. Flash programming writes through (default
attributes make code memory write-through), and a configuration store erase changes memory behind cached lines, so the
F7 flash body drops lines of its configuration region after erase and after programming, before reading back.

## D556. Gyro receive buffer offset (2026-10-31)

Board gyro glue `Fetch` copied received bytes from index 0, command byte first, while `Adaflight.MPU_Gyro` reads each
axis word from byte 2 on, as its reference lays out a receive buffer (one unused byte, one clocked with the command,
then data). Every axis word so held one axis's low byte and the next axis's high byte: a Talon F7 BB at rest read
0x0700 0x0300 0x0500 for gyro counts 7, 3 and 5, and calibration restarted without end on that apparent noise. `Fetch`
now puts the command's byte at 1 and data from 2, on both crates. Vectors exercise the layer with the reference layout
and the host image has its own gyro model, so only a bench run could show this.

## D557. Barrier before system reset (2026-10-31)

`MCU.Reset` wrote its reset request straight after other register writes, such as the backup register word that asks
for the ROM bootloader, and a Cortex-M7 may still have such a posted write crossing an APB bridge when the core resets.
`Reset` now issues a data synchronization barrier before and after the request, so pending writes complete first.

## D558. Bootloader request before plain reboot (2026-10-31)

The serial pass applied a session's effects in one place: a plain reboot first, then a ROM bootloader request. A `bl`
followed by `exit` in one batch set both, so `Reset` ran before `Reset_To_Bootloader` wrote its backup word, and the
board came back as the application. The bootloader request now comes first and the plain reboot only without one; the
reference resets inside its `bl` handler, so a later `exit` never reaches it.

## D559. Simulator link of the host image (2026-10-31)

`Adaflight.Host_Simulator` opens its link when `ADAFLIGHT_SIMULATOR` names a bridge, `gazebo` or `legacy`, with a
simulator address after a comma: a UDP server on port 9003 for flight dynamics packets and senders to ports 9002 and
9001 for motor packets. `Flight.Pass` polls it first through `MCU.Simulator_Poll`, so each packet that arrived goes
through `Sim_FDM.Decode` and `Step` in the main loop with no thread: a timeout sends a motor packet, an update stores
virtual gyro and accelerometer counts and an attitude quaternion. The host gyro body reads those counts in place of its
resting craft, with the 2000 dps scale and the accelerometer's 256 counts per g raised to its 2048, and `Run_Attitude`
sets the attitude from each fresh quaternion and runs `Update_Simulated`. Board images answer `Simulated` with False.
The host smoke drives it with a fake simulator. Motor speeds in the packets, RC over UDP and time scaling follow.

## D560. Virtual GPS and barometer for the simulator (2026-10-31)

`GPS_Link` gains a virtual provider: a simulator's solution offered through `Offer_Virtual` is taken at its next 100 ms
step as long as offers keep arriving within 2.5 s, with twelve satellites and fixed accuracies, and the generic state
machine times it out like a receiver gone dark. Board GPS runs its link without a port for MSP and virtual providers
and feeds the virtual one from `MCU.Simulator_GPS`. Board barometer takes a virtual device when the image is simulated:
no bus scan, calibrated at once at ground zero so its altitude is absolute, pressure from `MCU.Simulator_Pressure` on
every combined read with a 10 ms delay and 25 degrees. The oracle's link generator gains a virtual case with a feed
gap, replayed through new offer columns of the checker. Host smoke checks a virtual fix at a fed position and, with
`altitude_source` BARO_ONLY, an estimate at a fed 1600 m that follows a twenty metre climb. No magnetometer pipeline
exists yet, so the feed's field vector waits.

## D561. Barometer task chain (2026-10-31)

No barometer ever ran on any image: `Run_Body` had no arm for its task, which fell into a null default, and neither
`Task_Init` nor `Task_Functions` inputs carried `Baro_Detected`, so enable and guard stayed false. A host simulator
probe showed it: virtual device detected, pressure fed, no sample. `Run_Body` now runs `Tasks.Baro`, both inputs carry
detection, and position inputs carry sample time and interval for the estimator's gate, which had let one reading
through and then none. The smoke's GPS climb check had passed only because no barometer ran: that phase now sets
`altitude_source` to GPS_ONLY, and the simulator phase checks the barometer alone.

## D562. UDP receiver provider (2026-10-31)

A simulator sends its sticks as one UDP packet: a timestamp and sixteen channel pulses. `UDP_Receiver` keeps each
packet's channels, those a shorter packet leaves out staying as they were, and reports one complete frame per packet
with its channel count. `Receiver` takes that count on a complete frame as its channel count, bounded by configured
aux channels, and starts at zero channels until a packet arrives; `Source_Of` picks this provider ahead of every other
when its feature is on. On a host, the simulator link opens port 9004 for these packets and offers them through
`MCU.Simulator_RC`, which no board answers. The feature is available on the host image alone, where
`MCU.UDP_Receiver_Available` holds as the reference's simulator build defines it: there a configured UDP receiver counts
as the receiver feature, survives the fix-up's clearing of unsupported features, and clears the others when none of
them is set (each of them clears it first), and the command line offers it; a board ignores a stored UDP bit as the
reference's board builds do. Oracle receiver sequences 46 to 55 feed the reference's own UDP store with drawn
counts.

## D563. Motor packets to the simulator (2026-10-31)

Simulated host motors hand each pulse to the simulator link instead of a timer: a speed packet carries four motors
as (pulse - idle) / 1000, or / 500 with the 3D feature, and a raw packet carries a motor count with each pulse as
written. One pair goes out per flight dynamics packet received, when its motor write completes, and a link timeout
sends its latest pair. Pulses exist only on analog protocols, so a simulated image runs `motor_pwm_protocol = PWM`,
the one protocol the reference's simulator build has.

## D564. Simulator time scaling (2026-10-31)

`Host_Clock` accumulates real time times its link's rate, which `Sim_FDM.Rate_Of` finds per packet as in the reference;
`Millis`, `Micros` and cycle counts follow it, and a delay sleeps its real share. A protected object holds base and
rate and rebases on a rate change, since several host tasks read the clock. Link packet timing stays real, as in the
reference. Smoke feeds timestamps at 1.5 times real time and reads uptime twice.

## D565. Board compass (2026-10-31)

No image ran a compass: core compass state, its detection scan and nine drivers existed, a scheduler slot and a task
hook sat at no step, and every flight unit reported no magnetometer. `STM32.Compass` now scans its configured bus
through core detection, initializes whichever chip answers (HMC5883 over I2C or SPI, QMC5883L and P, IST8310, LIS3MDL,
LIS2MDL, AK8975, AK9916, MMC560X, BMM350; AK8963 behind an MPU slave bus waits), builds compass settings with that
chip's output rate, and runs its read cycle from its task with attitude gyro rates. Its field feeds attitude estimation
and MSP IMU values, its presence sensor flags, status and task enables, and a calibration starts from a stick command
or an MSP command, beeps at its start, at first movement, on success and on failure, and saves its zero. Board
configurations gain compass bus, select, interrupt and alignment defaults from board defines. A simulated image takes
a virtual compass whose field comes from packet attitude.
