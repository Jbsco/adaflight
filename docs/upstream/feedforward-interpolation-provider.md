# Feedforward interpolation turns off for a CRSF setting with no serial receiver open

Betaflight 2026.12 (master as of 2026-10-08). Finding F369, `DESIGN.md` D870. Not reported upstream.

## Betaflight

The change that brought feedforward interpolation names CRSF protocol as the case to leave out. pidInit sets feedforwardInterpolate from rxRuntimeState.serialrxProvider, and rxInit copies that field from the serialrx_provider setting whatever receiver it opens. A build with CRSF support defaults that setting to CRSF. A board using a PPM, parallel PWM, SPI or MSP receiver keeps that default, so its feedforward runs without interpolation.

Without interpolation, a repeated frame after stick movement gives a setpoint speed of zero, and a frame after a repeat divides its change by one frame interval, not two. A host image built to read the setting showed this for a roll step of 100 microseconds with frames at 50 Hz. Feedforward debug setpoint speed read 14, 4, 1, 0 (units of 100 degrees per second squared) over the step's frames. With interpolation the same step read 7, 11, 3, 1, 0.

## adaflight

Feedforward interpolates unless an open serial receiver reads CRSF. A PPM, parallel PWM, SPI, MSP or simulator receiver interpolates whatever the serial receiver setting is.

## Proposed change for Betaflight

Set feedforwardInterpolate from the receiver in use: false only when rxRuntimeState.rxProvider is RX_PROVIDER_SERIAL and the serial provider is CRSF.
