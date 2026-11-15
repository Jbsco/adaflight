# Joystick reports are transmitted from a plain serial USB device on F4 boards

Betaflight 2026.12 (master as of 2026-10-08). Finding F352, `DESIGN.md` D760. Not reported upstream.

## Betaflight

While disarmed, its receiver task calls sendRcDataToHid at each update, whatever `usb_hid_cdc` is set to. That setting is read only where arming asks whether a board may be in use as a joystick. On F4 boards sendReport calls USBD_HID_SendReport, which starts a transmit on endpoint 0x83 whenever its device is configured, whichever class is registered. A plain serial device, which is what `usb_hid_cdc = OFF` selects by default, has no endpoint 0x83 in its configuration and never opens one.

Reproduced on a host build of that device library with its serial class and its HID class over a stand-in controller. Every report from a configured serial device gave one transmit of 9 bytes to endpoint 0x83, and a report before configuration gave none. Not measured on a board, so what an F4 controller does with a transmit on an endpoint it never activated is unknown.

F7 boards are not affected. Their library's USBD_HID_SendReport reads a HID class pointer that a serial device leaves null, and sends nothing.

## adaflight

A joystick report goes out from a composite device alone.

## Proposed change for Betaflight

Call sendRcDataToHid from that task only when `usbDevConfig()->type` is COMPOSITE.
