# EE3220 TBL-2 — Mission Clock Report

## Overview
This project implements a bare-metal mission clock firmware on a small PicoRV32 processor subsystem. [cite_start]The base system uses UART TX for terminal output and a memory-mapped timer to signal one-second boundaries [cite: 339-342]. [cite_start]To fulfill the advanced requirements and earn extra credit, we extended the system with two optional features [cite: 364][cite_start]: a UART command interface to set the time via UART RX [cite: 366][cite_start], and a VT100/ANSI terminal UI featuring colored text, screen clearing, and a static mission console layout [cite: 375-384]. [cite_start]The design is verified in Vivado simulation (`tb_basic.sv`) and validated on the PYNQ-Z2 board using the `pynq_z2_tx_demo_top.sv` wrapper [cite: 415-420].

---

## Architecture
[cite_start]The processor fetches from instruction memory, initialized from the generated `clock.mem` file [cite: 236-237]. Data memory holds stack and writable data. [cite_start]The UART (TX and RX) and timer peripherals are integrated as memory-mapped devices on the simple MMIO bus [cite: 134-135].

[cite_start]Address windows are fixed: UART base address is `0x4000_0000`, and the Timer base address is `0x4000_0010`[cite: 277, 282]. Only transactions inside a window assert that slave’s `bus_valid`; `mem_ready` / `mem_rdata` multiplex IMEM, DMEM, UART, and Timer; unmapped accesses complete through an invalid path so the core does not hang.

---

## MMIO interface

| Region | Register | Address | Access | Function |
|--------|----------|---------|--------|----------|
| UART | TXDATA | `0x4000_0000` | WO | [cite_start]Start byte TX on UART line (low 8 bits) [cite: 283-284]. |
| UART | STATUS | `0x4000_0004` | RO | Bit 0: `tx_ready` (idle) [cite: 285-288]; Bit 1: `rx_valid` (new byte received). |
| UART | RXDATA | `0x4000_0008` | RO | Read received byte from UART line (hardware clears `rx_valid` on read). |
| Timer | STATUS | `0x4000_0010` | RW | [cite_start]Bit 0: `tick_pending`; write 1 to clear (W1C) [cite: 290-293]. |
| Timer | VALUE | `0x4000_0014` | RO | [cite_start]Free-running cycle counter (optional debug) [cite: 294-296]. |

[cite_start]Firmware uses `volatile uint32_t` pointers at these defined address offsets [cite: 302-320] to poll hardware status and trigger actions.

---

## UART design (RTL)
[cite_start]The UART module is configured for 115,200 baud, 8 data bits, no parity, and 1 stop bit [cite: 358-362]. 
* **TX Path:** A fixed-baud bit serializer. A write to TXDATA completes on the bus only when `tx_ready` is high; if the transmitter is busy, the bus stalls.
* **RX Path (Bonus Extension):** A synchronized deserializer that detects the start bit, samples 8 data bits, and asserts `rx_valid` upon receiving the stop bit. Reading the RXDATA MMIO register automatically clears the `rx_valid` flag, ensuring seamless firmware polling.

---

## TIMER design (RTL)
The timer maintains a cycle counter matching the `CLK_HZ` parameter (62.5 MHz). [cite_start]When the counter reaches the 1-second threshold, `tick_pending` is set[cite: 343]. Software clears it with a W1C write to STATUS at `0x4000_0010` [cite: 300-301]. 

---

## Firmware strategy & Bonus Features
* **Polling Loop:** The main loop waits on `TIMER_STATUS[0]`. Within this loop, it simultaneously polls `UART_STATUS[1]` to check for incoming keyboard commands without blocking the 1-second timer.
* **Time Setting (Bonus):** If a character is received, the firmware parses it. [cite_start]Pressing 'h', 'm', or 's' directly increments the hours, minutes, or seconds, respectively, handling local rollover logic immediately[cite: 366].
* [cite_start]**VT100/ANSI UI (Bonus):** The system implements advanced terminal controls[cite: 376]. [cite_start]Upon boot, it issues `\033[2J\033[H` to clear the screen and draw a green "Open-Source Space Shuttle Console" static border[cite: 378, 381]. [cite_start]The clock itself is printed in cyan (`\033[1;36m`) [cite: 379] at a fixed absolute cursor position (`\033[5;1H`), updating in-place to prevent screen scrolling. [cite_start]The colon blinks every second to indicate active running status[cite: 380].
* [cite_start]**Rollover logic:** `seconds`, `minutes`, `hours` updates use integer compares to 60 and 24 to guarantee accurate `23:59:59` to `00:00:00` transitions[cite: 349].

---

## Simulation / validation
[cite_start]`tb_basic.sv` instantiates `picorv32_soc_ref` with reduced timer divisions so a minute of mission time completes quickly[cite: 395]. [cite_start]The simulation verifies the initial `00:00:00` output, subsequent second increments, and correct minute/hour rollover events [cite: 388-394]. Failure triggers `$fatal`; success prints PASS.

---

## FPGA bring-up (PYNQ-Z2)
Synthesis top is `pynq_z2_tx_demo_top.sv`, which generates a 62.5 MHz SoC clock from the board's 125 MHz clock via a PLL and releases reset synchronously. `picorv32_soc_ref` is parameterized for a 115,200 baud rate at that SoC frequency. Constraints are mapped in `pynq_z2_tx_demo.xdc`, driving UART TX to PMODB pin W19 and RX to W18. A USB–UART external dongle is wired GND–GND, FPGA TX → dongle RX, FPGA RX → dongle TX, enabling bidirectional communication with the host terminal.

---

## Division of labor
* **Architecture & SoC integration:** Defined the MMIO memory map, integrated the UART RX path, and wired peripherals to the RISC-V `picorv32_soc_ref` system.
* **RTL:** Implemented hardware for `uart.sv` (TX+RX), `timer.sv`, and adjusted top-level parameters.
* **Firmware & verification:** Wrote `clock.c` with VT100 UI and time-setting logic, managed the build flow, and verified behavior in `tb_basic.sv`.
* [cite_start]**Documentation:** Prepared `README.md`, `report.pdf` (this document), and maintained the required `ai_log.txt` [cite: 446-448].
