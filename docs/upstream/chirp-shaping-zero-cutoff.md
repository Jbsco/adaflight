# Chirp shaping filter with a zero lag or lead

Betaflight 2026.12 (master as of 2026-10-08). Finding F372, `DESIGN.md` D892. Not reported upstream.

## Betaflight

Builds with chirp excitation set up its shaping filter from chirp_lag_freq_hz and chirp_lead_freq_hz, whose settings allow 0. Its ratio divides lead by lag, and its centre is lag times that ratio's root. A lag of 0 makes that ratio infinite and its centre and phase not a number, and a lead of 0 gives an infinite gain. Either way its coefficients are not numbers.

Each rate loop runs that filter and adds its output, times chirp amplitude, to its axis's setpoint, roll after start-up, whether chirp mode is on or not. Roll setpoint is then not a number from its first loop.

Betaflight's PID controller at af0638839, built for its unit tests with chirp on, was run with chirp_lag_freq_hz at 0 and chirp mode off. Roll P, I and PID sum were not a number from its first loop.

## adaflight

Its shaping filter takes a lag or lead of 0 as 1.

## Proposed change for Betaflight

Raise the minimum of chirp_lag_freq_hz and chirp_lead_freq_hz to 1, or skip the shaping filter while chirp mode is off.
