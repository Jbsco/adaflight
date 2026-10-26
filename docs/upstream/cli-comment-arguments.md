# A command followed directly by a comment takes the comment as its arguments

Betaflight 2026.12 (master as of 2026-10-26). Finding F153, `DESIGN.md` D168 and D169. Not reported upstream.

## Betaflight

The line processor cuts a comment by moving the line's end to the number sign and writing a terminator there, which leaves the comment's text in the buffer behind the terminator. The command matcher returns the arguments as the text one past the command word's terminator, so a command word that ends at the cut reads the comment as its arguments. `get#motor_pwm_rate` prints the `motor_pwm_rate` setting where `get` alone prints every setting, `get #motor_pwm_rate` searches for `#motor_pwm_rate` and reports an invalid name, and `dump profile#defaults` dumps with defaults. The buffer is cleared only after the command has run. Observed in the command line oracle.

## adaflight

The line processor clears the buffer behind the comment cut, so a command word that ends at the cut has no arguments. `get#motor_pwm_rate` and `get #motor_pwm_rate` print every setting, and `dump profile#defaults` dumps without defaults. The command line vectors with a comment after a command word, glued or after a space, were recorded from a host build of Betaflight's command line with the same clearing.

## Proposed change for Betaflight

Clear the buffer from the comment's number sign to its end when the comment is cut, before the command matcher runs.
