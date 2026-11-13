# Software serial with two timers clocks reception from its sending timer

Betaflight 2026.12 (master as of 2026-10-08). Finding F326, `DESIGN.md` D738 and D739. Not reported upstream.

## Betaflight

softSerialOpen gives a full duplex port a second timer when its send pin's timer is another timer than its receive pin's. In that mode it registers onSerialTimerOverflow on that second timer and only the edge handler on its main timer. onSerialTimerOverflow runs processTxState and processRxState, so both directions are clocked by that second timer.

onSerialRxPinChange sets the main timer's counter to half a period at a start edge. No handler runs on that timer's overflow in this mode, so nothing uses that alignment. Reception is sampled at whatever phase the second timer has when a start edge arrives.

Measured on a time model built from serial_softserial.c with exact edges and no interrupt latency, at 9600 baud with 256 byte values per run. A sender 2 percent slow and a first tick 2 percent of a bit after its start edge: 1 byte arrives as sent. At 10 percent of a bit 16 arrive, and from 25 percent up all 256. With equal rates every phase receives all 256. Not run on hardware.

## adaflight

A two-timer port runs reception on its main timer's overflow and sending on its second timer's. Software serial vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In two-timer mode, register an overflow handler on both timers: processRxState on the main timer, processTxState on the second.
