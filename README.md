# Open-Source Space Shuttle Mission Clock

## Build Steps and Simulation Commands

### Firmware Build
1. Navigate to the `firmware/` directory.
2. Run `make` to compile the C code, which automatically generates `clock.mem` at the project root using the provided `bin2mem.py` script.
   ```bash
   cd firmware/
   make
   ```

### Hardware Simulation
1. Ensure the generated `clock.mem` is accessible to the RTL simulator.
2. Open Vivado, create a project, and add `tb_basic.sv` and all `rtl/*.sv` files.
3. Set `tb_basic` as the top simulation module.
4. Run `xsim` (Vivado Simulator). The testbench uses overridden fast-clock parameters to make the simulation print 1Hz ticks extremely fast.
5. In the Tcl console, watch the output format carefully.

## MMIO Memory Map and Register Semantics

The PicoRV32 SoC maps peripherals directly to the system bus.

### UART Peripheral (Base: 0x4000_0000)
- **0x4000_0000 [TXDATA] (Write-Only)**
  - Writes to the lower 8-bits initiate a transmission over `uart_txd`. The UART busy sets immediately.
- **0x4000_0004 [STATUS] (Read-Only)**
  - Bit [0]: `tx_ready` - `1` means idle and ready to accept new characters; `0` means currently transmitting.

### Timer Peripheral (Base: 0x4000_0010)
- **0x4000_0010 [STATUS] (Read/Write)**
  - Bit [0]: `tick_pending` - `1` means a 1-second period has elapsed. Writing a `1` to this bit clears it (W1C semantic).
- **0x4000_0014 [VALUE] (Read-Only)**
  - The dynamic current value of the underlying fast counter.

## Division of Labor
- **Team Leader**: Coordinated integration and planned MMIO map.
- **SoC & Peripheral Engineers**: Engineered `timer.sv` and `uart.sv` RTL logic; modified `picorv32_soc_ref.sv` wrapper for correct Memory-mapped matching and ready/valid bus signaling.
- **Firmware & Verification Engineers**: Implemented C drivers in `clock.c` to parse and format the clock display. Wrote the highly optimized `tb_basic.sv` for fast 1Hz event simulation.
- **AI Engine**: Pair-programmed boilerplate and state-machine transitions to hit timing closure quickly.
