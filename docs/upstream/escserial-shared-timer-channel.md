# ESC serial without a separate send pin puts bit timer and capture on one timer channel

Betaflight 2026.12 (master as of 2026-10-08). Finding F331, `DESIGN.md` D740. Not reported upstream.

## Betaflight

openEscSerial uses a motor pin's timer for both directions when no ESCSERIAL_PIN is set. For BLHeli and Castle it calls serialTimerTxConfigBL, then serialTimerRxConfigBL, on that one channel. serialTimerTxConfigBL sets a bit period and registers onSerialTimerBL as that channel's edge callback. serialTimerRxConfigBL then resets that timer, sets its period to 0xFFFF and registers onSerialRxPinChangeBL as that channel's edge callback.

timerReset deinitializes a timer, and timerChannelConfigCallbacks keeps one edge callback per channel. After such an open nothing calls onSerialTimerBL, which alone calls processTxStateBL and processRxStateBL. A BLHeli or Castle port then neither sends nor completes a received byte. SimonK takes that path through escSerialTimerTxConfig and escSerialTimerRxConfig: it decodes edges and cannot send. KISS sets up its bit timer alone and is not affected.

A separate send pin on a motor pin's timer meets those two calls on one timer too. Read from source, with that call order logged on a host build. Not run on hardware.

## adaflight

A port whose bit timer is its capture's timer keeps its bit period as one time base for BLHeli and Castle, with a bit tick handler beside its edge handler, as adaflight's software serial port runs on one timer. SimonK needs a time base for each direction and is refused there. Not run on hardware. ESC serial vectors were recorded from a host build with that arrangement.

## Proposed change for Betaflight

On one timer, clock bits from its update interrupt at its bit period and keep capture on its channel, without a second reset or time base. Refuse SimonK without a second timer.
