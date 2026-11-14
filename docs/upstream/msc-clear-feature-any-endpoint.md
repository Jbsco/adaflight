# Mass storage class reopens whatever endpoint a clear feature request names

Betaflight 2026.12 (master as of 2026-10-08). Finding F348, `DESIGN.md` D753. Not reported upstream.

## Betaflight

USBD_MSC_Setup handles a standard CLEAR_FEATURE request without a look at its recipient or its endpoint. It flushes, closes and reopens endpoint wIndex as a bulk endpoint, then runs its transport's halt handling for it. ST's device library hands it that request for a device request that clears remote wakeup, for any interface request and for an endpoint request on any endpoint but 0.

Reproduced on a host build of device library, class and transport over a stand-in controller. CLEAR_FEATURE to the interface with index 0 closed endpoint 0 and opened it again as a bulk endpoint, and so did a device request that clears remote wakeup. Clearing a halt on endpoint 0x82, which that class does not own, sent a status wrapper with a failed result and tag 0 on endpoint 0x81 with no command pending. What a controller does with a control endpoint reopened as bulk was not measured.

## adaflight

Its class takes a clear feature request only with an endpoint as recipient and only for its two endpoints. Vectors were recorded from a host build with that condition.

## Proposed change for Betaflight

In USBD_MSC_Setup's CLEAR_FEATURE case, return unless bmRequest names an endpoint as recipient and wIndex is MSC_IN_EP or MSC_OUT_EP.
