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

### Device:

<img width="527" height="683" alt="image" src="https://github.com/user-attachments/assets/275da8b8-fac5-4103-bb75-557c522d8935" />

### Resource Utilization:

<img width="485" height="245" alt="image" src="https://github.com/user-attachments/assets/8a2dc094-9bc2-4ca5-bb4e-20eb27a0c961" />

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


Phase3 (FPU double)

## 64-Bit Double Precision MMIO Register Interface (`0x2000_0000`)

| Address Offset | Register Name | Width | Functional Description |
| --- | --- | --- | --- |
| `0x00` | `REG_FPU_OPA_LO` | 32-bit | Lower 32 bits of 64-bit Operand A (`opa[31:0]`) |
| `0x04` | `REG_FPU_OPA_HI` | 32-bit | Upper 32 bits of 64-bit Operand A (`opa[63:32]`) |
| `0x08` | `REG_FPU_OPB_LO` | 32-bit | Lower 32 bits of 64-bit Operand B (`opb[31:0]`) |
| `0x0C` | `REG_FPU_OPB_HI` | 32-bit | Upper 32 bits of 64-bit Operand B (`opb[63:32]`) |
| `0x10` | `REG_FPU_OPC_LO` | 32-bit | Lower 32 bits of 64-bit Accumulator C (`opc[31:0]`) |
| `0x14` | `REG_FPU_OPC_HI` | 32-bit | Upper 32 bits of 64-bit Accumulator C (`opc[63:32]`) |
| `0x18` | `REG_FPU_CTRL`   | 32-bit | `[3:0]`: Opcode, `[4]`: Start Pulse |
| `0x1C` | `REG_FPU_RES_LO` | 32-bit | Lower 32 bits of 64-bit Result (Auto-stalls CPU until done) |
| `0x20` | `REG_FPU_RES_HI` | 32-bit | Upper 32 bits of 64-bit Result (`result[63:32]`) |
| `0x24` | `REG_FPU_PERF`   | 32-bit | Execution cycle counter |

### Supported 64-Bit Opcodes:
- `0x0`: **DADD** (64-bit Double Addition: $A + B$)
- `0x1`: **DSUB** (64-bit Double Subtraction: $A - B$)
- `0x2`: **DMUL** (64-bit Double Multiplication: $A \times B$)
- `0x3`: **DDIV** (64-bit Double Division: $A / B$)
- `0x4`: **DSQRT** (64-bit Double Square Root: $\sqrt{A}$)
- `0x5`: **ITOD** (32-bit Integer to 64-bit Double conversion)
- `0x6`: **DTOI** (64-bit Double to 32-bit Integer conversion)


### Waveform:
<img width="1272" height="391" alt="image" src="https://github.com/user-attachments/assets/22ef6e5f-ab5f-4d50-bf37-d6b44893da5e" />

### Tcl Console

```
# run 1000ns
-----------------------------------------------------------------
STARTING SIMULATION: Rocket Navigation & Telemetry SoC
Core: PicoRV32IM | Accel: IEEE-754 64-Bit Double-Precision FPU
-----------------------------------------------------------------
[TB] System Reset Released. CPU Booting from SRAM 0x00000000...
[TB-MONITOR] Avionics Status LED Changed -> 0xff at time 790000 ns
INFO: [USF-XSim-96] XSim completed. Design snapshot 'soc_tb_behav' loaded.
INFO: [USF-XSim-97] XSim simulation ran for 1000ns
launch_simulation: Time (s): cpu = 00:00:02 ; elapsed = 00:00:07 . Memory (MB): peak = 2767.980 ; gain = 0.160
run -all


======================================================

[RICV_DOUBLE] PICO-RV32IM + 64-BIT IEEE-754 DOUBLE FPU BOOT

[RICV_DOUBLE] 64-Bit Avionics Numerical Processing Core

======================================================

[64-BIT FPU] DADD: PASS (12.5 + 7.25 = 19.75 | 0x4033C00000000000)

[64-BIT FPU] DMUL: PASS (3.0 * 4.5 = 13.5 | 0x402B000000000000)

[64-BIT FPU] DSQRT: PASS (sqrt(25.0) = 5.0 | 0x4014000000000000)

[64-BIT TLM] 3D DOUBLE NAV ACCEL NORM = 5.000000000000000 m/s^2 [LOCK ACHIEVED]

[64-BIT TLM] 64-BIT MISSION TIMER TICK CAPTURED [ACTIVE]

======================================================

[RICV_DOUBLE] ALL 64-BIT DOUBLE SYSTEMS NOMINAL. TELEMETRY OK

======================================================


-----------------------------------------------------------------
[TB] TIMEOUT reached at time 3000100000 ns
-----------------------------------------------------------------
$finish called at time : 3000100 ns : File "C:/Users/santh/OneDrive/Dokumen/EDUCATION IN ECE/VLSI/Projects/RISV-SOC/first_try/RICV_double/tb/soc_tb.v" Line 123
```

