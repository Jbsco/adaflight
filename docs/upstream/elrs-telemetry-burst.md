# ExpressLRS telemetry burst limit wraps at 1000 Hz with a 1:2 ratio

Betaflight 2026.12 (master as of 2026-10-08, unchanged on 2026-10-24). Finding F99, `DESIGN.md` D91. Not reported upstream.

## Betaflight

The ExpressLRS receiver sizes its telemetry burst, the data frames sent between two link statistics frames, as 512 ms times the packet rate over the telemetry denominator over 1000, into an 8-bit variable, then reserves one slot by subtracting one and floors the result at one. At 1000 Hz with a 1:2 ratio the quotient is 256, which wraps to zero, so the limit becomes one and link statistics and data frames alternate where 255 data frames were meant to follow each statistics frame. Every other rate and ratio in the table stays below 256. Reproduced with a host build of the receiver at that rate and ratio.

## adaflight

The quotient is computed in a wide count, the slot is reserved, and the limit is held at 255, the most an 8-bit count holds. The hold applies only to a 1000 Hz link without telemetry, where no telemetry frame uses the limit. The ExpressLRS receiver vectors were recorded from a host build of Betaflight's receiver with the same computation, with four sequences at 1000 Hz and a 1:2 ratio.

## Proposed change for Betaflight

In the burst update, compute the quotient in a `uint32_t`, reserve the slot on that value, and store the smaller of it and 255 in `telemetryBurstMax`.
