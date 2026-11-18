# Parallel PWM input on a motor's timer resets that timer's time base

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-18). Finding F365, `DESIGN.md` D810. Not
reported upstream.

## Betaflight

`pwmRxInit` takes each PWM input pin's timer channel with `timerAllocate`, which refuses only a channel that
another owner holds, and calls `timerConfigure` on that channel's timer. Motors start before it, and it has no
check for them. When a motor runs on another channel of the same timer, `timerConfigure` sets the timer to
count at 1 MHz over 65,536 counts. The DShot driver never writes its prescaler again, so the motors on that
timer send bits at 1 MHz counts, far too slow for DShot. Without burst mode each motor update also writes the
DShot bit length to the period and clears the counter, so the PWM input reads wrong pulse widths as well.

## adaflight

A PWM input pin on a timer that a motor uses gets no input. Its channel reads no signal, as with no pin.

## Proposed change for Betaflight

Skip a PWM input pin whose timer a motor uses. One timer cannot count at the motors' rate and at 1 MHz.
