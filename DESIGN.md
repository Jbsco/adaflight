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

## D7. Linear history (2026-10-08)

Branches start from and rebase onto `origin/main`. Pull requests merge by rebase only,
one at a time, and every pull request re-runs the gates after its last rebase. The
repository settings on the forge disable merge commits and squash merges and require a
linear history on `main`. Commit messages are one imperative line, signed.

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

## D10. Deferred: fast exponential and logarithm (2026-10-08)

The reference builds these from the bit layout of a float. SPARK does not admit an
unchecked conversion to a floating-point type, so the port needs a different
construction. The single consumer is a telemetry scaling, so the port waits for that
increment.
