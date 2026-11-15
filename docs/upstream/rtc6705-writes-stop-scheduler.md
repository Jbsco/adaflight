# RTC6705 software SPI writes and boot wait stop the scheduler

Betaflight 2026.12 (master as of 2026-10-08). Finding F351, `DESIGN.md` D757. Not reported upstream.

## Betaflight

rtc6705_write_register calls delay(1) after its select pin goes low and after each clock edge of 25 bits. A frequency is two register writes and a power is one. vtxRTC6705EnableAndConfigure calls delay() for 350 ms after power, then writes power and frequency. All of this runs in a VTX task of a cooperative scheduler, so no other task runs meanwhile.

Reproduced on a host build of that software SPI driver over stand-in pins: a power write spent 51 ms in delay(), a frequency 102 ms.

Read from source, not measured on a board: leaving pit mode with a power pin takes about 0.5 s while disarmed. vtxProcessPower is not limited to a disarmed craft, and with vtx_low_power_disarm a wanted power changes at arming. A software SPI RTC6705 then stops a flight loop for 51 ms right after arming.

## adaflight

A board unit keeps register writes, power changes and waits in a queue and runs those that are due at each VTX task call. A software SPI level lasts 10 microseconds, about 0.5 ms a write. Host smoke reads its VTX task's longest run after a start with a boot wait.

## Proposed change for Betaflight

Replace delay(1) in rtc6705_write_register with delayMicroseconds() of a few microseconds, and turn that boot wait into a state in vtxRTC6705Process that returns until 350 ms have passed.
