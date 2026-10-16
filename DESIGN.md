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
- The battery's charge integration for the analog and virtual meters multiplies the latest
  current by the microseconds since the meter was last serviced in 64 bits, where the
  reference's 32-bit product wraps on the first sample after a pack is detected, which spans
  the time since boot, and on every sample of a virtual estimate above 1073 A (findings
  F20). The recorded vectors keep that first sample and the virtual meter's scale small
  enough for the reference to stay in range, so the two agree on every step.
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
- The up and down reference prints U or D for the zenith or nadir. The reference formats
  the symbol string's pointer with a character conversion and prints the low byte of its
  address (finding F110).
- A mission item's altitude converts to centimeters toward zero and saturates at the 32-bit
  range, where the reference's conversion and its sum with the home altitude are undefined
  beyond it. The recorded items stay within the range.
- The flight plan executor holds a leg's target and its carrot within 262 kilometres of the
  origin in each axis, the navigation's bound, so a waypoint further out is flown toward the
  held point. It holds the carrot's velocity within 1000 metres per second in each axis and
  its speed at 1000, a unit direction within 2 in each component, the filtered along-track
  distance within 10,000 kilometres, the time a heading fault has lasted at a million seconds,
  and the hold pattern's phase within 10 radians, which a pattern started at its quarter radian
  a second never reaches, where the reference's floats run on. The geofence return's and the
  rescue's altitudes saturate at the 32-bit range. The recorded plans stay within 200 kilometres
  of the origin and replay bit for bit.
- MSP simplified tuning requests with a field outside its setting's range are errors that write
  and change nothing (D153), where the reference stores and computes with any byte. The in
  message checks the whole request before it stores anything, so a short request, which the
  reference stores as zero filter cutoffs, is an error (findings F142). The checker expects the
  error and unchanged settings for the recorded requests outside the ranges.
- The configuration storage image reads bytes past its region as erased and does not write an
  image longer than the region (D158), where the reference leaves both to the target and reads
  past a corrupted region's end. Its reported size is the image's length, 2 bytes less than the
  reference reports on 32-bit targets (findings F143). The recorded images never read past the
  region, and the checker takes the reference's extra bytes off its size.
- The command line's `aux` answers a negative condition index with the index range error, where
  the reference writes the condition's fields before the start of the conditions, and prints 0 for
  a mode or link outside the box table in its reply line, where the reference dereferences an
  empty box lookup (findings F155). The recorded command lines keep their indexes at zero or above.
- The configuration fix leaves a mixer mode past the mixer table and the rates of a rates type
  past the limit table as they are, and takes an MSP override condition's aux channel past 27 to
  name no bit, where the reference reads past its tables or shifts past the mask's width
  (findings F150 to F152). The recorded configurations stay within the tables and the mask.
- The command line's `map` query and the master dump print the map from a cleared buffer, so a
  position no mappable channel holds ends the map text, and `map` skips a stored position past the
  eight, where the reference prints what its stack buffer held and writes past the buffer (findings
  F156). `rxfail` prints no mode letter for a stored mode past the three letters, where the
  reference prints its letter string's terminator or the bytes after it. The recorded command lines
  map only the eight mappable channels.
- The command line's `adjrange` answers a negative range index with the index range error, where
  the reference writes the range's fields before the start of the adjustment ranges (findings
  F157). The recorded command lines keep their indexes at zero or above.
- The command line's `serial` reads ports, baud rates and telemetry protocols through the serial
  map, where a stored value outside its setting's values reads as no port, the automatic rate or no
  protocol. A legacy line writes back only what changes in that reading, where the reference writes
  over the stored value. The recorded command lines keep every setting within its values.
- The command line's `mixer` and the master dump print no name for a mixer mode outside the names
  table, where the reference reads outside the table (findings F161).
- The command line's float reader takes a number past the float range as the largest float and
  zero with an exponent past the range as zero, where the reference reads infinity and
  not-a-number, and `mmix` prints every value in full, where the reference writes values of 100000
  or more past its text buffers (findings F159, F160). The recorded command lines keep their values
  below 100000.
- The command line's `smix load` of the last frame loads no servo rules, where the reference reads
  the frame's rules from past the end of its rule table (findings F47). The recorded command lines
  load the other frames.
- The command line's LED text prints in full, where the reference writes a text of 20 characters or
  more past its 20-byte buffer, and with no function letter for a stored function past the ten
  letters, where the reference reads past its letter table (findings F163). The recorded LED texts
  have 19 characters or fewer.
- The command line's `vtx` answers a negative condition index with the index range error, where the
  reference writes the condition before the start of the conditions (findings F165). The recorded
  command lines keep their indexes at zero or above.
- The command line's `vtxtable bands` and `vtxtable channels` without a number are the argument
  count error, where the reference reads a null pointer (findings F166). Band lines and table lists
  print every frequency and power value in full and read a factory flag without a store, where the
  reference writes past its text buffers from five digits and writes the flag's value before its
  frequency buffer (findings F167, F168), and a stored count past eight lists and clears eight. The
  recorded command lines give every count its number and keep values to four digits.
- The simplified tuning of a stored PIDs mode past RPY covers every axis, where the reference's axis
  loop runs to the mode's value and reads past its default gains (findings F177). The recorded
  configurations keep the mode within its names.
- A runtime record built from the stored configuration holds each field to its runtime range and
  each code to its names (D187), where the reference computes with the stored value. A stored value
  leaves its setting's range only through a foreign image, and the recorded configurations keep
  every value within it.
- The runtime receiver settings widen an equal channel range by one step and read a zero RSSI frame
  period as one (D187), where the reference scales by a zero span and divides a filter gain by zero.
  The recorded configurations keep their ranges apart and their periods above zero.
- The runtime mode conditions make a condition whose stored mode is outside the box table never
  active, and a link outside it no link (D187), where the reference dereferences an empty box lookup
  (findings F155). The recorded configurations keep their modes within the table.
- The runtime mixer configuration holds the motor output range to the motor values and at least one
  step wide, with the disarm output below its top, and reads a disabled protocol's range as zero to
  one (D187), where the reference computes with an inverted or empty range (findings F181). The
  recorded configurations keep their ranges within the motor values and in order.
- The runtime mixer configuration reads a mixer mode outside the table as quad X, a mix weight that
  is not a number as zero, and a custom mix without motors as one motor with a zero mix (D187), where
  the reference indexes past its mixer table, computes with the weight, and drives no motor. The
  recorded configurations keep their modes within the table, their weights numbers and their custom
  mixes with motors.

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
reference defaults; the simplified filter sliders are in D152, and the OSD profiles come with the
configuration phase. Two guards cover the reference's undefined behavior: a range whose function is
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

Amended 2026-10-13: the floor on a rescheduled period and the gyro loop's period are the
platform's, settings: 10 and 125 microseconds on the STM32 F4 and later, 100 and 1000 on AT32
and the older STM32, 1 and 100 on the simulator. The unit had held the floor at 100 for every
platform. With a floor of 1, a checked task's age, one plus its waiting time
over its period, can pass the 32-bit range, so the sum is taken in 64 bits and keeps the low 16
bits the reference stores. The recorded passes reschedule at 125 microseconds and up, so they
replay the same, and the checker gives the scheduler the oracle platform's floor of 1.
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
modes and the velocity buildup clamp are in D145; there is no optical flow. A feedforward term beyond the signal bound and a target velocity beyond 2 to the 26
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

## D100. The OSD statistics (2026-10-12)

The OSD stats unit contains the reference's flight statistics: the extremes tracked while
armed and the text of every statistic on the page after a flight. The reset at arming
sets each extreme at its far end, the link quality floor at 99 without a link quality
source and 100 with one. Each update takes the readings of the cycle through the
reference's sixteen-bit comparisons: the speed in three dimensions or over the ground,
the voltage of the pack or the average cell by the setting, the current, the signal
percent, the altitude, the acceleration, the link quality, the signal strength and the
noise ratio, the home distance under a fix and a home fix, the ESC temperature from the
sensor's combined reading when its feature is on and from the telemetry's per-motor
maxima otherwise with the motor that set it, and the average ESC rotation from the sensor
converted or the telemetry averaged. A reading past sixteen bits wraps as the reference
wraps it, so a home distance past 32767 metres records negative (finding F105).

The page's text for a statistic comes with its label beside the value, or the value alone
across the label's place for the clock, and reports when the statistic is not shown: the
speed, distance and flight distance only with the GPS feature, the current, charge and
energy only with a current meter, the flight log status only for a flash or card device,
the log number only when there is one, the acceleration only with an accelerometer, the
peak frequency only with the dynamic notch active. The timer statistics print the timer
without its symbol under its precision unless its source is the on time, and label it with
the source's name; the lap times print seconds and hundredths rounded or a blank; the
flight log status prints the storage used in percent from the card's blocks and free
space or the flash partition's sectors and offset, or a fault. The display, the readings
and the settings stay with the target, which places the label thirteen columns left of the
middle, the colon five right and the value seven right.

The harness replays six sequences of 1500 operations recorded from the reference: resets
with and without a link quality source, updates under random readings with the wrapping
ones among them, and each statistic's text under random settings, clocks, meters, devices
and totals, checked against the display writes the reference made with their columns and
rows. Every extreme, text and position of the 9006 lines replays byte for byte.

## D101. The OSD page and the arming screen (2026-10-12)

The OSD page unit contains the reference's statistics page, its arming and boot screens,
and the three steps the OSD runs around them each cycle. The page is laid out one row per
step from the statistics enabled, in the reference's display order, each row the label
thirteen columns left of the middle, a colon five right and the value seven right, or the
clock alone at the label's place; a counting pass finds the row count, then the page is
centred vertically with its heading when the rows fit, and the refresh walks its phases of
the first clear, the count, the clear between and the rows until the page is complete or
the rows run out. The arming screen clears the display, draws the logo when the setting
shows it always or until the first arming, writes the armed word in the middle and the
crash flip warning below it when that mode is on; the pause after it lasts the logo's
duration or half a second. The boot screen clears the display and draws the logo, the
version in capitals, the menu help and the clock when there is one, with a pause of four
seconds. The logo goes to the display as a whole when the display draws it itself, else as
the font's logo characters row by row.

The first step of a cycle sees the arming transitions: arming resets the statistics and
starts the pause with the arming screen; disarming enables the page when a statistic is
enabled, the page is not suppressed, no failsafe is active, and the disarm was not a
runaway or crash with the warnings visible, keeping the end voltage and resetting the row
count. While armed the extremes update and the flight and launch times grow by the cycle,
the launch time resetting while launch control is active; while disarmed with the page
enabled, a grabbed display drops the page, the switch hides it and shows it again, and a
shown page refreshes every second. The auxiliary value follows its channel every second.
The second step keeps the pause: while it lasts the cycle draws nothing, and a high
throttle or pitch stick or the crash flip switch while disarmed ends it early; once it has
passed the display clears and the page is dropped. The third step reads the acceleration
when the element shows it or its statistic is enabled. The display, the sticks, the
switches, the arming disable reasons and the readings stay with the target, which draws
the writes each step hands back; the counting pass sees the display's rows and columns.

The harness replays six sequences of 500 operations recorded from the reference: the
first step under random times, arming, failsafe, grabbing, switch, launch control and
readings; the refresh walked to completion under random settings, pages and extremes with
displays that draw the logo themselves and ones that do not; the second step under random
sticks, switch and pauses; the third step; the arming screen; and the boot screen with
the version and the clock. Every state field, extreme, write and position of the 11803
lines replays byte for byte.

## D102. OSD element set, alarms and active list (2026-10-12)

The OSD elements unit contains the reference's item set with its position fields, the blink
the alarms drive and the list of the active elements. The item set is the eighty-nine items
of a one-megabyte target without flight plan, map or pitot, in the reference's order, which
fixes each item's place in the position table and in the blink bits. A position field holds
the column in five bits with a sixth above the row for wide displays, the row in five bits,
the three profile bits and the variant in the top two; an item is visible when its profile
bits meet the active profile's bit, the first profile standing in for profile zero. The blink
has a bit per item and a state the half second cadence sets from the clock, on in the first
half; an item blinks while its bit is set in the on half, and a reset clears every bit.