cmd Output:
```
PS C:\Users\santh\OneDrive\Dokumen\EDUCATION IN ECE\VLSI\Projects\RISV-SOC\first_try\RICV_double> go run cmd_app.go
==========================================================
    64-BIT DOUBLE PRECISION FPU CLOCK CYCLE MONITOR
==========================================================
 Target Core : IEEE-754 64-Bit Double-Precision FPU (RICV_double)
 Clock Freq  : 50 MHz (20 ns per cycle)
 Format      : 1 Sign, 11 Exponent, 52 Mantissa Bits
==========================================================

Enter COM Port name (e.g. COM3, COM4, COM20) [Default: COM3]: COM20

[INFO] Connected to 64-Bit Double SoC on COM20 at 115,200 Baud.
----------------------------------------------------------
  [1] Measure 64-Bit DADD Clock Cycles
  [2] Measure 64-Bit DMUL Clock Cycles
  [3] Measure 64-Bit DSQRT Clock Cycles
  [4] Measure 64-Bit 3D Double Vector Norm Total Cycles
  [Q] Quit
----------------------------------------------------------

Select Option [1-4 / Q]: 1

[64-BIT FPU PROFILE] DADD (12.5 + 7.25):
  -> 64-Bit Double Hex Output: 0x4033C00000000000 (19.75)
  -> FPU Hardware Latency    : 2 Clock Cycles (40 ns @ 50MHz)

Select Option [1-4 / Q]: 2

[64-BIT FPU PROFILE] DMUL (3.0 * 4.5):
  -> 64-Bit Double Hex Output: 0x402B000000000000 (13.5)
  -> FPU Hardware Latency    : 3 Clock Cycles (60 ns @ 50MHz)

Select Option [1-4 / Q]: 3

[64-BIT FPU PROFILE] DSQRT (sqrt(25.0)):
  -> 64-Bit Double Hex Output: 0x4014000000000000 (5.0)
  -> FPU Hardware Latency    : 15 Clock Cycles (300 ns @ 50MHz)

Select Option [1-4 / Q]: 4

[64-BIT FPU PROFILE] 3D Double Vector Norm ||a||:
  -> 64-Bit Double Vector Norm: 5.000000000000000 m/s^2
  -> Total 64-Bit Pipeline Latency: 26 Clock Cycles (520 ns @ 50MHz)
```

### PuTTy Terminal Output:

<img width="795" height="297" alt="image" src="https://github.com/user-attachments/assets/1a22f1ed-2225-4f30-8031-b6c9723d508f" />

### Timing Summary:

<img width="1067" height="287" alt="image" src="https://github.com/user-attachments/assets/6208d88a-b866-4484-8c7d-40729a51c5db" />

### Power Summary:

<img width="816" height="423" alt="image" src="https://github.com/user-attachments/assets/f6004c66-6260-4811-b59b-bf4366cf69ca" />

### Schematic:

<img width="1552" height="482" alt="image" src="https://github.com/user-attachments/assets/680b458b-08b8-4354-a693-498f13c8c364" />

### Constraints:

<img width="1580" height="758" alt="image" src="https://github.com/user-attachments/assets/f97b3193-d031-4723-86c1-6636e199e86f" />

### Device:

<img width="516" height="692" alt="image" src="https://github.com/user-attachments/assets/6579a81f-66b6-4c3d-93fd-0a02245a0217" />

### Resource Utilization:

<img width="483" height="242" alt="image" src="https://github.com/user-attachments/assets/69350395-a08a-463e-8d8e-81908cef771f" />
