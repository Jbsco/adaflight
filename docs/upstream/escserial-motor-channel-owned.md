# ESC passthrough is refused on a motor pin whose timer channel a motor output owns

Betaflight 2026.12 (master as of 2026-10-08). Finding F333, `DESIGN.md` D744. Not reported upstream.

## Betaflight

openEscSerial takes a motor pin's timer channel with timerAllocate as OWNER_MOTOR and returns NULL when it gets none. timerAllocate gives none for any channel that already has an owner. PWM, Oneshot, Multishot and timer DShot outputs take each motor pin's channel as OWNER_MOTOR at start. On such a build escprog and MSP ESC passthrough answer "Error starting ESC connection" for every motor. Bit-banged DShot takes no timer channel, so a first passthrough opens there. closeEscSerial frees no owner, so a second passthrough on that pin is refused until a restart.

Read from source. A timer allocation test built from Betaflight's timer_common.c refused every allocation of a channel by an owner that already had it. Not run on hardware.

## adaflight

An ESC serial link takes a channel that a motor output owns, or a free one in that owner's name. A second link on a pin opens without a restart. Host image runs open links on both kinds of channel.

## Proposed change for Betaflight

Let openEscSerial use a channel whose owner is OWNER_MOTOR, for example through a lookup that returns a pin's timer hardware when its owner matches.
