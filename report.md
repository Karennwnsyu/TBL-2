# EE3220 TBL-2 — Mission Clock Report

## Overview
This project implements a bare-metal mission clock firmware on a small PicoRV32 processor subsystem: UART TX is used for terminal output, and a memory-mapped timer signals one-second boundaries via a pending flag. Firmware polls the timer and UART status registers. The clock is displayed as hh:mm:ss with correct rollover. The same RTL is exercised in Vivado simulation using `tb_basic.sv` and brought up on the PYNQ-Z2 board using the top-level wrapper `pynq_z2_tx_demo_top.sv`.

---

## Architecture
The processor fetches from instruction memory, initialized from the generated `clock.mem` file. Data memory holds stack and writable data. The UART and timer peripherals are integrated as memory-mapped devices on the simple MMIO bus.

Address windows are fixed: UART base address is `0x4000_0000`, and the Timer base address is `0x4000_0010`. Only transactions inside a window assert that slave’s `bus_valid`; `mem_ready` / `mem_rdata` multiplex IMEM, DMEM, UART, and Timer; unmapped accesses complete through an invalid path so the core does not hang.

---

## MMIO interface

| Region | Register | Address | Access | Function |
|--------|----------|---------|--------|----------|
| UART | TXDATA | `0x4000_0000` | WO | Start byte TX on UART line (low 8 bits). |
| UART | STATUS | `0x4000_0004` | RO | Bit 0: `tx_ready` (idle). |
| Timer | STATUS | `0x4000_0010` | RW | Bit 0: `tick_pending`; write 1 to clear (W1C). |
| Timer | VALUE | `0x4000_0014` | RO | Free-running counter / current counter value. |

Firmware uses `volatile uint32_t` pointers at these defined address offsets; there is no UART RX command parsing in software.

---

## UART design (RTL)
The UART TX path is a fixed-baud bit serializer set to 115,200 baud. STATUS reads return the `tx_ready` bit. A write to TXDATA completes on the bus only when `tx_ready` is high; if the transmitter is busy, the bus stalls until the byte can be accepted—consistent with firmware that polls `UART_STATUS[0]` before each character transmission.

---

## TIMER design (RTL)
The timer maintains a cycle counter versus `DEFAULT_PERIOD_CYCLES`. In the FPGA SoC, parameters are chosen so that one wrap corresponds to exactly one second on the SoC clock. On wrap, `tick_pending` is set. Software clears it with a W1C write to STATUS at `0x4000_0010`. VALUE exposes the counter for debug observations. Register decode uses a BASE_ADDR parameter so STATUS and VALUE match `0x4000_0010` and `0x4000_0014`.

---

## Firmware strategy
* **Polling:** The main loop waits on `TIMER_STATUS[0]`; when set, it writes W1C and advances hours / minutes / seconds with explicit second, minute, and hour rollover.
* **UART output:** Characters are sent with `uart_putc`, which spins on `UART_STATUS[0]` (`tx_ready`) before each write to TXDATA.
* **No stdio:** No `printf`, no heap, no dynamic allocation.
* **Digit formatting:** Two-digit ASCII does not use division or modulo. The code uses precomputed packed strings of two-character pairs `HOUR_PAIR` (hours 0–23) and `MS_PAIR` (minutes/seconds 0–59). Indices use `unsigned << 1` and `+ 1` to select the two ASCII bytes—no `__divsi3` / `__mulsi3`-style helpers from formatting.
* **Rollover logic:** `seconds`, `minutes`, `hours` updates use integer compares to 60 and 24 only for correct rollover logic.

---

## Simulation / validation
`tb_basic.sv` instantiates `picorv32_soc_ref` with reduced timer and UART divisors so a minute of mission time completes in short wall-clock simulation time. A testbench UART receiver decodes `uart_txd` into bytes, accumulates a log string, and self-checks that the stream contains `MISSION CLOCK`, `00:00:00` at reset, and `00:01:00` for minute rollover validation. Failure triggers `$fatal`; success prints PASS and `$finish`.

---

## FPGA bring-up (PYNQ-Z2)
Synthesis top is `pynq_z2_tx_demo_top.sv`, which generates a 62.5 MHz SoC clock from the board's 125 MHz clock via a 7-series-compatible PLL and releases reset in a synchronized way. `picorv32_soc_ref` is parameterized for a 115,200 baud rate at that SoC frequency. Constraints are mapped in `pynq_z2_tx_demo.xdc`, driving UART TX to PMODB pin W19 and RX to W18. After bitstream programming, a USB–UART external dongle is wired GND–GND, FPGA TX → dongle RX, FPGA RX → dongle TX, and a host terminal is configured to 115200 baud, 8 data bits, no parity, 1 stop bit.

---

## Bonus terminal UI
The firmware uses VT100/ANSI escape sequences for a compact TUI: full-screen clear once on boot, a green title line ("RISC-V MISSION CLOCK") with colored text, cyan time on a fixed row with cursor movement and line-to-end clear (`EL`) for in-place updates, a yellow STATUS: RUNNING line, and a `|/-\` spinner indexed by `seconds & 3` (bitwise, not modulo). This is an optional bonus feature; core clock behavior does not depend on ANSI support.

---

## Division of labor
* **Architecture & SoC integration:** Defined the MMIO memory map, integrated peripherals into the provided RISC-V `picorv32_soc_ref` system.
* **RTL:** Implemented hardware for `uart.sv`, `timer.sv`, and top-level integration.
* **Firmware & verification:** Wrote `clock.c`, managed the build flow, and verified behavior in `tb_basic.sv`.
* **Documentation:** Prepared `README.md`, `report.pdf`, and maintained the `ai_log.txt`.