The alarms set the bits each cycle: RSSI, RSSI dBm and link quality under their thresholds;
battery voltage and cell voltage while the battery state is not OK; satellites without a fix,
under four, or under the rescue's minimum when the rescue is configured; each timer whose
source has reached its alarm minutes, taken times sixty million in thirty-two bits, which
wraps past seventy-one minutes (F107); charge drawn and remaining time estimate at the
capacity alarm; battery usage at the capacity alarm, or on a low battery without one;
altitude at its alarm while armed; home distance at its alarm while armed with a home fix;
and ESC temperature at its alarm from the ESC sensor's combined reading, or from the first
motor whose DShot telemetry contains one. The capacity alarm is the battery profile's
capacity when it has one, else the setting. The altitude compared is the selected unit's
value over a hundred, truncated.

The active list is built from the positions and the active profile: horizon, g force and up
and down reference with an accelerometer, then the display order of seventy-three items,
then the eight GPS items with a GPS, the three ESC items with an ESC sensor or DShot
telemetry, the three lap times with a GPS, and the total flights. The up and down reference
and the total flights are listed twice when visible, and the list holds the ninety-one adds
of a list with every item visible (F106). Six items ask for the accelerometer when active.
Settings, sensors, clocks and readings stay with the target.

The harness replays six sequences of 400 operations recorded from the reference: the active
list under random positions, profiles, sensors and features; the alarms under random
thresholds, readings, clocks, battery profiles and motor telemetry, with the blink synced to
the clock and one item's blink read back; and the reset. Every count, listed item,
accelerometer need, blink word and state of the 2406 lines replays byte for byte.

## D103. OSD element renderers for readings (2026-10-12)

The OSD render unit contains the reference's element renderers that format readings,
thirty-eight of the seventy-six: altitude, pitch and roll angles, anti gravity, average
cell voltage, compass bar, core temperature, crosshairs, current, the two debug lines,
disarmed, g force, charge drawn, watt hours, battery usage, battery voltage, numerical
heading, vario, PID and rate profile, the three PID lines, power, remaining time estimate,
RSSI, RSSI dBm, RSNR, throttle, the two timers, auxiliary value, ready mode, position hold
ready, total flights, flip arrow, flight mode and clock. Each render starts from an empty
text, offsets at zero, normal severity, drawn and complete, and fills them as its element
does: the altitude in the unit when a barometer or a GPS fix supplies it, else the altitude
symbol and a hyphen, critical past the altitude alarm while armed; the angles with a sign
and two digits; the cell and pack voltages with the battery symbol, warning and critical by
the battery state, the pack voltage with one decimal from ten volts; the compass bar as nine
characters of the heading strip; charge, watt hours and remaining time critical past the
capacity alarm, the remaining time as the flight time scaled by the charge left over the
charge drawn, dashes below a tenth of the capacity and zero past it; the battery usage as a
percentage of the profile's capacity or of the voltage estimate, or as a bar of eleven cells
with a half cell; the RSSI capped at ninety-nine and critical under its alarm; the RSSI dBm
with the antenna once a second antenna has reported; the timers critical when either alarm
has passed; the flip arrow from the folded roll and the pitch while crash flip is on or the
craft lies disarmed off its feet; the flight mode in the reference's precedence from
failsafe to acro, with the chirp's axis, repeat and finish; the clock in the variant's form
when the clock is set. The remaining time's conversion to microseconds saturates at the
signed thirty-two-bit limit (F108). The PID line's feedforward widens to sixteen bits (D97).
Settings, sensors and readings stay with the target; the graphics, GPS, link, ESC and name
elements and the draw cycle come later.

The harness replays six sequences of 500 renders recorded from the reference, each element
under random settings, readings, attitude, battery profile, gains, clocks, switches, modes
and clock. Every text, offset, severity and flag of the 3006 lines replays byte for byte.

## D104. OSD element renderers for GPS, link, ESC and names (2026-10-12)

The OSD render unit grows by the reference's GPS, link, ESC, motor, log, name and text
renderers, twenty-nine items, and the craft and pilot name backgrounds: flight distance,
home direction and distance, the two coordinates, satellites, speed, efficiency, the three
lap times, link quality, uplink power, log status, ESC temperature, ESC rotation and
frequency, motor diagnostics, the rate, PID, OSD and battery profile names, the four custom
messages, the custom serial text, the adjustment range and the lidar distance. The GPS
elements print their values with a fix and a hyphen without one; the home direction points
to the lap timer's start while a lap runs and the home distance measures to it; the
coordinates set their blink while a fix once held is lost. The satellite count is critical
without a fix or under four and a warning under the rescue's minimum, with the dilution
appended on request; the efficiency filters the current over the speed at half a hertz and
prints up to four digits. The link quality prints by its source, with the mode before it
for Crossfire except in the second variant; the uplink power prints in milliwatts below a
watt. The ESC temperature prints the sensor's combined reading or each motor's telemetry
and stops at the text's thirty-one characters where the reference writes past its buffer
(F109); the ESC rotation elements walk the motors one row a render; the motor diagnostics
scale each output into a bar and mark a stopped motor. A name prints in capitals, or its
default with the profile's number when empty; a custom message prints as stored or its
number; the serial text prints up to thirty-one characters or dashes. Settings, sensors and
readings stay with the target; the graphics and the draw cycle come later.

The harness replays six sequences of 500 renders recorded from the reference, each element
under random fixes, positions, satellites, speeds, laps, links, logs, ESC telemetry, motor
outputs, names, messages and texts, with the efficiency filter carried between renders.
Every text, offset, severity, blink, flag and filter state of the 3006 lines replays byte
for byte.

## D105. OSD element renderers for graphics and the VTX channel (2026-10-12)

The OSD render unit grows by the reference's graphics renderers, the VTX channel and the
remaining backgrounds: artificial horizon, up and down reference, the left and right stick
overlays, RC channels, VTX channel, and the horizon sidebar, camera frame and stick overlay
backgrounds. The artificial horizon walks nine columns one a render, each bar character from
the roll and pitch held to their limits and scaled, drawn only when its row falls on the
ladder; the up and down reference marks the zenith or nadir from the attitude matrix's up
row within twenty-five degrees, its offsets scaled from the small angles; the stick overlay
places the cursor sprite from the radio mode's sticks and draws its cross one row a render;
the RC channels print one channel a render scaled to thousandths; the VTX channel prints the
band letter, channel name and power label from the table, the band and channel looked up
from the frequency when the band is zero, the power from the transmitter while it limits
power disarmed, dashes when locked, with the disable or pit mode mark. The horizon sidebars
write their decorations row by row and then the level marks; the camera frame writes its
top, its sides row by row and its bottom. A renderer's direct writes are one-character
string writes with the blink bit while the element blinks. The reference prints the up and
down reference's symbol as the low byte of its string's address (F110); adaflight prints the
letter, a deviation declared in D6. Settings, sensors, sticks, tables and readings stay with
the target; the draw cycle comes next.

The harness replays six sequences of 500 renders recorded from the reference, each element
under random attitude, limits, sticks, radio modes, channel settings, frame sizes, tables,
transmitter states and blink bits, with the rows walked between renders. Every text, offset,
severity, flag and direct write of the 3006 lines replays byte for byte, the up and down
reference's letters standing for the bytes the reference printed.

## D106. OSD warnings element (2026-10-12)

The OSD render unit contains the reference's warnings element: the warnings line from the
warnings unit (D95) with its severity, and the element's blink bit set while the line
blinks and cleared otherwise. With the craft name messages on, a link quality message
replaces the line while the blink is in its hidden half or the line is empty: the mode,
quality and RSSI dBm for Crossfire, the quality and RSSI dBm for Ghost, else the quality
scaled to one digit. The element then copies its first fifteen characters into the craft
name, zero filled after a shorter text; a text of fifteen characters or more leaves the
name's sixteenth byte as it was (F111). The craft name buffer, the blink and the readings
stay with the target.

The harness replays six sequences of 500 steps recorded from the reference, the warnings
scripted as for D95 with the craft name messages, link sources, qualities, modes, blink
halves and stored names added. Every text, blink bit, severity, beeper flag and craft name
byte of the 3006 lines replays byte for byte.

## D107. OSD draw cycle (2026-10-12)

The OSD draw unit contains the reference's element draw cycle. Each call takes the element on
turn from the active list. Where the display has no background layer and the element has a
background not yet drawn, the call draws the background; otherwise it draws the foreground and
moves to the next element once the renderer reports the element complete, returning false after
the last element and starting again at the first. A foreground draw is skipped for an element
without a foreground, and for an element whose blink is in its hidden half unless the display
blinks it itself. A system element goes to the display as a system write at its position, the
warnings element renders through the warnings unit with the craft name messages, and every other
element renders through the render unit with its variant, its blink bit taking the renderer's
change. A render stores its text in the element buffer when it writes one, and the buffer keeps
its old text otherwise, so renderer outputs gain a flag for whether they stored their text. The
pending write goes to the display at the element's position plus its offsets, with its severity
and the blink attribute while its blink bit is set, a background's before a foreground's; an
empty buffer writes nothing. The background pass after an analysis selects and clears a
background layer and draws every active element's background to completion into it, or asks a
display without the layer to redraw its background; the pass writes the renderers' own
characters and leaves text backgrounds pending (F112). The element on turn keeps its number
across an analysis that shortens the list, and the bound checks restart the cycle. The display,
active list, blink, settings and readings stay with the target, which carries out the operations
each call hands back.

The harness replays six sequences recorded from the reference as the OSD task steps the cycle,
one draw or display call at a time with readings rescripted between calls: eighteen elements
visible at random positions and variants, an occasional re-analysis with new positions and
sensors, and displays with and without a background layer and their own blink. Every return,
pending flag, element number, blink bit, craft name byte and display operation of the 3612 lines
replays byte for byte.

## D108. OSD spec prearm screen (2026-10-12)

The OSD spec unit contains the reference's spec prearm screen, drawn one row a call. The first
row is the RPM limit: on with its value when the limit is set and the motors run bidirectional
DShot, else off; with the limit on, the screen adds the motor's KV and pole count and the
limit's three gains. The throttle limit follows with its kind and, unless off, its percentage,
then the motor output limit, the pack voltage with two decimals and the battery symbol, and the
version, after which the screen is complete and starts again. Each row is centred on the
display's middle column; the first goes three rows above the middle row and each next row below
the one before. The settings, readings and version stay with the target, which writes each row.

The harness replays six sequences of 600 calls recorded from the reference under random limits,
motors, gains, batteries and display sizes. Every row's text, position and completion of the
3606 lines replays byte for byte.

## D109. OSD task (2026-10-13)

The OSD task unit contains the reference's OSD task: the update check and the update state
machine. The check wakes an idle task once the clock passes the frame's due time, which steps past
the clock by whole frames of a second over the frame rate, or starts one frame ahead; a check or
transfer state waits while the display transfers. Each update runs one state. The boot state, once
the display is ready, selects the foreground, opens a transaction, draws the boot screen, sets a
four-second pause, resets the element state and analyzes the active elements. Then come the
heartbeat; the three statistics steps with the arming screen and the clears they ask for, the
statistics page between the first and second when due, and the second opening a transaction each
time; the alarms, skipped while the menu holds the display; the canvas, which waits out the pause,
clears for the OSD switch, clears or copies the background layer, re-analyzes the elements when the
GPS sensor appears or goes, and syncs the blink; the draw cycle's element draws and displays; the
spec prearm screen after the elements while disarmed when the setting asks for it; the commit; and
the transfer, repeated while the display reports more to draw. Each update keeps a running peak
time per state, and per element place for the draws, decaying by one and replaced by a longer time,
and names the next state's anticipated time to the scheduler; the state times wrap past 2047 µs in
sixteen bits (F113). The display port's answers come in with the call and its operations go back in
order; the clock is read where the reference reads it. The statistics page renders only when its
readings fit the page's bounds, which every physical altitude does. Settings, readings and the
display stay with the target.

The harness replays six sequences of 1500 scheduler steps recorded from the reference, each a check
and, when due, an update, over MAX7456, MSP and FrSky displays with and without the logo and with
random answers, arming, switches, sticks, sensors and readings, six elements visible, the
statistics page off, and clocks that sometimes run a state past 2 ms. Every check result, state,
scheduler flag and time, page state, statistic and display operation of the 17162 lines replays
byte for byte.

