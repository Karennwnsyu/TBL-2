# EE3220 TBL2 Mission Clock Report

## System Architecture
The design extends the PicoRV32 skeleton with a mission clock on the UART. The CPU uses instruction memory (`imem.sv`) loaded from `clock.mem` and data memory (`dmem.sv`) for stack and `.data`/`.bss`. UART and Timer are slaves on the main bus. In `picorv32_soc_ref.sv`, fixed windows (`0x4000_0000`–`0x4000_000F` for UART, `0x4000_0010`–`0x4000_001F` for Timer) gate `bus_valid` so peripherals do not respond to IMEM/DMEM traffic. `mem_ready` and `mem_rdata` multiplex IMEM, DMEM, UART, and Timer; unmapped addresses complete with `invalid_ready` so the CPU does not hang.

## UART & Timer Interface
The timer divides `CLK_HZ` by `DEFAULT_PERIOD_CYCLES` (typically equal to `CLK_HZ` for a one-second tick on the SoC clock). When the counter wraps, `tick_pending` is set; software clears it with a W1C write to STATUS. Register addresses are decoded with a `BASE_ADDR` parameter (`0x4000_0010`) so STATUS and VALUE match `0x4000_0010` and `0x4000_0014`.

The UART runs a fixed baud from `CLK_HZ` and `BAUD`. STATUS exposes `tx_ready`. A write to TXDATA is accepted by the bus only when `tx_ready` is high; otherwise the transfer stalls until the transmitter is idle, consistent with firmware that polls STATUS before writing.

## Firmware Strategy
Firmware avoids `printf` and other heavy library use. Integer **division and modulo are not used** for digit formatting, so linking stays within a bare-metal `-nostdlib` flow without compiler helper routines such as `__divsi3`. Two-digit fields use subtract-in-a-loop formatting. The main loop polls `tick_pending`, updates hours/minutes/seconds with rollover, and prints a fixed `MISSION CLOCK HH:MM:SS` line. An optional VT100 clear/home sequence is sent once at startup for a stable console layout.
