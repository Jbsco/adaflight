# MSP LED strip configuration can never take its profile byte

Betaflight 2026.12 (master as of 2026-10-25). Finding F192, `DESIGN.md` D211. Not reported upstream.

## Betaflight

The LED strip configuration message answers an error unless the request is exactly five bytes, a LED index and its packed configuration. The profile byte that API 1.41 added follows those five bytes and is read only when a byte remains, which the length check rules out, so the strip's profile cannot be set through this message and a six-byte request carrying it is rejected whole. Observed in the command line oracle: every six-byte request answered an error.

## adaflight

The message takes five bytes, or six with the strip's profile, which must lie within the ledstrip_profile setting's range. A profile past the range is an error that writes nothing, where the reference writes the byte as it is. The MSP LED vectors were recorded from a host build of Betaflight's MSP with the same length check.

## Proposed change for Betaflight

Accept a data size of five or six bytes in the length check and keep the profile read that follows.