## D110. MAVLink telemetry streams (2026-10-13)

The MAVLink telemetry unit contains the reference's stream messages: system status with system
time, raw RC channels, raw GPS, global position, GPS origin, home position, attitude, heartbeat,
HUD and battery status. Each message is packed in the library's wire order and framed as MAVLink 2
with trailing payload zeros trimmed, the link's sequence number and the message's CRC extra.

A pass runs when the receiver's buffer report asks for one, or 20 ms after the last pass when no
report is valid. It sends each message past its due time in table order and moves that due time
one interval past the clock, whether or not the message had anything to send. The pass ends with
the arming report: a status text of the disable reasons, cut at 49 characters, sent when the
reasons change to a nonzero set. The disable reason names move from the OSD warnings unit into the
arming unit, which both readers share.

Stream rates set the intervals, at least 20 ms, each first due one interval plus 3 ms per table
place ahead. A ground station sets one message's interval, zero restoring the rate's, and reads it
back in microseconds. The reply wraps above 4294967 ms (F115). Global position sends the
microsecond clock in its millisecond boot time field (F114). Port, receiver link and readings stay
with the target. Incoming commands and the mission protocol are open.

The harness replays six sequences of 500 steps recorded from the reference: telemetry passes under
random readings, rates, arming reasons and clocks, interval sets including unknown messages, and
interval reads. Every frame byte, due time, interval and sequence number of the 3006 lines replays
byte for byte.

## D111. MAVLink commands (2026-10-13)

The MAVLink commands unit contains the incoming side of the reference's telemetry file. Messages
from a ground station arrive two ways: drained from the telemetry's own port, up to 64 bytes a
pass through a frame parser of its own, or popped from the MAVLink receiver's queue, up to sixteen
a pass. The parser state moves out of the receiver's record into a record of its own so both
parsers share the code. MAVLink 2 framing moves into a unit of its own, shared by the stream
messages and the replies with one sequence number.

Ping and time sync requests are answered. A command long or command int addressed to this system,
or to every system, is executed and acknowledged. Command long also requests the autopilot
version, protocol version, component information, available modes, modes monitor and a message's
interval, and sets a message's interval. Both execute disarm, mode selection, return to launch,
set home and reboot. Arming over the link is a build option the default leaves out, so it answers
unsupported. Float parameters are decoded from their bits. A parameter counts as a whole number
only when finite, not negative and not above the handler's maximum.

Disarms, mode override clears and sets, and home resets and sets go out as requests in call order,
for the target to apply to the arming, modes and GPS units. An accepted reboot waits for the end of
the port's drain and goes out as a reboot request. One accepted from the receiver's queue stays
pending (F116). Coordinates, altitudes and intervals past the range of the reference's float
conversions saturate, where the reference is undefined (F117). A set-home altitude goes out as
commanded, and the home position telemetry multiplies it by ten (F118). The modes unit's override
mask, which the reference adds to the switch-selected modes and clears at each disarm, is open.

The harness replays six sequences of 500 steps recorded from the reference, alternating the owned
port and the receiver's queue: heartbeats, pings, time syncs, and command long and command int
messages with random targets and parameters (NaN, infinities, signed zeros, subnormals, handler
bounds), unknown messages, MAVLink 1 frames, noise and corrupted frames. Every reply byte, request,
home value, interval, sequence number and parser state of the 3006 lines replays byte for byte.

## D112. MAVLink mode overrides (2026-10-13)

The mode update takes a mask of overridden boxes and forces them on after the switches vote. A
ground station sets these boxes through the MAVLink commands (D111). The mask lives in the arming
state, where every disarm clears it before anything else, and the arming unit hands it to the mode
update. The reference keeps the mask with the mode state and clears it from the disarm path, which
gives the same order. Boxes are forced on or released one at a time, and the whole mask clears at
once.

The arming vectors were recorded again with a third random stream that clears, sets and releases
overrides before each step. Of the 15030 lines, 4015 change from the earlier recording. Overrides
are active in 3789 of the 15000 steps, and a disarm clears them 15 times. Every line replays byte
for byte.

## D113. Jeti EX Bus telemetry (2026-10-13)

The Jeti telemetry unit contains the reference's answer to a transmitter's telemetry request. A call
answers when the receiver may transmit, the request is a telemetry request no older than 3 ms with
a good CRC, and no byte waits on the port. A stale or failed request is dropped, and an answer ends
the permission to transmit. The receiver's request state gains the processed state an answer sets.

The first 255 answers are text messages that describe the enabled sensors and the two device
descriptions in turn. The answers after them carry sensor values: each message starts at the next
sensor and holds the following enabled sensors of its group of fifteen, at most four values. A
value takes three bytes with its decimals in the top byte, and a GPS coordinate takes four bytes of
degrees and thousandths of a minute with the longitude and sign flags. The GPS sensors leave the
values when the text phase ends with the GPS feature on, and return once a GPS is detected. The RPM
value averages the motors with fresh ESC data and rounds ties to even. With no sensor enabled the
reference reads a value length past its table (F119), and adaflight sends no value frame. A power
product past 32 bits wraps as the target's multiply does, and a G-force past 16 bits saturates.

The harness replays seven sequences recorded from the reference, each request frame fed through the
receiver byte by byte: telemetry requests, other requests, channel frames, corrupted and cut
frames, stray bytes, waits up to 5 ms and busy ports, under random sensor sets, readings and ESC
data. One sequence enables a single sensor, and one enables none and stops inside the text phase.
Every request state, permission, sensor set and frame byte of the 15707 lines replays byte for
byte.

## D114. FrSky SPI receiver, D8 (2026-10-13)

The FrSky SPI unit contains the reference's FrSky receiver on a CC2500 radio for the D8 protocol,
with the SPI receiver's LED and bind button handling and the CC2500 helpers. Start-up checks the
chip when the setting asks, raises the LNA and antenna pins, lowers the transmit enable pin and
claims the RSSI source. The first protocol call after 10 ms resets and configures the radio and
calibrates every channel. The target measures the calibration and hands it back.

Binding, on a bind request or with auto bind, tunes the frequency offset up and then down in steps
of two every 50 ms until a bind packet arrives at each end, keeps the midpoint, and collects the
transmitter id and the hop table in ten chunks of five. Bound, the receiver hops over 47 channels.
A packet from its transmitter with the CRC bit set hops on, sets the RSSI from its status byte, and
every fourth one is answered 1.38 ms later with the telemetry frame: transmitter id, A1 and A2
values and RSSI. Without packets the receiver hops on, switches antennas after two misses, drops
the RSSI after 100, and searches with a 13-channel skip at the slow timeout. Channels decode at two
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
acknowledges the last frame, the next frame starts a hub burst once the previous one is sent; when
it asks again, the unacknowledged bytes go out again. A burst lands in a 64-byte buffer and goes
out ten bytes a frame. A burst of 64 bytes or more fills the buffer and stalls it for good, as in
the reference (F122).

The harness replays the six D8 sequences of D114 unchanged and three more with telemetry on: one
with every sensor and a GPS fix, where the eighth hub cycle stalls the buffer, and two with random
sensor sets and settings, the scripted transmitter acknowledging nine telemetry frames in ten.
Every operation, frame byte and buffer count of the 27009 lines replays byte for byte.

## D116. FrSky SPI X receivers (2026-10-13)

The FrSky SPI unit gains the four D16 variants: FCC, LBT, and their V2 forms, each with its radio
configuration, packet length and telemetry delay. A V2 bind is one packet, decoded with the 0xA7
mask, whose transmitter id seeds a generated hop table that steps around each band's reserved
channels. A packet passes the D16 CRC over its body, the transmitter id, and the receiver number
when both sides set one. The first good packet after a reset gives the hop skip.

Each good packet stores the transmitter's telemetry slot by its sequence id and answers with
either a resend request for the first missing slot or an acknowledgement of the slots received in
order. Five resend requests in a row reset the transport. The receiver's own telemetry frame
alternates the RSSI and the A1 value, answers an init request, resends a slot on request, or fills
the next slot with up to five SmartPort bytes, and carries the D16 CRC. After the telemetry slot
the receiver waits 3.7 ms, hops by the skip, switches antennas after two misses, and resets the hop
skip after 100. Channels decode as eleven-bit values with a shift bit that moves a channel eight
up, and a failsafe packet leaves them as they were. SmartPort payloads over the link are open.

The harness replays eight sequences of 4000 calls recorded from the reference, two for each
variant, with a scripted transmitter: bind packets, D16 packets with random skips, receiver
numbers, failsafe flags, shifted channels and telemetry markers with init and resend requests,
corrupted and short packets, noise and dropouts up to 900 calls. Every operation, frame byte,
channel value, bind result and state of the 32008 lines replays byte for byte.

## D117. S-FHSS receiver (2026-10-13)

The S-FHSS unit contains the S-FHSS receiver on a CC2500 radio. The CC2500 radio unit now contains
what the SPI receivers share: the operations in order, the pins, the LED with its blink timer, bind
requests, the RSSI from a status byte, the antenna switch, register lists and channel calibration.
The antenna switch follows the antenna pin that start-up set. The first protocol call after 10 ms
resets and configures the radio and calibrates its 30 channels, six channel numbers apart from 16.
The target measures the calibration and hands it back.

Binding listens on channel 15. The frequency offset rises by 16 every 220 ms until a packet arrives
with a link quality above 40, which gives the transmitter id. The offset then widens by 4 up and
down while packets keep arriving within 880 ms, and the midpoint becomes the bind offset, or
binding starts over when the two ends meet. The coarse sweep wraps from 112 to -128 as a signed
byte (F125). Bound, the receiver hunts with a hop every 500 ms until a packet with channels 5 to 8
arrives, then hops 0.5 ms after that half, 3.5 ms after the other half, or 6.8 ms after a miss. It
switches antennas after two missed hops and hunts again after 100. Each packet's hop code moves the
channel. A code of 30 or 31 moves it past the calibrated channels, where adaflight writes zero
calibration and the reference reads past its table (F123). The proof shows that the hop loop ends
in every state the receiver can reach. Start-up reports success when the chip does not answer,
without the radio's pins or the RSSI source (F124).

The harness replays ten sequences of 3000 calls recorded from the reference with a scripted
transmitter: packets inside an offset window during binding with poor link quality, failed CRCs,
bad headers and other ids, a transmitter that goes quiet after the coarse sweep, channel packets
with failsafe flags, wrong channels and short FIFOs, hop codes 28 and 29 and an occasional code of
30 or 31, noise, dropouts up to 260 calls, bind presses and bind commands, a clock near its wrap
and a chip that does not answer. Every operation, channel value, bind result and state of the
30010 lines replays byte for byte.

## D118. Redpine receiver (2026-10-13)

The Redpine unit contains the Redpine receiver on a CC2500 radio, in a fast and a slow mode with
their own radio configurations. The first protocol call after 10 ms resets and configures the radio
for its mode and calibrates 255 channels, which the target measures and hands back.

Binding switches to the fast mode, configures and calibrates again, and listens on channel 0 with
the hop table cleared. The frequency offset rises by 16 every 220 ms until a bind packet arrives,
then widens by 2 up and down while bind packets keep arriving within 880 ms. Each bind packet gives
the transmitter id and five hop table entries at its chunk index. A chunk past the table writes
nothing beyond it, where the reference writes into the settings after it (F126). Binding starts
over when the two ends are 10 or less apart, and returns to the coarse sweep without clearing the
table while an entry is still zero. The midpoint becomes the bind offset. Auto bind blinks the LED
80 times over 4 s instead of saving, and restarts binding after any 2 s without packets (F127). The
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

The FlySky unit contains the FlySky receivers on an A7105 radio: AFHDS with eight channels and
AFHDS 2A with fourteen. The CC2500 radio unit becomes the SPI radio unit, shared by both radios, and
gains what the A7105 needs: an id write, FIFO writes of up to 64 bytes, a discarded register read,
a wait for a register to clear, the interrupt flag reset, and the LED's link loss blink. Start-up
resets the A7105, writes its id and registers, starts its calibration and waits for it, then
listens on the bind channel, or on the stored map when bound.

