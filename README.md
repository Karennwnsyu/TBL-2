# Open-Source Space Shuttle Mission Clock

## Build Steps and Simulation Commands

### Firmware Build
1. Use a RISC-V bare-metal toolchain (`riscv32-unknown-elf-gcc` or `riscv64-unknown-elf-gcc` recommended; or clang with RISC-V target support).
2. From the `firmware/` directory, run `make`. This produces `clock.mem` at the **project root** (parent of `firmware/`) via `bin2mem.py`.
   ```bash
   cd firmware/
   make
   ```
3. If linking fails: on some hosts, add `-fuse-ld=lld` to `LDFLAGS` in `Makefile` when using clang+lld; GNU `gcc` normally does not need it.

### Hardware Simulation
1. Build firmware first so `clock.mem` exists at the project root.
2. In Vivado, set the **simulation run directory** to that same project root so `$readmemh("clock.mem", …)` in `imem` and the `tb_basic` parameter resolve correctly.
3. Add simulation sources: `rtl/tb_basic.sv`, **all** `rtl/*.sv`, and **`rtl/picorv32.v`** (CPU core is Verilog, not SystemVerilog).
4. Set `tb_basic` as the top module.
5. Run `xsim`. The testbench overrides fast clock/timer parameters so wall-clock “1 s” ticks complete quickly; watch the UART monitor output in the Tcl/console.

### FPGA (PYNQ-Z2 demo)
- Synthesis top: `rtl/pynq_z2_tx_demo_top.sv`.
- Constraints: `constraints/pynq_z2_tx_demo.xdc` (adjust if your handout uses different pins).
- After bitstream programming, open a serial terminal at **115200 8N1** on the UART pins wired in the XDC.

## MMIO Memory Map and Register Semantics

The PicoRV32 SoC decodes UART and Timer in `picorv32_soc_ref.sv`; only accesses inside each peripheral’s address window are driven onto that slave (`bus_valid` gating).

### UART Peripheral (Base: 0x4000_0000)
- **0x4000_0000 [TXDATA] (Write-Only)**  
  - Writes to the lower 8 bits start transmission on `uart_txd`. If the UART is busy, the bus **stalls** until `tx_ready` is 1, then completes the write in the same handshake style as the firmware poll.
- **0x4000_0004 [STATUS] (Read-Only)**  
  - Bit [0]: `tx_ready` — `1` = idle, ready for a new byte; `0` = transmitting.

### Timer Peripheral (Base: 0x4000_0010)
- **0x4000_0010 [STATUS] (Read/Write)**  
  - Bit [0]: `tick_pending` — `1` after one timer period. Write `1` to clear (W1C).
- **0x4000_0014 [VALUE] (Read-Only)**  
  - Current free-running counter value.

## Division of Labor
- **Team Leader**: Coordinated integration and planned MMIO map.
- **SoC & Peripheral Engineers**: `timer.sv`, `uart.sv`, and `picorv32_soc_ref.sv` interconnect (address windows, `mem_ready`/`mem_rdata` mux).
- **Firmware & Verification Engineers**: `clock.c`, `tb_basic.sv`, and firmware build flow.
- **AI Engine**: Pair-programmed bring-up and timing-oriented edits.
