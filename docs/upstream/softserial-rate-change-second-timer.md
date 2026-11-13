# Software serial rate change leaves its second timer at the old rate

Betaflight 2026.12 (master as of 2026-10-08). Finding F327, `DESIGN.md` D738 and D739. Not reported upstream.

## Betaflight

softSerialSetBaudRate calls serialTimerConfigureTimebase for a port's main timer. A port with two timers sends on its second timer's overflow, and softSerialOpen sets that timer's time base once. After a rate change such a port receives at its new rate and sends at its old one.

gpsSetBaudRate changes its port's rate while a GPS search steps through rates, and SmartAudio changes its port's rate while it tunes. Read from source. Not run on hardware.

## adaflight

A rate change sets each timer a port uses. Software serial vectors were recorded from a host build with that change.

## Proposed change for Betaflight

In softSerialSetBaudRate, call serialTimerConfigureTimebase for exTimerHardware too when a port runs in two-timer mode.