The radio raises an interrupt when it finishes a transmission or a reception. The target shows the
interrupt flag and its time, the mode and RSSI registers and the receive FIFO on each call, and
clears the flag on each reset operation. After a strobe to receive or transmit the receiver takes
the next interrupt, and after any other strobe it ignores the flag. After a transmission the
receiver hops when bound and listens again. A reception with a good CRC is a packet, and any other
answer restarts reception.

Unbound, an AFHDS bind packet gives the transmitter id, which chooses one of 16 channel tables and
an offset. An AFHDS 2A bind packet gives the id and the channel map, and the receiver answers it
0.5 ms later with its own id. Binding completes 200 ms after the last bind packet and saves the id
and the map. Bound, a packet with the transmitter's id, and for AFHDS 2A the receiver's id, gives
the channels as two bytes each, updates a 16-sample RSSI average and hops on. AFHDS 2A answers a
channel packet with telemetry every 57 ms: battery voltage, RSSI and error rate, the full frame the
first time and its changing part after that. Without packets the receiver hops by the packet times
missed, and after 32 timeouts lengthens its timeout and drops the RSSI. The error rate is the
number of packets short of 100 in each period of 101 packet times. The RSSI conversion leaves 0 to
1023 at both ends, and adaflight passes the values on as computed (F128). Unbound, AFHDS 2A reads
27 bytes of a packet, and adaflight reads zeros for the rest where the reference copies unread
bytes into five channels (F129).

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
count, and after 31 the receiver searches again. With the telemetry feature on, a packet on the
id's own seed is answered every 176 ms with the battery voltage and the RSSI percentage. A packet
length from the radio is taken up to 16 bytes with zeros for the bytes not read, where the
reference reads any length into a 16-byte buffer (F130).

The harness replays seven sequences of 3000 calls and one start-up with no radio, recorded from the
reference with a scripted transmitter for each protocol: bind packets with broken repeats and
checksums, two packets per 11 or 22 ms frame, receive errors with and without a bad CRC, short
counts, other ids, dropouts, bind presses and commands, the telemetry feature and a clock near its
wrap. Every operation, channel value, bind result, timer and state of the 21008 lines replays byte
for byte.

## D121. RC statistics (2026-10-13)

The RC statistics unit contains the statistics the OSD statistics page shows as full throttle time,
full throttle count and average throttle. Each update at 100 Hz takes the throttle percentage. Once
the throttle passes 15% after arming, each update while armed and out of crash flip counts a
sample, adds the percentage to the sum, adds the time since the last update while the throttle is
at 100%, and counts each new arrival at 100%. Arming clears only the raised flag, so the statistics
run from power-on across flights, as in the reference. The average is the float quotient of the sum
by the count plus 0.5, truncated. Before the first sample adaflight returns 0, and when 3D reverse
throttle has wrapped the unsigned sum it returns 127, where the reference conversions are undefined
(F131).

The harness replays six sequences of 3000 updates recorded from the reference: flights with arming
and disarming, throttle ramps and holds at full throttle, crash flip, irregular update times, one
sequence with 3D reverse throttle and one with a clock near its wrap. Every count, sum, time and
defined average of the 18006 lines replays exactly.

## D122. MSP override in the receiver (2026-10-13)

The receiver takes its raw channels as floats, so a provider's fraction of a microsecond reaches
the channel ranges as it does in the reference. The receiver unit adds the MSP override: the
channels set for it and whether it may stand in for a lost link. While any channel is set, every
channel reads as a whole microsecond. A channel that is set and fresh on the MSP receiver reads the
MSP channel within the pulse limits when the override mode is on, and the provider's channel
otherwise. The reference truncates every channel this way (F132). With the override mode on and
the link setting on, a complete override frame counts as a received frame in the frame check. The
frame check reads the MSP receiver's override status only then, since a read consumes it.

The receiver vectors gain eight sequences of 300 steps recorded from the reference with the
override compiled in: fractional pulses throughout, six with an override mask and random link
settings, the override mode switched on and off, MSP channels inside and outside the limits,
random freshness and override frame status. The 30 earlier sequences record byte for byte as
before. Every value of the 11894 lines replays exactly.

## D123. Receiver task (2026-10-13)

The RX task unit contains the receiver task's state machine. One call checks the receiver, the
next updates the modes when the check found data, and the next updates the RC commands and the
arming status; the caller runs the step the unit names. Every step but the last tells the
scheduler to ignore the task's rate. Unless the scheduler ignores the call's time, the estimate of
the step just run takes the scheduler's anticipated time when that differs, then the execution time
plus a microsecond when that is longer, and otherwise decays by a 64th of a microsecond. The
estimate of the next step goes to the scheduler. The unit takes the scheduler's values as inputs
and names its outputs, so it stays independent of the scheduler unit, and the target joins them.
An execution past 33 seconds counts as 33 seconds, where the reference's shift would overflow.

The harness replays four sequences of 4000 calls recorded from the reference task source with the
processing and the scheduler's hooks stubbed: random check results, execution times, ignored
execution times, anticipated times that echo the last estimate or change, and a clock near its
wrap. Every step, hook call, estimate and state of the 16004 lines replays exactly.

## D124. Barometer read cycle (2026-10-13)

The barometer task unit contains the barometer's read cycle. One call starts a temperature
conversion, the next calls read and sample it, and the same three steps follow for the pressure.
The pressure sample computes the altitude through the barometer unit and starts the cycle over,
from the pressure when the device reads both values at once. A start sleeps for the device's
conversion delay, and a restart sleeps for the rest of the 40 Hz period when the cycle was shorter.
Other calls sleep 1 ms. A read or sample the device has not finished keeps the phase and tells the
scheduler to ignore the call's time. A busy bus keeps the phase and tells the scheduler to ignore
the state's time. Every phase but the pressure start tells the scheduler to ignore the task's rate.
The unit keeps the longest execution of each phase without decay (F133) and names the next phase's
to the scheduler as a signed time delta, which wraps past 2 ** 31 microseconds. The caller makes
the device call the unit names and passes its answer, and after a finished pressure sample the
device's pressure and temperature. The unit is SPARK for its state machine and the time delta
conversion.

The harness replays eight sequences of 2500 calls recorded from the reference barometer with the
device, the bus and the scheduler's hooks stubbed: separate and combined reads, a device without
temperature delay, slow pressure conversions, unfinished reads, a busy bus, invalid pressures, a
ground level reset, execution times past 2 ** 31 microseconds, and clocks that start at zero or
near their wrap. Every phase, device call, hook call, sleep time, estimate and barometer value of
the 20008 lines replays exactly, with the altitude in the declared 3 cm tolerance (D6): 4 of 20000
altitudes needed it.

## D125. MSP state replies (2026-10-13)

The MSP out unit contains the replies that report the flight controller's state: the status and
extended status, the raw accelerometer, gyro and compass readings, the motor outputs, the RC
channels, the attitude as angles and as a quaternion, the estimated altitude with the vario, the
rangefinder altitude, the analog and battery state readings, and the debug values. The caller
gathers the state into a snapshot: the packed mode flags from the box unit, the arming disable
reasons, the sensors present, the profiles, the readings and the motor protocol's external
values. Each reply writes its fields in the protocol's order and width. Integers wrap to their
field. Readings and quaternion components round to the nearest integer with ties to even, and
pulses truncate. The battery voltage, drawn capacity and current saturate to their fields, and the
load to 100%. The extended mode flag bytes follow the count of active boxes. Any other command
writes nothing. The unit is SPARK for the reply length, which stays within the 36 bytes of a full
RC reply, and for the conversions.

The harness replays eight sequences of 500 requests recorded from the reference MSP processor with
the target's accelerometer, motor, rangefinder, vario, internal ADC and I2C switches on and the
state it reads stubbed: random snapshots with values inside and outside each field's range, ties
in the readings, and channel counts from 0 to 18. Every result, length and byte of the 4008 lines
replays exactly.

## D126. MSP GPS, ESC and clock replies (2026-10-13)

The MSP out unit adds the replies for the GPS solution, the home vector and the satellites, the
ESC sensor data and the motor telemetry, the pitot readings, the transmitter information and the
real-time clock. The GPS solution reports the fix as the reference's state flag value 2 and the
altitude in whole metres saturated to 16 bits, and the home direction drops to whole degrees. The
satellite list holds up to 32 entries. The ESC data comes from the ESC sensor when that feature is
on, from the DShot telemetry otherwise, and without either the reply is an error. The motor
telemetry takes the rate from the DShot telemetry ahead of the ESC sensor, the invalid share as the
whole without an active motor, and the extended DShot values when the motor reported them, which
the ESC sensor's record then overrides. Rates round to the nearest integer with ties to even, and
the pitot readings truncate to 32-bit integers. The clock reply is empty while the clock is unset.
The caller gathers each source's values into the snapshot, the ESC sensor's rate converted to
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
the output parameters, the acknowledgement and its own check. The unit takes the host's bytes one
at a time, where the reference blocks in a loop on the port, and asks the caller for each bootloader
operation in turn with the selected ESC, the address, the count and the data. A connect tries up to
three times, each with the STK500v2 bootloader first unless the interface is in the ARM mode, then
the BLHeli bootloader, and keeps the first device whose signature matches an Atmel, SiLabs or ARM
part. The other commands read, write, erase and verify the flash and EEPROM through the bootloader
of the interface mode, set that mode, restart the ESC with an optional 300 ms low pulse on its pin,
and report the interface name and versions. A flash write in the power-on C2 mode replies OK
without a bootloader call (F134). Starting the interface stops the motors and takes the pins of the
enabled motors as the ESCs. The exit command hands the pins back and restarts the motors when every
motor took its pin back. The receive LED lights from the escape byte to the reply, the transmit LED
from the check to the end of the reply. The interface mode, the device information and the selected
ESC carry over between sessions. The unit is SPARK for the 256-byte parameter buffer, the reply
length and the operation list.

The harness replays six sessions recorded from the reference interface with both bootloader
protocols on and the port, the pins, the motors, the LEDs and the bootloader calls stubbed: 120
frames each of every command with random addresses, lengths up to 256 and data, broken checks,
stray bytes between frames, scripted bootloader answers and device signatures, and one session
without ESCs. Every operation, bootloader call with its arguments, and reply byte of the 5530 lines
replays exactly. The host platform defines every pin configuration as 0, so the oracle gives the
input, output and alternate settings distinct values.

## D128. Gimbal control (2026-10-13)

The gimbal control unit moves a camera gimbal from a head tracker's frames and the sticks. The head
tracker's frames arrive on the gimbal port mixed with bytes for the gimbal, which pass through. A
frame is the opcode 16#5AA5#, the stabilisation mode and the sensitivity, the roll, pitch and yaw as
12-bit angles, and a CRC-16 CCITT sent high byte first. A valid frame goes on to the gimbal with
its angles scaled by the gains, the roll, pitch, yaw and throttle sticks added by theirs, the pitch
stick with separate gains below and above the centre, the offsets added, the limits applied, and
the configured mode and sensitivity. A frame with a broken check is dropped. After 250 ms without
bytes from the head tracker, each update sends the frame for the sticks alone. A byte after the
first opcode byte that is not the second goes on behind a byte 1 in place of the held-back first
opcode byte (F135). Without a configured port the control asks for its task to stop. The sticks lie
within the receiver's pulse limits, where every sum of the reference's 16-bit arithmetic stays in
range, and the integer scale truncates its division as C does. The output holds twice the input and
one frame, which no update exceeds. The unit is SPARK for the 12-bit field packing, the scale
arithmetic and the buffers.

The harness replays six sequences of about 1670 updates recorded from the reference with its
settings registered and the port and sticks scripted: default and random gains, offsets and limits,
valid frames, frames with broken checks, broken opcodes, passthrough bytes, gaps past the timeout,
a clock near its wrap, and a sequence without a port. The sticks start centred with the throttle at
its minimum, as the receiver leaves them before the gimbal starts. Every frame and output byte of
the 10061 lines replays exactly.

## D129. OSD custom text (2026-10-13)

