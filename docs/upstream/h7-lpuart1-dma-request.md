# LPUART1 DMA options on STM32H7 select another peripheral's request

Betaflight 2026.12 (master as of 2026-10-08). Finding F373, `DESIGN.md` D926. Not reported upstream.

## Betaflight

On STM32H7 a DMA option names one of the 16 streams of DMA1 and DMA2, and the option lookup puts the device's
request number into that stream's DMAMUX1 channel. The H7 request map lists LPUART1's transmit and receive sides
with their DMAMUX2 request numbers, 10 and 9, since LPUART1 sits on the BDMA. DMAMUX1 reads 10 as ADC2's request and
9 as ADC1's.

The UART hardware table gives LPUART1 no DMA stream, but a LPUART_TX or LPUART_RX option set from the command line
replaces that with an option's stream, so that stream then follows an ADC instead of the UART. Read from the source.

## adaflight

H7 builds give LPUART1 no DMA options. Its table generator leaves LPUART1's entries out of the H743 request map.

## Proposed change for Betaflight

Leave LPUART1 out of the H7 peripheral request map until BDMA streams are supported, or map its options to BDMA
channels.
