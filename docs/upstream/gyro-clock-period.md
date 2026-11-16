# Gyro clock input runs one count short

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-11-16). Finding F360, `DESIGN.md` D784. Not reported upstream.

## Betaflight

`gyroClkInInit` divides its timer's clock by 32000 for a period. It then calls `pwmOutputConfig` with that period less one, and a compare value of half that period less one. `pwmOutputConfig` sets its time base through `timerReconfigureTimeBase`, which writes its period argument less one to a timer's reload register. That register gets a period less two, so its timer counts one tick fewer than 32 kHz needs. An 84 MHz timer divides by 2624 and gives 32012.2 Hz. Motor and servo outputs pass a whole period to that call.

By its datasheet an ICM-42688-P derives its output data rate from that clock, so an 8 kHz rate would become 8003 Hz. This was read from source and not measured.

## adaflight

Boards pass a whole period. An 84 MHz timer divides by 2625 for 32000 Hz, with a compare value of half that period.

## Proposed change for Betaflight

Pass `period16` and `value16` to `pwmOutputConfig`, and write `value16` with `pwmWriteChannel`.
