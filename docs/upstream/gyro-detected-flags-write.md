# Gyro initialization writes the configuration at every boot with a configured sensor missing

Betaflight 2026.12 (master as of 2026-10-25). Finding F236, `DESIGN.md` D294. Not reported upstream.

## Betaflight

Gyro initialization scans the stored detected flags, or every sensor when they are zero, together with the enabled setting and every sensor whose device has a bus configured. It stores the detected flags and asks for a configuration write whenever the scanned set differs from the stored flags. A sensor with a configured bus that is not detected stays in the scanned set at every boot but never enters the stored flags, so the two differ at every boot and the configuration is written each time. A target that configures a second gyro which a board variant leaves unpopulated writes its flash at every power-up. Observed in the gyro selection oracle: every second and third boot with a configured sensor missing wrote the configuration.

## adaflight

The selection writes the configuration when the detected set differs from the stored flags, so a boot that detects the stored set writes nothing. The gyro selection vectors were recorded from a host build of Betaflight's initialization with the same comparison.

## Proposed change for Betaflight

Compare the detected flags, not the scanned set, with the stored flags before storing them and requesting the write.
