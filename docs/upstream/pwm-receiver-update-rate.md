# Parallel PWM receiver's channels update only at signal loss

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-18). Finding F367, `DESIGN.md` D812. Not
reported upstream.

## Betaflight

`rxFrameCheck` marks a parallel PWM receiver's signal as received without data driven processing, and it asks for
channel processing only for data driven sources while a signal lasts. Nothing else asks for it then, so
`calculateRxChannelsAndUpdateFailsafe` runs for this receiver only after a signal loss, and its channels never
follow the sticks. A 2022 change to failsafe timing removed the 15 Hz update that served this receiver: the
`rxNextUpdateAtUs` deadline in the processing condition and its reset in the channel calculation.

## adaflight

A receiver without data driven processing gets its channels processed once its 15 Hz deadline passes while its
signal lasts, and each channel calculation sets the next deadline 66,666 microseconds on. Data driven receivers
are unchanged.

## Proposed change for Betaflight

Restore the deadline for receivers without data driven processing: ask for processing when
`cmpTimeUs(currentTimeUs, rxNextUpdateAtUs) > 0` beside `useDataDrivenProcessing`, and set `rxNextUpdateAtUs` to
`currentTimeUs + DELAY_15_HZ` where the channel calculation clears its request.
