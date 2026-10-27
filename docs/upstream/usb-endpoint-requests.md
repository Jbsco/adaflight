# USB endpoint requests index past the endpoints

Betaflight 2026.12 (master as of 2026-10-26). Findings F289 and F293, `DESIGN.md` D408. Not reported upstream.

## Betaflight

The USB device library of the F4 targets takes the endpoint of SET_FEATURE, CLEAR_FEATURE and GET_STATUS
from the request's index without a check. A halt request stalls that endpoint, a clear request clears it and
a status request reads its halt flag, and each indexes the endpoint arrays and then the controller's register
blocks with the number. The full-speed controller has four endpoints, and only their register blocks are set
up. A request for endpoint 127 writes past the arrays, and a request for endpoints 4 to 14 dereferences a
null register pointer. Any USB host can send such a request.

A request error stalls both directions of the control endpoint and sets their halt flags. The controller ends
that stall at the next setup packet, but the flags stay set, so a later status request for the control
endpoint reports it halted.

## adaflight

A halt, clear or status request that names an endpoint the controller lacks is a request error. The control
endpoint's halt flags clear at every setup packet. The vectors were recorded from a host build of the library
with both changes.

## Proposed change for Betaflight

Answer a request error when the endpoint number is not below the controller's endpoint count, as the later
HAL library does, and clear the control endpoint's halt flags when a setup packet is parsed.