The OSD custom text unit contains the text that a serial port sends for the OSD's custom text
element. A message ends with a line feed or a null as configured. Carriage returns are dropped, and
so are nulls when the line feed ends messages. The unit keeps the first 63 bytes of a message and
drops the rest up to the end of the message, and the text shows the first 31. An empty message
clears the text. Without a configured port the text stays empty. The port opening with its baud
rate default stays with the target. The unit is SPARK for the two buffers.

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
output alone. The task runs while any assigned box has a mode condition. The caller computes the
box states with the box unit and drives the outputs. The unit is SPARK for the box lookup and the
output contract.

The harness replays six sequences of 1000 updates recorded from the reference with the box table
for the permanent ids and the box states, mode conditions, outputs and task switch stubbed:
permanent ids that name a box, unset ones, and unknown ones, with the states and conditions drawn
at random. Every assignment, output and task state of the 6006 lines replays exactly.

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

The NRF24L01 unit contains the radio driver the NRF24 receivers share. Register writes go out as
SPI commands with the write bit, address registers as block writes, the payload read and the FIFO
flushes as their commands, and the chip enable pin sets the standby, receive and transmit modes.
The power-up waits out the chip's 100 ms settling time from start before it writes the
configuration, then 4.5 ms. Register reads, the status and the FIFO status, are inputs the target
supplies. The SPI radio unit gains the chip enable pin and a delay longer than sixteen bits for
that settling wait.

The V202 unit contains the V202 receiver. It takes 16-byte packets with a two-byte CRC on a fixed
address. Unbound, it hops the first row of the frequency table every millisecond and binds to the
first packet with both bind flags, whose transmitter id picks a table row and an offset for its
sixteen channels. Bound, a packet with that id gives the throttle, the three sticks in sign and
magnitude scaled onto 1000 to 2000 in integer arithmetic, four switches from the flag byte and three
from the mode byte; a bound receiver ignores bind packets and other ids. The receiver hops after
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
give its transmitter's address in reverse; the address's low five bits pick four hop channels,
computed as one 32-bit word stored low byte first. The X5C starts bound at 1 Mbit/s on its own
address and fifteen channels. Data packets give the throttle, the three sticks in sign and magnitude
scaled onto 1000 to 2000, a three-position rate, and four switches from the flag bytes. The receiver
hops every second packet and after 10 ms without one. The timeout compares a plain 32-bit sum, so
within 10 ms of the clock's wrap every call hops (F136). The X reads its headless switch from byte
14, which a 10-byte packet never writes, so the switch stays low (F137); the caller hands back the
receiver's buffer with the bytes a shorter packet leaves. The unit is SPARK for the hop table and
the channel scaling.

The harness replays six sequences of 2500 calls recorded from the reference driver and protocol with
the SPI commands, the chip enable pin and the clock stubbed, and the receiver's buffer static and
zeroed as on the target: both variants, bind packets with a scripted address, data packets, gaps
that make the receiver hop, a start inside the settling time, and three clocks near their wrap.
Every operation, result, channel, hop and address of the 15006 lines replays exactly.

## D135. XN297 payloads and H8_3D receiver (2026-10-13)

The XN297 unit contains the payload helpers for NRF24L01 receivers that talk to XN297
transmitters. The unscramble works in place: each byte as received joins a CRC-16 CCITT that
starts from 16#B5D2# over the receive address in reverse, then is XORed with its scramble byte and
bit-reversed; the CRC takes a final value per length.

The H8_3D unit contains the H8_3D receiver. Unbound, it hops the bind channels 6 to 38 every
millisecond and binds to a packet with a good check, three bind marks and a checksum over its
transmitter id. The id picks four hop channels and, when the receiver's id setting is empty,
becomes that setting; a stored id at start binds at once. A data packet with a good check gives the
four sticks between their ends with the truncating division of C, a three-position rate, six
switches, the camera tilt and three trims, each wrapped to sixteen bits. The receiver hops after
each data packet and after 5 ms without one, and the timeout compares a plain 32-bit sum (F136). The
unit is SPARK for the hop channels, the channel arithmetic and the buffer.

The harness replays six sequences of 2500 calls recorded from the reference driver, XN297 helpers
and protocol with the SPI commands, the chip enable pin and the clock stubbed: a transmitter that
scrambles its packets with the reference's tables, bind packets with good and broken checksums,
data packets with the sticks inside and outside their ends, broken checks, gaps that make the
receiver hop, a stored id at start, a start inside the settling time, and two clocks near their
wrap. Every operation, result, channel, hop and stored id of the 15006 lines replays exactly.

## D136. Battery meter sources (2026-10-13)

`Adaflight.Battery` contains the ESC sensor, virtual and MSP meters beside the analog ones. The
ESC voltage meter runs the combined ESC reading through the display filter while the ESC sensor
feature is on and reads zero once the data is more than 10 sensor periods old. With the feature
off the voltage meter keeps its last values. The virtual current meter starts from its offset and,
while armed, adds the throttle factor times the scale over 1000. The factor is the mixer throttle
in thousandths, rounded with a tie going to the even one, plus its square over 50, or zero at low
throttle with motor stop on. Its charge accumulates as the analog meter's does (D6). The ESC
current meter adds a tenth of the configured offset to the combined current, and the offset's
charge over the millisecond clock to the consumption. That charge comes from a 32-bit unsigned
product that wraps after 268 s at 16000 mA (F139), and the unit forms the same product. The MSP
meter reports the current and the capacity of the last analog reply and asks for a new reply
every 100 ms on the wrapping microsecond comparison. The rounding helper sits in the unit, so its
postcondition bounds the throttle factor for the proof.

The harness replays six sequences of 2000 steps recorded from the reference voltage, current and
battery logic with the ESC sensor reading, the throttle, the arming flag, the MSP replies and the
cell count scripted: ESC meters with fresh and stale data, the ESC feature off, the virtual meter
with motor stop and a clock across its wrap, the MSP meter's requests, and a 16000 mA ESC offset
past the wrap of its charge product. The virtual meter's scale stays within 1000 and its offset
within 2000, and the generator checks that the reference's charge product stays in range. Every
meter field and request of the 12006 lines replays exactly.

## D137. Flash filesystem (2026-10-13)

`Adaflight.Flash_FS` contains the volume the flight log writes to on SPI flash. The volume starts at
the start of the flash and spans the filesystem partition. Bytes go into a 128-byte ring buffer
that holds up to 127 of them. Once 64 are in use, an asynchronous flush hands the buffered runs to
the flash as one page program at the tail address, trimmed at the page boundary as the flash layer
trims it, and the tail address and the ring's tail advance when the program ends. A byte past a
full buffer empties it and loses the buffered bytes. The erase takes the chip erase when one
partition covers a whole NOR chip and otherwise erases one sector per call, toggling the status
LED, and turns the LED off at the end. The search for the start of the free space reads the first
sixteen bytes of 2048-byte blocks in a binary search and stops at a short read. A close puts the
tail on the next 2048-byte boundary, after the flash's flush and the next page on NAND. Synchronous
flushes, seeks and reads wait for the flash before and after their program.

The unit hands the flash its operations in order, as the SPI receivers do: ready checks and waits,
page programs with their bytes, erases, reads, the NAND flush and the status LED. Each call takes
the flash's readiness as it stands at the call, where the reference polls the flash at every check.
A flash that completes a program inside the program call, as a bus without background transfers
does, ends the program at once. On a bus with background transfers the caller reports each
program's end between calls, and a synchronous flush ends its own program after its wait, as the
reference's wait for the flash does. The unit applies every end the caller reports, where the
reference's flash layer drops the end of a program still in flight when an erase or a read starts
(F140). A synchronous write needs a flash that completes inside the call. The range erase has no
caller and stays out, as do the test pattern and the verify tool. The unit is SPARK for the ring
indices, the trimmed program lengths and the search bounds.

The harness replays eight sequences of 1500 calls recorded from the reference flash layer and
filesystem over a stub chip whose memory is an array: NOR and NAND layouts, one partition and two,
completions inside the call and between calls, completions that arrive late so the buffer fills
past its end, a short read in the search, a nearly full volume, sector and chip erases, seeks and
reads past the end, and closes. The stub completes programs as the m25p16 driver does, is busy
while a transfer is in flight, and has each pending completion delivered before an erase or a call
that waits for one. Every operation, program byte, result and state field of the 12008 lines
replays exactly.

## D138. Flight plan storage and waypoint capture (2026-10-13)

`Adaflight.Flight_Plan` contains the stored plan: up to 30 waypoints with their position in 1e-7
degrees and centimeters, speed, duration, climb rate, type, hold pattern and yaw behaviour. The
last three stay the configuration's bytes, for the executor to check. `Adaflight.Flight_Plan_Capture`
contains the capture gesture on the capture switch. A press samples the GPS position while the
executor is idle and the fix is good. A release before 1.5 s appends the sampled point as a fly-by
waypoint or reports the plan full, and a hold of 1.5 s deletes the last waypoint once per press,
so a hold works on a full plan. Edits are refused while the executor flies the plan, and invalid
channels freeze the gesture with its press time. Each edit leaves its message, formatted with the
printf-style formatter, for 2.5 s on the wrapping microsecond clock, and the OSD's read clears an
expired one. The OSD warnings line shows the message in the reference. That line gains it with
the executor. The unit is SPARK for the plan's bounds and the message buffer.

The harness replays six sequences of 2500 steps recorded from the reference capture with the plan,
the executor's activity, the fix, the position, the switch, the channel validity and the clock
scripted: short and long presses, signal losses during a press, an executor that starts and
stops, empty, nearly full and full plans, and a clock across its wrap. Every gesture state, plan
count, last waypoint and message of the 15006 lines replays exactly.

## D139. MAVLink mission protocol (2026-10-13)

`Adaflight.MAVLink_Mission` contains the MAVLink mission protocol over the flight plan, and
`Adaflight.Flight_Plan_Nav` contains the executor's orbit period it converts loiter turns with. A
ground station uploads a plan with a count and then each item on request. The unit asks for the
first item, for the next one as each arrives, and again after 1.5 s up to five times before it
cancels. Waypoints and splines become fly-by waypoints with their dwell. Loiter times, turns,
unlimited loiters, loiters to an altitude and follows become holds. The landing and takeoff forms
become landings and takeoffs, and altitude changes, delays and yaw speeds become the modifier
types. A return to launch in the last slot ends the plan. An item with a non-finite parameter, a
position out of range, an unsupported frame or a relative altitude without a home fix is refused
with its reason. The plan's count drops to zero when an upload starts and takes the received
count, less a final return to launch, at its end. A download answers requests for the next item or
the one before it, each stored item sent in the command that carries its type. A fence of up to 16
items is kept in memory the same way, without enforcement. Uploads and clears of the plan are
denied in the autopilot mode. A set-current request goes to the executor, and the caller hands its
answer back: the current item report when it took the index, an error acknowledgement when not.
The unit reports the current item every second and each waypoint the executor reaches. Wire floats
are decoded from their bits in exact steps, so the unit stays SPARK, and altitudes beyond the
32-bit range saturate (D6). The unit is SPARK for the payload offsets, the stores' indices and the
float decoding.

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
origin, now public in `Adaflight.Position_Estimator`, with the altitude offset between the
estimator and the GPS frame. The braking deceleration at a lean of 10 to 70 whole degrees takes its
tangent from a static table of the correctly rounded single-precision values, which the C
library's tangent gives at every entry, so the unit needs no elementary function. The rest point,
the carrot placed within the controller's 5 m reach of the craft or of its rest point, the braking
distance with a turn-in's width, the navigation deltas, the bearing with its 2 m floor and the nose
test follow the reference's operations. The angle wrap takes the remainder of the division by 360
by one exact subtraction of the whole turns, which equals the C library's remainder over the
inputs the executor gives it. The pattern carrot is an orbit or a figure eight through the centre.
The unit is SPARK for the plan's indices, the table and the geometry's bounds. Each square root is
held at a bound whose square covers its input, as the core's other bounded roots are, so the hold
never acts.

The harness replays 1200 calls of each group of helpers recorded from the reference executor with
random plans, waypoints, estimates, leg states and settings within the configuration interface's
ranges. Every result of the 9600 lines replays exactly.


