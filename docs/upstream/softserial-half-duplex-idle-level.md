# Half duplex software serial sends its first frame from a pin without an idle level

Betaflight 2026.12 (master as of 2026-10-08). Finding F329, `DESIGN.md` D739. Not reported upstream.

## Betaflight

softSerialOpen calls serialOutputPortActivate and setTxSignal with IDLE for a port without SERIAL_BIDIR. A half duplex port gets neither call: its pin starts as an input. processTxState switches that pin to an output when a first byte waits, returns, and writes a start bit one bit period later. Its comment says that pin is in IDLE state during that period.

No code has written that pin's level before a first transmission, so its output register still has its reset value, low. On a line that idles high, that first switch to output drives low one bit period before a start bit. A receiver then sees a start edge one bit early and misreads a first byte. Later frames start from a stop bit's level and are not affected. Read from source, with a GPIO output register's reset value from STM32 reference manuals. Not run on hardware.

## adaflight

Opening a half duplex software serial port writes its idle level to its send pin's output register while that pin is still an input.

## Proposed change for Betaflight

In softSerialOpen, call setTxSignal with IDLE for a half duplex port too, without activating its output.
