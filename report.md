# EE3220 TBL-2 — Mission Clock Report

## Overview

This project implements a **bare-metal mission clock** on a small **PicoRV32** SoC: **UART TX** is used for terminal output, and a **memory-mapped timer** signals **one-second** boundaries via a **pending flag**. Firmware **polls** the timer and UART status registers (**no interrupts**). The clock is displayed as **hh:mm:ss** with **24-hour rollover**. The same RTL is exercised in **Vivado simulation** (`tb_basic`) and brought up on **PYNQ-Z2** using **`pynq_z2_tx_demo_top`**.

---

## Architecture

The processor fetches from **instruction memory** (`imem.sv`), initialized from **`clock.mem`**. **Data memory** (`dmem.sv`) holds stack and writable data. **UART** and **Timer** sit on the processor bus as MMIO slaves inside **`picorv32_soc_ref.sv`**.

Address **windows** are fixed: **UART** `0x4000_0000`–`0x4000_000F`, **Timer** `0x4000_0010`–`0x4000_001F`. Only transactions inside a window assert that slave’s **`bus_valid`**; **`mem_ready`** / **`mem_rdata`** multiplex **IMEM, DMEM, UART, and Timer**; unmapped accesses complete through an **invalid** path so the core does not hang.

---

## MMIO interface

| Region | Register | Address | Access | Function |
|--------|----------|---------|--------|----------|
| UART | TXDATA | `0x4000_0000` | WO | Start byte TX on UART line (low 8 bits). |
| UART | STATUS | `0x4000_0004` | RO | Bit 0: **`tx_ready`** (idle). |
| Timer | STATUS | `0x4000_0010` | RW | Bit 0: **`tick_pending`**; write **1** to clear (**W1C**). |
| Timer | VALUE | `0x4000_0014` | RO | Free-running counter (read-only observation). |

Firmware uses **`volatile` uint32_t** pointers at these offsets; there is **no UART RX command parsing** in software.

---

## UART design (RTL)

The UART TX path is a **fixed-baud** bit serializer ( **`CLK_HZ`** / **`BAUD`** ). **STATUS** reads return **`tx_ready`**. A **write to TXDATA** completes on the bus only when **`tx_ready`** is high; if the transmitter is busy, the bus **stalls** until the byte can be accepted—consistent with firmware that **polls STATUS before each character**.

---

## TIMER design (RTL)

The timer maintains a **cycle counter** versus **`DEFAULT_PERIOD_CYCLES`**. In the FPGA SoC, parameters are chosen so that one wrap corresponds to **one second** on the **SoC clock**. On wrap, **`tick_pending`** is set. Software clears it with a **W1C** write to **STATUS** at **`0x4000_0010`**. **VALUE** exposes the counter for debug. Register decode uses a **`BASE_ADDR`** parameter so **STATUS** and **VALUE** match **`0x4000_0010`** and **`0x4000_0014`**.

---

## Firmware strategy

- **Polling:** The main loop waits on **`TIMER_STATUS[0]`**; when set, it writes **W1C** and advances **hours / minutes / seconds** with explicit **rollover** (`60` / `60` / `24`).
- **UART output:** Characters are sent with **`uart_putc`**, which spins on **`UART_STATUS[0]`** (`tx_ready`) before each write to **TXDATA**.
- **No stdio:** No **`printf`**, no heap, no dynamic allocation.
- **Digit formatting:** Two-digit ASCII **does not use division or modulo**. The code uses **precomputed packed strings** of two-character pairs **`HOUR_PAIR`** (hours **0–23**) and **`MS_PAIR`** (minutes/seconds **0–59**). Indices use **`unsigned << 1`** and **`+ 1`** to select the two ASCII bytes—**no `__divsi3` / `__mulsi3`**-style helpers from formatting.
- **Rollover logic:** `seconds`, `minutes`, `hours` updates use **integer compares** to `60` and `24` only (no divide/mod for display).

---

## Simulation / validation

**`tb_basic.sv`** instantiates **`picorv32_soc_ref`** with **accelerated** **`CLK_HZ`**, **`TIMER_TICK_CYCLES`**, and a matching **`UART_BAUD`** so a **minute** of mission time completes in **short wall-clock simulation time**. A testbench **UART receiver** decodes **`uart_txd`** into bytes, accumulates a log string, and **self-checks** that the stream contains **`MISSION CLOCK`**, **`00:00:00`**, and **`00:01:00`** (minute rollover). Failure **`$fatal`**; success prints **PASS** and **`$finish`**.

---

## FPGA bring-up (PYNQ-Z2)

Synthesis top is **`pynq_z2_tx_demo_top`**, which generates a **SoC clock** from the board **125 MHz** clock via **PLL/MMCM** and releases **reset** in a synchronized way. **`picorv32_soc_ref`** is parameterized for **115200** baud at that SoC frequency. Constraints are in **`constraints/pynq_z2_tx_demo.xdc`** (e.g. **PMODB** UART pins **W19** / **W18**). After **bitstream** programming, a **USB–UART** adapter is wired **GND–GND**, **FPGA TX → dongle RX**, **FPGA RX → dongle TX**, and a host terminal is set to **115200 8N1**.

---

## Bonus terminal UI

The firmware uses **ANSI escape sequences** for a compact TUI: **full-screen clear once**, a **green** title line (**“RISC-V MISSION CLOCK”**), **cyan** time on a **fixed row** with **cursor positioning** and **line-to-end clear** (`EL`) for **in-place** updates, a **yellow** **STATUS: RUNNING** line, and a **`|/-\` spinner** indexed by **`seconds & 3`** (bitwise, not modulo). This is **optional visually**; core clock behavior does not depend on ANSI support.

---

## Division of labor

- **Architecture & SoC integration** — MMIO map, **`picorv32_soc_ref`** interconnect, peripherals  
- **RTL** — **`uart.sv`**, **`timer.sv`**, FPGA top  
- **Firmware & verification** — **`clock.c`**, **`tb_basic`**, build flow  
- **Documentation** — README, report, AI log per course policy  
