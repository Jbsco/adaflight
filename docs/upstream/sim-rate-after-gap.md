# Simulator rate after a packet gap comes from a stale time

Betaflight 2026.12 (master as of 2026-10-08). Finding F324, `DESIGN.md` D717. Not reported upstream.

## Betaflight

SITL's updateState measures its simulator rate as a packet's timestamp step over monotonic time since its last packet, which it keeps in last_ts. A packet more than 500 ms after that one takes a timeout branch that resets last_timestamp and last_realtime and returns. That branch leaves last_ts as it was. Only its normal path sets it.

A first packet after a gap takes that branch. A second one then divides one packet interval by that whole gap. At a first start last_ts is still zero, so it divides by its monotonic clock's value. Either way simRate is near zero until a third packet arrives. micros64 scales by simRate, and delayMicroseconds sleeps its time divided by simRate, so a delay asked for in that window lasts for hours.

Read from source; not reproduced on Betaflight.

## adaflight

Its timeout path sets that last packet's time too, so a second packet's rate is measured over its own interval. Before this change a host image fed exactly two packets stopped answering MSP: its clock had stopped, and a scheduler wait caught by that stop never returned. Simulator vectors were recorded from a host build of updateState with that assignment added.

## Proposed change for Betaflight

In updateState's timeout branch, also assign now_ts to last_ts.