## D141. Flight plan executor legs (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the second part of the executor: one cycle of a carrot leg.
The tracker reads back the carrot the navigation has walked and finds the next positional waypoint.
The corner speed comes from a constant velocity-change budget, and a point leg next lowers it to
its braking speed. The gate is the corner speed's radius on a fly-by and the arrival radius on a
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
returns its calls into the autopilot in order. The caller advances the plan on a crossed gate,
which is the executor's next part.

The unit is SPARK for the leg's bounds. Every cycle keeps the leg's points and the carrot within
the navigator's 2^18 m bound and the carrot's velocity within 1000 m/s in each component. Each
intermediate of the tracker has a stated range, and the steering, its turn, the corner speed and
the leg line are separate subprograms, so each proof runs in a small context. The leg's direction
and the steering aim are held within 2 in each component, which a unit vector never reaches, and
the carrot's velocity within 1000 m/s, which no cruise reaches, so no hold acts. The time a fault
is held saturates at 10^6 s, past the 2 s abort. `Adaflight.Maths.Atan2_Approx` now takes any
finite arguments, as the reference's does: the turn-in's course test passes it products of the
craft's velocity and its distance to the waypoint.

The harness replays 120 scenarios recorded from the reference executor with its rescue plan
compiled in. Each sets up a carrot leg through the navigation's own calls, with a craft that
follows the commanded velocity or only drifts, a nose that turns toward the commanded heading at
90 degrees a second, and a GPS course that follows the nose, off by a bias in some scenarios. Every
state field, autopilot call and commanded velocity of the 43076 steps replays exactly, and every
line of the executor's body runs.

## D142. Flight plan executor dispatch and landing (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the third part of the executor: the dispatch of a leg,
the arrival at a waypoint, and the landing. The dispatch walks past the modifier waypoints and
stages each for the next leg: an altitude override, a delay window, and a yaw rate cap the
autopilot is told of. The leg's target comes from the GPS distance, at the craft for a takeoff
and at the craft's resting point for the rescue's first stop. Its radius is the hold radius on
a station-keeping waypoint and the arrival radius, at most 12 m, on any other, and a rescue
leg arrives at the descent distance and brakes onto its point. A delay lowers the cruise to
cover the rest of the leg in the delay's time, never below 0.1 m/s. A carrot leg starts on the
craft when it turns in, from the carrot the leg before held the craft to, or from where the
craft comes to rest at its speed along the leg. A point leg goes to the navigator with its
arrival and the executor's reached handler, which the owner runs when the navigator reports
the leg reached. A face-the-target point leg first holds the craft where it is while the nose
comes round. The rescue's first stop without a heading starts the heading recovery's level
climb.

On arrival the listener hears the stored plan's index, a station-keeping waypoint with a
duration holds, a landing waypoint lands at the leg's target, and the plan advances or
completes. The rescue's first stop without a heading pitches forward instead, or waits for
the climb's drift to die away. A landing descends at no less than 0.3 m/s toward a target kept
200 m below the craft. It watches for touchdown once the descent is established, or once the
craft has been below the landing altitude for 5 s, and completes the plan with a disarm when
the descent has stopped for the touchdown time.

The navigator's command records whether its owner handles the arrival, in place of the
reference's callback. The executor's outputs became a list of the calls it makes out, to the
autopilot, to the arming, and to the reached waypoint's listener.

The harness replays 3000 calls recorded from the reference executor on random executor
states, navigator legs and plans within their ranges: half of them dispatches, a quarter
arrivals, and a quarter landings followed by up to 30 cycles of the touchdown watch. Every
executor field, navigator field and call of the 22175 lines replays exactly.

## D143. Flight plan executor update (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the fourth part of the executor: its cycle, its engagement
and the plans it takes. Each update takes its interval from the last, at most 0.25 s. The
rescue's heading recovery waits for the GPS course to stay within 5 degrees of the nose at speed
for half a second, or 2 s after the attitude trusts its heading, then turns in onto the next
leg, and aborts after 15 s without a heading. An idle executor dispatches again until the
estimator has an origin, and a leg the position controller lost is dispatched afresh. A landing
runs its touchdown watch. While a leg or a hold flies, an invalid estimate aborts, and past the
geofence's distance from home the executor returns home at the return altitude or lands in
place. A delay's end restores the leg's cruise. The rescue's blind climb keeps its target over
the craft and pitches forward once the climb's drift has died away or after 5 s. A leg runs nose
control, swaps a nose hold for the real target once the nose is round, flies a carrot or checks
progress, and on a heading fault parks the craft level and aborts. A hold counts time in
per-update deltas, starts a pattern once arrival braking has settled or after 5 s, advances
pattern phase every 0.2 s, and on expiry lands or moves on.

Engaging clears heading-fault park, nose command, modifiers and nose gate, captures altitude
frame, and flies a staged rescue plan or the stored plan from the waypoint a set-current chose
while idle. Disengaging drops plan and target. An injected plan of one to four waypoints
replaces the stored one while the executor is active, and a set-current moves the stored plan's
current waypoint, or the next engage's start while idle. Queries give distance and bearing in
tenths of a degree to the waypoint, and time to it at the craft's ground speed, at most 65535 s.

The harness replays 3600 calls recorded from the reference executor on random executor states,
navigator legs and plans within their ranges: half of them updates, the rest engages,
disengages, injections, set-currents and initializations. Every executor field, navigator
field, call and query of the 7200 lines replays exactly. Every line of the executor's body runs
except three the reference never reaches: landing in place when a return plan cannot be
injected, which the update only reaches while the executor is active; a point leg's progress
check without a target, which the update dispatches afresh first; and orbit period saturation,
beyond hold radius and cruise ranges.

## D144. Flight plan executor rescue plan (2026-10-13)

`Adaflight.Flight_Plan_Nav` contains the last part of the executor: the failsafe rescue's plan.
With a GPS fix and home, the plan climbs where the craft comes to a stop, returns home and lands
there. Its altitude is the highest flown plus the initial climb, a fixed height above home, or
the current altitude plus the initial climb, and never below the craft. A craft that stops
within the minimum start distance of home lands where it stops instead, and gets no plan without
a heading to hold that point. The plan replaces one already flying at once, or waits for the
next engage. Without a plan the rescue descends on altitude alone: alt hold's emergency descent
at the rescue's rate, with the landing's touchdown watch and disarm.

The harness replays 1440 stagings and 960 descents of up to 32 cycles recorded from the
reference executor on random executor states, navigator legs, GPS fixes and settings within
their ranges. Every executor field, navigator field and call of the 21766 lines replays exactly.

## D145. Autopilot navigation modes (2026-10-13)

`Adaflight.Position_Control` contains the autopilot's three navigation modes over the navigation
target (D94). A target flown at a velocity its owner states is tracked as a moving anchor. A fixed
target is approached through a reference point, seeded where the position error stands, walked
onto the target at the navigator's velocity and held within 5 m of the craft in each axis. A
target its owner moves without a stated velocity is tracked from within 5 m until it is 7.5 m
away and flown by the navigator's velocity otherwise, and each new leg starts unanchored.
Navigation takes up a leg with the feedforward filters at the nominal interval, the distance
error, its integral and the target velocity's history dropped, and no braking. A heading
recovery ends that continuity, so the leg is taken up afresh after it. On a leg the distance
error is held within 5 m, the integral stays at zero, and a leg's own lean limit applies below
the configured one. A leg whose velocity starts from the craft's motion seeds the feedforward
filters and the target velocity's history with the current command, on the first task of
navigation and on each new leg. Flying by velocity, the damping and feedforward drive that
builds speed is held to the configured buildup lean, and a drive that sheds speed is left
whole. On a leg the nose takes the override heading when one is set, and otherwise follows the
configured yaw mode. The velocity mode steers along the course over the ground above the
minimum forward speed and releases it below three quarters of that speed. The bearing mode
steers at the target outside its acceptance radius, or along a stated velocity above half a
metre a second. The hybrid mode steers along the course and falls back to the bearing. A rescue
flown as a plan leaves the rescue's own velocity mode to the navigation modes.

The navigator updates between the checks that fail a hold and the rest of the task, and a
reached leg's owner runs there, so a leg its owner replaces on arrival is flown on the same
task. `Begin_Step` and `Finish_Step` split the task at that point, and `Adaflight.Position_Hold`
offers the same split around its engagement and sensor checks. Its single `Update` finishes a
reached leg with no owner. The navigator's velocity is held at 2 ** 26 centimetres per second,
the bound of the controller's target velocity (D82).

The harness replays 16 flights of 900 tasks recorded from the reference autopilot and position
hold with the navigation module, 12 with the rescue flown by its own velocity and 4 with the
rescue flown as a plan: legs to fixed, moved and velocity-stated targets with every setter, an
owner that issues the next leg from inside the navigator's update on 18 of 31 arrivals,
retargets, clears, nose overrides, sticks, heading recoveries, level parks, estimate dropouts
and rescue windows, in every yaw mode. Every controller field, navigator field, lean and yaw
rate of the 14416 lines replays exactly.

## D146. MSP identification and meter replies (2026-10-13)

`Adaflight.MSP_Common_Out` contains the MSP out messages every MSP host answers: the protocol and
API versions, the firmware variant and calendar version, the MCU name, the board information,
the build information with its option codes, the unique id, the feature and beeper
configuration, the voltage and current meters, the analog voltage sensors, the analog and virtual
current sensors, the battery and transponder configuration, and the OSD canvas. The board
information covers the target's capabilities, names, signature, configuration state, gyro rate,
configuration problems and bus device counts. The version reply leaves out the version text for a
request from the port an HD video transmitter shares. The caller gathers the firmware's identity,
the target's options, the configuration and the meter readings into a snapshot, so the replies
hold no identity of their own. With the ESC sensor built in, both meter replies leave out the
per-motor slots past the motor count. The current meters keep the reference's trim, which drops
the MSP meter when that meter is built as well (findings F141). A displayed voltage rounds to
tenths within a byte, consumption and current in milliamperes saturate at the field's range, and
the year since 2000 and the cell voltages in tenths wrap to a byte. The beeper configuration
reply exists only with the beeper built in.

The harness replays 4800 requests recorded from the reference MSP processor in two builds, one
with every option the replies branch on and one without, on random identities, configurations
and meter readings. Every result, length and byte of the 4808 lines replays exactly.

## D147. MSP tuning replies (2026-10-13)

`Adaflight.MSP_Tuning_Out` contains the MSP out messages that report the tuning: the PID gains
with their names and controller, the rate profile, the advanced configuration, the filter
configuration, the advanced PID configuration, the board and sensor alignment, the arming
configuration, the 3D throttle and the stick deadbands. The caller gathers the active PID and
rate profiles, the gyro, filter, motor and system configuration and the build's options into a
snapshot. Each value keeps its configuration width and the reply narrows it to the protocol's
field: the first gyro cutoff wraps to a byte, the board alignment in degrees wraps to sixteen
bits, and the signed gyro yaw offset, compass alignment and profile cell count wrap to their
fields. A value whose option is left out of the build goes out as zero. Retired fields keep
their place in the layout and go out as zero, or one for the retired gyro sync divider.

The harness replays 4800 requests recorded from the reference MSP processor with the reference
PID names, in a build with every option the replies branch on and one without, on random
profiles and configurations. Every result, length and byte of the 4808 lines replays exactly.

## D148. MSP receiver and mode replies (2026-10-13)

`Adaflight.MSP_Receiver_Out` contains the MSP out messages that report the receiver and the
switches: the mode ranges, their logic and links, the adjustment ranges, the receiver
configuration, the failsafe configuration, each channel's failsafe, the RSSI channel and the
channel map. The mode replies name each box by its permanent id from `Adaflight.MSP_Box`, and a
channel's failsafe step goes out as its pulse, 750 microseconds and 25 more per step. The caller
gathers the configured conditions and ranges, the receiver and failsafe settings, the runtime
channel count and the build's options into a snapshot. The SPI receiver's settings, RC
smoothing, the USB device type and the ExpressLRS binding go out as zero when their option is
left out of the build, and the retired fields keep their place as zero.

The harness replays 4800 requests recorded from the reference MSP processor with its box table,
in a build with every option the replies branch on and one without, on random configurations
within their ranges. Every result, length and byte of the 4808 lines replays exactly.

## D149. MSP hardware replies (2026-10-13)

