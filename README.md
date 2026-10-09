# A-RISC-V-based-onboard-numerical-processing-SoC-for-rocket-spacecraft-navigation

## Why I like this project

 - There is a real engineering motivation behind onboard numerical processing.
NASA describes onboard computing as responsible for real-time control, command execution, telemetry generation, data storage and subsystem coordination.

 - And RISC-V + FPGA onboard computing is not a random academic combination. Research has explored RISC-V soft processors for spaceflight, including FPGA implementations and fault-injection testing. Southwest Research Institute

 - There is also very recent work showing that spacecraft workloads can benefit significantly from domain-specific accelerators. A 2026 study reported that trigonometric functions and small matrix operations are major computational bottlenecks in spacecraft workloads, and demonstrated RISC-V-connected CORDIC and matrix accelerators. EurekaMag

 - That gives you a very good justification for your architecture.


## Phase 2(FPU 32bit):



### Memory Map (MMIO)

| Address Range | Size | Peripheral / Device | Description |
|---|---|---|---|
| `0x0000_0000 - 0x0000_3FFF` | 16 KB | **On-Chip SRAM** | Instruction & Data Memory (`firmware.hex`) |
| `0x1000_0000 - 0x1000_000B` | 12 B | **UART Controller** | Telemetry Downlink & Command Uplink |
| `0x2000_0000 - 0x2000_0017` | 24 B | **FPU Accelerator** | IEEE-754 Floating-Point Coprocessor |
| `0x3000_0000 - 0x3000_000F` | 16 B | **Mission Timer** | 64-bit Mission Clock & Match Interrupt |
| `0x4000_0000 - 0x4000_000B` | 12 B | **GPIO / Avionics** | Flight Status LEDs & Configuration Switches |

### Hierarchical Cell Utilization
| Instance | Module | Cell Count | Description |
|---|---|---|---|
| `top` | `soc_top_zedboard` | 6,942 | Board wrapper with clock divider & debounce |
| `u_soc` | `rocket_nav_soc` | 6,913 | Top-Level SoC |
| `├── u_fpu_accel` | `fpu_mmio_accel` | 3,580 | FPU MMIO wrapper & IEEE-754 unit |
| `├── u_picorv32` | `picorv32` | 2,726 | RV32IM processor core with Mul/Div |
| `├── u_uart` | `uart_controller` | 255 | Telemetry UART transceiver |
| `├── u_timer` | `timer` | 220 | 64-bit mission clock & match counter |
| `├── u_ram` | `soc_ram` | 69 | 16 KB BRAM instance (4 RAMB36) |
| `├── u_gpio` | `gpio` | 50 | Status LEDs and switches register |
| `└── u_interconnect`| `soc_bus_interconnect` | 2 | MMIO crossbar address decoder |


### Tcl Console:
```
======================================================

[AEROSPACE-SOC] PICO-RV32IM + IEEE-754 FPU AVIONICS BOOT

[AEROSPACE-SOC] Spacecraft Telemetry & Navigation Core

======================================================

[FPU] FADD: PASS (12.5 + 7.25 = 19.75)

[FPU] FMUL: PASS (3.0 * 4.5 = 13.5)

[FPU] FSQRT: PASS (sqrt(9.0) = 3.0)

[TLM] 3D NAV ACCEL NORM = 3.0 m/s^2 [LOCK ACHIEVED]

[TLM] MISSION TIMER TICK CAPTURED [ACTIVE]

======================================================

[AEROSPACE-SOC] ALL FLIGHT SYSTEMS NOMINAL. TELEMETRY OK

======================================================
```

file name: first_try(2)

### Waveform:
<img width="1560" height="488" alt="image" src="https://github.com/user-attachments/assets/dbb22c47-8c49-4b6e-938a-d61cffce313d" />

### PuTTy Terminal Output:
<img width="583" height="235" alt="image" src="https://github.com/user-attachments/assets/3c6dd69b-54c5-4a1a-9d60-5d9be80db9c0" />

### Output in cmd:
<img width="1307" height="928" alt="image" src="https://github.com/user-attachments/assets/31ea7cb7-fe18-4a3e-b617-f291519fb3cc" />

### Timing Summary
<img width="1047" height="297" alt="image" src="https://github.com/user-attachments/assets/067d1f84-2dca-432a-b468-43d55ef1fa93" />

### Power:
<img width="832" height="435" alt="image" src="https://github.com/user-attachments/assets/fdec6aab-c8c5-44f2-b46a-52d8b1894011" />

### Constraints:
<img width="1588" height="671" alt="image" src="https://github.com/user-attachments/assets/fee9c123-f87c-4287-87c5-5700dfc918e8" />

### Design Runs:
<img width="1488" height="62" alt="image" src="https://github.com/user-attachments/assets/f5b93d8f-c487-4921-930b-0e28e40efab3" />

### Schematic:
<img width="1162" height="431" alt="image" src="https://github.com/user-attachments/assets/9cc879a4-fc10-4a22-bac9-609e6a27ecca" />


