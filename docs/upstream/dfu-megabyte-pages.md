# DFU flasher reads megabyte pages as kilobytes

Betaflight configurator (master as of 2026-11-05). Finding F319, `DESIGN.md` D670. Not reported upstream.

## Betaflight

A DFU memory layout string gives each group of pages as a count and a size, with a unit letter before the page's attribute letter: none for bytes, K for kilobytes, M for megabytes. The configurator's flasher multiplies a size in M units by 1024, as for K. A device whose layout counts pages in megabytes appears 1024 times smaller, and an image that fits its flash fails the size check.

## adaflight

A page size in M units counts megabytes, as dfu-util reads it. The flasher checks parse a layout of two 1 MB pages.

## Proposed change for Betaflight

Multiply a size in M units by 1024 twice.
