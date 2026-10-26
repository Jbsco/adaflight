# 2SMPB-02B takes its coefficients from unchecked reads of an uninitialized buffer

Betaflight 2026.12 (master as of 2026-10-25). Finding F275, `DESIGN.md` D357. Not reported upstream.

## Betaflight

The 2SMPB-02B driver's signed register read fills a stack buffer it does not initialize and does not check the read's answer. The nine coefficient reads of the configuration go through it, the configuration ignores the IIR filter write's answer too, and it always returns true, so detection succeeds whatever the bus did after the identity read, and the detection's own check of the configuration result never fires. A refused read leaves whatever the stack held as a coefficient, as the BMP085 does with its calibration. Read from the source. The 2SMPB-02B oracle answered every coefficient read until this change.

## adaflight

The configuration reports a refused coefficient read or IIR write, and the detection then fails as it does for a missing identity, returning an SPI chip's select pin to the preinit state. The 2SMPB-02B vectors were recorded from a host build of Betaflight's driver with the same checks, with one coefficient read refused in a drawn share of the cases.

## Proposed change for Betaflight

Return false from the configuration when a coefficient read or the IIR write fails. The detection already takes its failure path on a false configuration.
