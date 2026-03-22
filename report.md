# EE3220 TBL2 Mission Clock Report

## System Architecture
Our system architecture extends the provided PicoRV32 processor skeleton with custom human-visible peripherals to display a Space-Z shuttle clock. The CPU relies on local Instruction Memory (`imem.sv`) initialized by the `clock.mem` firmware binary, and Data Memory (`dmem.sv`) for stack space. Two custom memory-mapped peripherals (UART and Timer) were developed and tied to the processor's main interconnect bus. Address decoding enables correct bus selection and ready handshakes dynamically.

## UART & Timer Interface
The timer acts as a periodic tick source. Based fundamentally on the `CLK_HZ` parameter, it resets itself and raises a one-second `tick_pending` flag precisely when a full second has passed. The processor polls this interrupt-free mechanism efficiently.
The UART exposes a `tx_ready` flag and a `TXDATA` register. The firmware loop blocks until `tx_ready=1`, inserts an ASCII byte into `TXDATA`, and relies on the autonomous 115200 baud UART state machine to manage bit transitions on the underlying `txd` pin.

## Firmware Strategy
The Bare-metal C logic was intentionally kept stripped of heavy standard libraries like `printf` to reduce footprint. Our firmware directly polls the Timer's `tick_pending` flag in an infinite loop. When asserted, it executes arithmetic carry operations across seconds, minutes, and hours to correctly simulate rollover. The runtime converts values to ASCII strings bounded by VT100 console reset commands (`\033[2J\033[H`) to maintain a clean Mission Console layout during string transmission over the serial port.