`Adaflight.MSP_Hardware_Out` contains the MSP out messages that report the hardware
configuration: the mixer, the motors, the compass declination, the GPS receiver, the GPS rescue
and its gains, the accelerometer trims, the flight log, the sensors selected and detected, the
gyros detected, and the flash and SD card storage. The caller gathers the configuration, the
recorder's rate divider and P ratio, the sensors detected, the storage state and the build's
options into a snapshot. The compass, GPS, rescue and trim replies exist only with their option
built. A sensor left out of the build reports its hardware selection as none and its detection as
16#FF#. The flash summary counts the partition's sectors from its first and last, and the SD card
summary merges the card's presence and health with the file system's state, giving the free and
total space in kilobytes once the card is ready.

The harness replays 4800 requests recorded from the reference MSP processor, in a build with every
option the replies branch on and one without, on random configurations and storage states. Every
result, length and byte of the 4808 lines replays exactly.

## D150. MSP peripheral replies (2026-10-13)

`Adaflight.MSP_Peripheral_Out` contains the MSP out messages that report the peripherals: the
servo outputs, the servos' configuration and mix rules, the motor output order, the LED colors,
the LED strip and its mode colors, the video transmitter's configuration, and the wing's tuning.
The caller gathers the outputs, the configuration, the transmitter's state, the target's servo
count and strip length, and the build's options into a snapshot. Signed values wrap to their
fields. The servo, LED and transmitter replies exist only with their option built, and a strip
built without its status mode reports every LED as zero. The transmitter's type, pit mode and
readiness come from its device when one is present. The reply for the MSP transmitter's own port
also marks that transmitter ready, and that call stays with the caller.

The harness replays 4800 requests recorded from the reference MSP processor, in a build with the
servos, the 64-LED strip with its status mode and the transmitter with its table, and one
without them, on random outputs, configurations and devices. Every result, length and byte of the
4808 lines replays exactly.

## D151. MSP text, table and battery profile replies (2026-10-13)

`Adaflight.MSP_Text_Out` contains the MSP out messages that answer with text, a table row or a
profile: the craft name, a text by its type, a video transmitter band or power level from the
frequency table, the LED strip's brightness and rainbow, and a battery profile. The request's
first byte selects the text type, the band, the level or the profile, and the profile falls back
to the active one without it. An unknown text type, a text the build leaves out, a band or level
outside the table and a profile beyond the third are errors that write nothing. The caller
gathers the names, the build key and release name, the battery profiles, the strip settings and
the table into a snapshot. The table replies exist only with the table built and the strip
values only with the strip. A band or level reply to the MSP transmitter's own port also marks
that transmitter ready, and that call stays with the caller.

The harness replays 4800 requests recorded from the reference MSP processor with the reference
build strings, in a build with the table, the strip, a build key and a release name, and one
without, on random names, profiles, tables and request bytes. Every result, length and byte of
the 4808 lines replays exactly.

## D152. Simplified tuning filter sliders (2026-10-13)

`Adaflight.Simplified_Tuning` contains the filter sliders beside the gain sliders. With the D term
filter slider on, each D term lowpass cutoff in use is set from its default through the slider in
percent: the dynamic range from 75 and 150 hertz, the first static cutoff from 75 and the second
from 150, each held to 1000 hertz. The gyro filter slider does the same for the gyro lowpass
filters from 250 and 500 hertz. A cutoff that is off stays off. Apply runs the gains, the D term
filters and the gyro filters in that order, and Disable turns every slider off.
`Adaflight.Gyro_Filters.Settings` gains the gyro filter slider and its multiplier. The dynamic
range's ends are written in the order that keeps the lower end at or below the upper end at every
step, the invariant the profile and gyro settings state.

The harness replays 6000 calls recorded from the reference simplified tuning on random profiles
and gyro configurations within their ranges, each applying one slider set or turning the sliders
off. Every gain, cutoff and flag of the 6000 lines replays exactly.

## D153. MSP simplified tuning messages (2026-10-13)

`Adaflight.MSP_Simplified_Tuning` contains the MSP messages of simplified tuning: slider read with
D term and gyro cutoffs, gains, D term filters or gyro filters computed from a requested slider set
without storing them, validation of gains, gyro filters and D term filters against their sliders,
and an in message that stores a slider set with its cutoffs and applies every slider. A request
reads zero past its end. A request with a field outside its setting's range is an error that
writes and changes nothing: mode beyond roll, pitch and yaw, gain slider above 200, filter switch
above one, filter multiplier outside 10 to 200, cutoff above 1000 hertz, or dynamic range with its
lower end above its upper end (D6). The in message checks the whole request before it stores
anything. Dynamic range ends are written in the order that keeps the lower end at or below the
upper end at every step.

The harness replays 4800 requests recorded from the reference MSP processor on random profiles and
gyro configurations, about a third of them already at their sliders' result, with requests within
their ranges, short, long, or with one field outside its range. Every result, length, reply byte
and setting of the 4025 requests within their ranges replays exactly, and each of the 775 outside
them is an error that leaves the settings unchanged.

## D154. MSP OSD replies (2026-10-13)

`Adaflight.MSP_OSD_Out` contains the MSP out messages of the OSD: configuration and warnings line.
The configuration reply holds OSD flags from the display device's type and readiness, video
system, units, alarms, element positions, statistics enabled, timers, warnings enabled as low half
and full mask, profile count and selection, stick overlay mode, camera frame, and link quality and
RSSI dBm alarms. A reply to the MSP display port's own serial port keeps the layout of the first
80 elements without the RSSI dBm alarm. A build without the video system, profile or stick
overlay options reports the HD video system, one profile selected, or overlay mode zero. The
warnings reply gives the line's severity with the blink bit and the line as a length-prefixed
string. The element set is the 89 items of D102. The caller gathers the settings, the display
device's type and readiness and the rendered warnings line into a snapshot.

The harness replays 4800 requests recorded from the reference MSP processor, in a build with the
video system, profiles, stick overlay, MSP display port with its font and frame buffer OSD and
one without, on random settings, devices and warnings lines. Every result, length and byte of the
4808 lines replays exactly.

## D155. Serial feature map (2026-10-13)

`Adaflight.Serial_Feature_Map` contains the map between the features that name a serial port in
their own settings and the per-port view of function bits and baud rates: a port's function bits
and its baud rate of a class from the features naming it, the claims on a port with their setting
names, a function mask applied to a port, a baud rate applied to a port's features of a class,
implied MSP ports, port conflict rule, configuration check and its fix. Applying a mask clears
every claim on the port first, and changes nothing when the mask asks for two VTX protocols or for
more MSP or telemetry slots than are free. A port's functions conflict when MSP or a serial
receiver is on a soft serial port, when an MSP VTX is alone on its port, or when shared functions
are neither MSP with functions that share with it nor a serial receiver with telemetry it carries.
The fix drops every claim but MSP on each conflicting port and, when the assignment is still
invalid, clears every claim and puts MSP on the target's first port at its default baud rate. The
build's features, telemetry protocols and soft serial ports come in as options, with one telemetry
slot per protocol built, at most three. The rangefinder's and optical flow's hardware enter as
whether they talk MSP.

The harness replays 4800 operations recorded from the reference feature map, conflict rule, port
types and telemetry port sharing check, in a build with every feature that names a port and one
without the ESC sensor, RC device, gimbal, Tramp and MSP VTX, rangefinder, optical flow, MSP
display port and MSP over telemetry, on random assignments, half of them sparse. Every function
mask, claim, baud rate, conflict, check result and assignment of the 4808 lines replays exactly.

## D156. MSP serial port replies (2026-10-13)

`Adaflight.MSP_Serial_Out` contains the MSP out messages of the serial ports in the legacy and the
common layout: each available port's identifier, an empty function mask and its baud rate of each
class from the serial feature map (D155), with the common layout led by the count of available
ports and carrying a 32-bit mask. Port functions live in the features' settings and the command
line shows them, so both layouts give an empty mask, which an older configurator reads as an
unassigned port. The caller gives the target's ports with their availability, which the serial
layer's initialization and port removals decide, the build's options and the feature assignments
in a snapshot.

The harness replays 4800 requests recorded from the reference MSP processor with the reference
feature map and serial layer linked, in the full and the reduced build of D155, on random
assignments with soft serial on or off and random ports removed. Every result, length and byte of
the 4808 lines replays exactly.

## D157. MSP transmitter device status (2026-10-13)

`Adaflight.MSP_VTX_Status_Out` contains the MSP out message of the video transmitter's device
status: device type and readiness, band and channel, power index, frequency and status with whether
the device knows each, power levels in decibel-milliwatts and milliwatts, and the device's own
status block. The values come from the driver of the device in use, SmartAudio (D84), Tramp (D86)
or MSP (D98), and a value the device does not know goes out as zero. The status has the pit mode
bit and, for Tramp, the race lock bit. SmartAudio reports its own power levels from version 2 on,
the MSP device reports the table's, and Tramp reports none. Only SmartAudio has a status block of
its own: version, mode, pit mode frequency and boot flag; the others send a zero length. Nothing
goes out without a device. The RTC6705 driver is not ported, so its device does not appear.

The harness replays 4800 device states drawn into the reference common transmitter layer and its
SmartAudio, Tramp and MSP drivers, with random frequency tables, each step making one device
current or none. Every length and byte of the 4808 lines replays exactly.

## D158. Configuration storage image (2026-10-13)

`Adaflight.Config_Store` contains the storage image of the parameter groups: header with storage
version 178 and magic byte, one record per group with its size, group number, version and class,
zero terminator, and the CRC over all of it, inverted and big-endian, so the CRC of the whole image
is a constant. The structure check scans the records to the terminator, each record at least its
own header long and ending before the region does. Lookup finds a group's first record of a class
with the same scan. Loading resets every group to its defaults, takes its stored bytes when a
system record has the group's version, as many as the group holds, and hashes each group with
FNV-1a. Saving writes only when the image's version or structure is invalid or a group's bytes no
longer match its hash; it zeroes the region, as the reference's RAM storage does, then writes
header, records, terminator and CRC. Each group's bytes are adaflight's own layout, so an image
the reference writes does not load. Bytes past the region read as erased and an image longer than
the region is not written (D6).

The harness replays 4800 operations recorded from the reference storage code over a 512-byte RAM
region with six parameter groups: structure checks, lookups, loads and saves on images built from
random records, about a third of them clean and the rest often corrupted, never one whose scan
reads past the region. Every result, group, hash and image byte of the 4808 lines replays exactly.

## D159. Mixer setup (2026-10-13)

`Adaflight.Mixer_Init` contains the mixer setup: each mixer mode's motor count, whether it drives
servos, and its motor table where the build has it; the motors in use and their mix, from the
mode or, for the custom modes, from the custom table up to its first entry without throttle, at
most the build's motors; the launch control mix, which holds every motor that pitches the nose up
at zero; disarmed outputs reset to the disarm value; a mode's table loaded into the custom table
for the command line; and whether the motors run or saturate. The modes keep the configuration's
order, from tri to octo X8 plus. The build's options select quad X only, the uncommon frames, the
motor count and launch control. A mode whose table the build leaves out keeps the previous mix
for its motor count, as the reference does (findings F144). The motor mixer (D16) takes the count
and the mix.

The harness replays 4800 setups recorded from the reference mixer setup, in a build with every
frame, launch control and 8 motors, one without the uncommon frames and launch control for 6
motors, and one for quad X only, on random previous and custom mixes and outputs. Every count,
flag and weight of the 4808 lines replays exactly.

## D160. Task setup (2026-10-13)

