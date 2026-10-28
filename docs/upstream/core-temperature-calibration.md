# Core temperature calibration overrides a few counts apart

Betaflight 2026.12 (master as of 2026-10-27). Findings F96 and F303, `DESIGN.md` D75 and D477. Not reported upstream.

## Betaflight

On the STM32F4 the core temperature slope is eighty degrees, in thousandths, over the difference of the
temperature sensor's two calibration readings. The readings come from the chip, or from the
`adc_tempsensor_calibration30` and `adc_tempsensor_calibration110` settings when those are set. Nothing checks
the settings against each other.

Equal settings divide by zero. The STM32F4's core gives a quotient of zero there, so the temperature stays at 30
degrees, and a host build stops on the division. Settings a few counts apart give a slope in the tens of
thousands, so the temperature moves by tens of degrees for each count of the sensor reading. With settings one
count apart, the 32-bit signed product of the slope and the reading less the 30 degree point leaves the signed
range once the measured supply passes about 21 V, which a failing reference channel can report.

The sensor's datasheet slope of 2.5 mV per degree puts the chip's two readings about 250 counts apart, a slope
near 320.

## adaflight

The slope holds to ten thousand, the bound the internal ADC unit takes so its products stay in 32 bits.
Settings fewer than eight counts apart read a temperature closer to 30 degrees than Betaflight's. Equal settings
give a slope of zero, the processor's quotient.

## Proposed change for Betaflight

Ignore an override pair fewer than eight counts apart and keep the chip's readings.
