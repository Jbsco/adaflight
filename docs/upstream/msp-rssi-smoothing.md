# RSSI over MSP is replaced by smoothing of an unset raw RSSI

Betaflight 2026.12 (master as of 2026-10-08). Finding F321, `DESIGN.md` D686. Not reported upstream.

## Betaflight

MSP_SET_TX_INFO gives a flight controller an RSSI, and MSP becomes its RSSI source while no other source is set. That setter writes RSSI in use and leaves raw RSSI untouched, which stays at zero for this source. Every RSSI update then smooths: while RSSI in use differs from raw RSSI, it takes a low-pass filter's output for raw RSSI.

Updates run with receiver processing, so an RSSI over MSP reads its value only until an update follows, and then falls toward zero. Read from source and recorded from a host build of Betaflight's receiver; not reproduced on hardware. On an adaflight host image with that arithmetic and one message every 0.22 s, MSP_ANALOG gave 800 in 7 of 12 reads and 0 in 5.

## adaflight

An RSSI over MSP writes both RSSI in use and raw RSSI, so smoothing leaves it alone, and its 1.5 second timeout clears both. Receiver vectors were recorded from a host build of Betaflight's receiver with those two changes.

## Proposed change for Betaflight

In setRssiMsp, assign rssiRaw as well as rssi. In updateRSSI, clear rssiRaw with rssi when an MSP source times out.