`Adaflight.Task_Init` contains the task setup over the scheduler's task table: which tasks run
from boot and at what period, from the build's options, the features, the sensors detected and
the settings, in the reference's order. The serial task takes its update rate, the voltage task
the fast rate with sag compensation, the gyro, filter and PID tasks the gyro's sample and loop
periods, the accelerometer task its sample rate, the telemetry task 500 hertz on a Jeti Ex Bus or
CRSF receiver, and the OSD task its frame rate. The battery alert task runs with a meter and an
alert or the OSD, the position task with any measurement source, the hold tasks with their
sources, and the menu task with the MSP display port or the OSD or dashboard. The heading hold
task follows the compass and a heading mode on a switch, and is set again whenever the modes
change. The caller gives the PINIO box task's state, which `Adaflight.PINIO_Box` decides.

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
identifier) with its limits, and the parameter group that holds it; and the 72 lookup tables of
value names. A local tool generates the unit from a settings oracle: the reference's settings table
and parameter group sources built for the host with the option set of an STM32F405 board and the
options of the features adaflight implements beyond it (acro trainer, 3D speed, chirp, Galileo,
gimbal, GPS lap timer, pitot with its MS4525 driver, the flight plan, the MSP current meter, PID
audio, the UPT1 optical flow and two soft serial ports). Names and lookup strings are verbatim (D2).
A lookup entry the build leaves out, a driver compiled away, has an empty name, which the command
line skips. The values, their defaults and the groups' records follow in the next steps of the
configuration layer, and the hardware settings wait for Phase 7. The unit is SPARK at no cost, and
its lookups prove in range.

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
for 7 the field is wider than the setting's type, so only its low bytes are read; no setting's range
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
run reset, PID loop slowed to the motor protocol's update rate, profile selections past their
counts back to the first, rates held to their type's limits, and battery voltages out of order back
to their defaults. `Fix_Gyro` is the gyro's part alone, which also runs once the gyro's sample rate
is known and after the MSP advanced and filter configuration writes.

Hardware inputs: gyro sample rate, motors in use, timer behind each pin and board's serial ports.
The runtime feature mask is a parameter: a load starts it from the configuration's features, a save
passes the running mask, and the ADC's RSSI channel follows it. The results name the serial port the
MSP display port draws over and the GPS port taken out of use, for the caller to apply to the
running ports. A port setting outside the serial map's identifiers stands for a port the board does
not have, and a port setting changes only where the serial check changed it.

Three inputs make the reference read past a table or shift past a word: a mixer mode past 27
(F150), a rates type past 4 (F151) and an MSP override condition's aux channel past 27 (F152).
adaflight leaves such a mode and such rates as they are and takes such a channel to name no bit
(D6). Sensor alignment codes past the custom one wrap onto the eight standard alignments.

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
over the configuration's settings. A line keeps its printable characters past the leading spaces,
up to 255 of them, loses a comment from the first number sign and its trailing spaces, and names a
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

A command word followed directly by a comment takes the comment as its arguments (F153), so
`get#motor_pwm_rate` prints that setting. adaflight reproduces it. On the oracle's 64-bit host the
C library reads a number past the 32-bit range by its low 32 bits, where a 32-bit target holds it
at the range. adaflight follows the target. The recorded numbers stay within the range, where the
two agree.

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

The line's command words are read from the line buffer by position, so an option after a section
name that a comment cut off still applies (F153): `dump profile#defaults` dumps with defaults.

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

Prefix matching takes the first match (F154): `feature R` enables RX_PPM and `feature -` disables
it. adaflight reproduces it.

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

A diff prints no `mmix reset` or `smix reset` line, since both follow the default configuration's
first motor and first rule (findings F169), and its flight plan lines print with no heading of their
own (F170). A changed beeper's default line, and some features' default lines, print before their
headings (F171, F172). A channel failsafe default line takes the format of the channel's own mode
(F173). A VTX band compares its name without regard to case, its letter and its frequencies, and the
power values' and labels' default lines list all eight entries (F174). With the printers in the
master dump, the unit's largest prover process holds 3.9 gigabytes, for `Dump_Master`.

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
A different value for a stored one is the error. The signature reads each pair with spaces and a
sign allowed before its digits, a minus negating the byte (findings F175), and a long name or
manufacturer keeps its first characters (F176). The dumps and `version` print the board's lines from
this state.

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
keyword, a missing group or a zero group is the parse error. A word only has to contain its keyword,
and the group number wraps to 16 bits (findings F178).

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
constructor is the one boundary between them; a stored value outside its range is held to the range
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
and PID loop groups, the current PID profile, the features in use and the sensors found at boot; the
fixed wing flag comes from the mixer mode through `Mixer_Init.Is_Fixed_Wing`. `Conditions_Of` builds
the mode conditions, a condition whose mode is outside the box table never active and a link outside
it no link (D6).

`RC_Config_Of` builds `RC_Command.Config` from the stored receiver, RC controls and PID loop groups
and the current rate profile, through `Rate_Profile_Of`, with the sample time whose product with the
loop ratio is the loop time. The command path's minimum check is held to 1999, below its setting's
2250 (D6). `Adjustment_Settings_Of` builds `Adjustments.Settings` from the stored receiver and system
groups.

`Mixer_Config_Of` builds `Mixer.Config` from the stored mixer, motor, 3D and receiver groups, the
current rate and PID profiles, the custom motor mix, the features in use and the build's mixers. The
output range comes from the protocol family: `DShot.Endpoints` for the DShot family, and
`PWM_Output.Endpoints` for the analog family, which raises the minimum command by a tenth of the idle
setting and brings the maximum throttle down by what the output limit leaves of the span, or in the
two direction mode brings the 3D limits in by half the limited span. The range is then held to the
motor values and at least one step wide, with the disarm output held below its top; a disabled
protocol's range is zero to one. The motors in use and their mix come from
`Mixer_Init.Configure_Output`, over a mode outside the table read as quad X and weights that are not
numbers read as zero; a custom mix without motors reads as one motor with a zero mix (D6).

`Accelerometer_Settings_Of` builds `Accelerometer.Settings` from the stored accelerometer, gyro
device and board alignment groups, with the hardware's sample rate and counts per g; the alignment
is the first gyro's, since the boards use one chip for both. `Attitude_Settings_Of` builds
`Attitude.Settings` from the stored IMU and throttle correction groups, `Barometer_Settings_Of`
builds `Barometer.Settings` from the stored barometer group, with the virtual device from the
hardware code, and `Compass_Settings_Of` builds `Compass.Settings` from the stored compass and board
alignment groups.

`Battery_Settings_Of` builds `Battery.Settings` from the stored battery, voltage meter, current
meter, virtual meter and ESC sensor groups and the current battery profile. `Beeper_Settings_Of`
builds `Beeper.Settings` from the stored beeper group, each sound's flag from the bit below its code.

`GPS_Link_Settings_Of` builds `GPS_Link.Settings` from the stored GPS and GPS rescue groups, with
whether a serial port has the GPS function; the baud is the user's from the module's table, 230400
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
build is a wing; a serial device runs fast from a megabaud up. `Scheduler_Settings_Of` builds
`Scheduler.Settings` from the stored scheduler group, with the platform's clock, its floor on a
rescheduled period and the gyro's period. `LED_Strip_Settings_Of` builds `LED_Strip.Settings` from
the stored LED strip and status mode groups, the first eight stored special colors being the
strip's. `VTX_Settings_Of`, `Flight_Stats_Settings_Of` and `Lap_Timer_Settings_Of` build their
settings from the stored VTX settings, statistics and lap timer groups.

`Rangefinder_Settings_Of` builds `Rangefinder.Settings` from the stored position group, with the
cone the detected sensor reports; `Optical_Flow_Settings_Of` and `Pitot_Settings_Of` build their
settings from the stored optical flow and pitot groups; `Gimbal_Settings_Of` builds
`Gimbal_Control.Settings` from the stored gimbal tracking and receiver groups, with whether a serial
port has the gimbal function; and `RTC_Settings_Of` builds `RTC.Settings` from the stored time group.

`OSD_Page_Settings_Of` builds `OSD_Page.Settings` from the stored OSD and OSD element groups, with
whether the display supports a logo; an element is visible when its stored position shows it in the
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
and receiver groups and the features in use. A radio's pins come from the stored pin tags. The
FrSky SPI protocol comes from the SPI protocol code, FrSky D for a code outside the family, the
FlySky variant is AFHDS 2A for its code and AFHDS otherwise, and the Spektrum kind comes from the
serial provider, Spektrum 2048 for a code outside the three (D6).

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
engage the plan; without one it lands. A link loss during a mission enters the autopilot stage at
once when the autopilot's loss policy continues the mission, or lands when the policy lands; the
mission's own throttle keeps the low-throttle shortcut from disarming. In the autopilot stage the
failsafe recovers on stick movement or a switch, lands when disarmed, waits through the grace period
while the plan is not yet engaged, falls back to the configured procedure, auto-landing in place of
the rescue, when the mission ended or never engaged, and sounds the landing tone otherwise. The
plain GPS rescue stage of a build without the flight plan is in the state machine but not entered,
as in the reference's build with it.

The harness builds the four PID profiles and the four rate profiles of every fixed configuration in
the configuration fix recordings, 16000 of each, the arming, failsafe, receiver, adjustment, mixer,
attitude, barometer, compass, battery, beeper, GPS link, GPS rescue, position control, position
estimator, position hold, altitude control, altitude hold, flight plan, blackbox, scheduler, LED
strip, VTX, statistics, lap timer, rangefinder, optical flow, pitot, gimbal, clock, OSD page, OSD
render, OSD specification, OSD warning, OSD alarm, the eight telemetry and the eight receiver link
settings and the mode conditions of each, 4000 of each, and the gyro, RC command and accelerometer
settings of each with a running gyro and motors, 3082, with the preconditions and the predicates
checked at run time, and compares one field of each. The analog endpoints replay 235 recorded motor and 3D settings from
the DShot oracle bit for bit, 70 of them with an inverted range (findings F181).

## D189. Command line batches (2026-10-14)

The command line's text goes out through an `Output` record: the sink the instantiation supplies,
and the command batch's state, whether a batch is open and whether a command in it printed an
error. Every error goes through one printer, `Put_Error`, which prints `###ERROR IN ` and the
text, and notes the error when a batch is open. `batch start` opens a batch and clears its error,
unless one is open already, and prints `Command batch started`. `batch end` prints `Command batch
ended`, or the error line `ERRORS WERE DETECTED - PLEASE REVIEW BEFORE CONTINUING` when a command
in the batch printed an error, and closes the batch either way. Any other option is the `Invalid
option` error. An option only has to begin with its word, in any case (findings F180). A
`defaults` reset clears the batch's error and leaves the batch open.

A line naming no command gets the reply `ERR_CMD_NA: ` and the line, with its comment and trailing
spaces cut, and no error is noted. This is the reply of the reference's non-interactive stream,
which the oracle records. Its interactive session prints the `UNKNOWN COMMAND, TRY 'HELP'` error
instead, which notes the error (findings F179); that error, the echo and the prompt belong to the
target phase's interactive session. `Process_Line` reports Handled false only for `defaults`
without `nosave`.

The harness replays two sequences of 1019 command lines in all, recorded from the oracle: batch
starts and ends in any case and with trailing text, settings and commands with and without errors
between them, unknown lines, stored values past a setting's range and their gets, diffs and resets
inside batches, and batch commands with bad options. With the earlier sequences, all 62611 replies
match the reference's byte for byte, and so does the configuration's hash after every command.

## D190. Core loop cadence and yaw reset (2026-10-14)

`Adaflight.Core_Loop` holds the core loop's cadence: a counter of gyro samples that starts over at
a multiple of the PID loop ratio and counts from one, with the gyro filtering ready when the count
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

The harness replays the cadence and the yaw rule on every step of the arming recordings, 15000
steps of one to three samples each over loop ratios of one to eight, and compares the counter, both
ready flags and the yaw reset with the reference's. The recordings hold the calibration state before
each step's commands for the receiver pass and the state after them for the PID loop and the final
status update, which a stick calibration in the same step as an arming attempt tells apart.

## D191. PID loop pass (2026-10-14)

`Adaflight.Main_Loop` is the PID loop's pass over the units in the task's order, a generic whose
procedures are the units: the yaw reset before the RC command, the launch wing in a wing build, the
controller with the runaway check and the PID audio after it, the mix, the servos when the mixer
drives them, the motors, and the flight log outside the command line when a log device is set. The
pass reads those conditions as inputs. `Adaflight.Main_Loop_Shape` instantiates it over counting
units for the proof; the target phase instantiates it over the units' updates with their states.

The harness instantiates the pass over logging units, one letter each, on every step of the arming
recordings, with the runaway check over the arming state, and compares the letters with the order
the reference's loop called its units in, over 15000 steps with the servo, flight log and command
line conditions drawn at random. The recordings hold no PID audio condition.
