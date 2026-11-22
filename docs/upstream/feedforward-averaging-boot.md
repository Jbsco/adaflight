# Feedforward averaging is off after every power-up

Betaflight 2026.12 (master as of 2026-10-08). Finding F370, `DESIGN.md` D871. Not reported upstream.

## Betaflight

activateConfig calls initRcProcessing before pidInit. initRcProcessing copies pidRuntime.feedforwardAveraging into rc.c's own averaging count and starts its moving averages only when that count is above zero. At power-up pidRuntime is still zero there, so feedforward runs without averaging whatever feedforward_averaging is set to, its default of 2_POINT included. pidInit sets pidRuntime.feedforwardAveraging next, but rc.c does not read it again.

Averaging comes on only when initRcProcessing runs again: a rate profile change, an MSP RC tuning write, or an MSP EEPROM write, which reloads the configuration without a restart. A command line save restarts the board and turns it off again. A craft tuned after a configurator save therefore flies its next battery with different feedforward.

Betaflight's SITL build at af0638839 was run in a closed loop with level flight dynamics at 100 Hz and stick frames at 50 Hz, P, I and D at zero on roll, and a roll step of 100 microseconds.

After power-up its blackbox feedforward on roll (axisF) rose to 12 in 20 ms and peaked at 21. After an MSP rate profile select it rose to 6 in 20 ms and held 17, as adaflight's host image does. With full PID gains, motor outputs through roll and yaw steps differed from that host image by up to 0.014 after power-up and by 0.002 at most after the select.

## adaflight

Feedforward averaging follows feedforward_averaging from power-up. Boards set up their PID settings first and start receiver processing from them.

## Proposed change for Betaflight

In activateConfig, call pidInit before initRcProcessing, or have initRcProcessing read feedforward_averaging from the PID profile.
