# PPM input on a motor's timer takes a count divisor that wraps to 0

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-18). Finding F364, `DESIGN.md` D807. Not
reported upstream.

## Betaflight

When a motor runs on the PPM pin's timer, `ppmAvoidPWMTimerClash` sets `ppmCountDivisor` to
`timerClock(timHw) / (timerGetPrescaler(timHw) + 1)`. `timerClock` is in Hz, so the quotient is the motor
timer's count rate in Hz, and `ppmCountDivisor` is a `uint8_t`, which keeps it modulo 256. A DShot600 timer
counts at 12 MHz, and 12,000,000 modulo 256 is 0, which the PPM edge handler divides by. DShot300 gives 128.

`ppmRxInit` then calls `timerConfigure`, which sets that timer to count at 1 MHz over 65,536 counts. PPM counts
are then microseconds, and any divisor but 1 is wrong. The DShot driver never writes its prescaler again, so
the motors on that timer send bits at 1 MHz counts, far too slow for DShot. Without burst mode each motor
update also clears the counter that PPM reads.

## adaflight

A PPM pin on a timer that a motor uses gets no PPM input. The receiver then reads no signal, as with no PPM pin.

## Proposed change for Betaflight

Refuse PPM on a timer that a motor uses. One timer cannot count at the motors' rate and at 1 MHz.
