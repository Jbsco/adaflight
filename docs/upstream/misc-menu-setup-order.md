# Misc profile menu sets up the PID controller before it stores its values

Betaflight 2026.12 (master as of 2026-10-25). Finding F216, `DESIGN.md` D247. Not reported upstream.

## Betaflight

On the way out of the profile's misc menu, the menu calls the PID controller's setup with the current profile and only then stores its copies into the profile the profile menu selected. The setup derives the controller's coefficients from the profile, so it takes the old values, and the edited angle, horizon, anti gravity, I term relax, feedforward and attenuation settings reach the controller only at its next setup, such as the next profile change or reboot. Read from the source. The menu oracle counts the setup requests, which both orders give alike.

## adaflight

The menu stores the copies and then requests the setup, and the caller runs the setup after the menu returns, so the controller takes the stored values. The menu content vectors record the stored profile and the request count after each key, which both orders give alike.

## Proposed change for Betaflight

Call the controller's setup after the stores, at the end of the misc menu's exit handler.
