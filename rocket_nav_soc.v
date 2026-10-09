/*
 * Spacecraft Navigation & Telemetry RISC-V SoC (rocket_nav_soc)
 *
 * Integrates:
 *   - PicoRV32 Core (RV32IM architecture with hardware multiply/divide)
 *   - Hardware Floating-Point Accelerator (IEEE-754 Single-Precision FPU: Add/Sub/Mul/Div/Sqrt/Mac/Conv)
 *   - Full-Duplex Telemetry UART Controller (115200 Baud)
 *   - 64-bit Spacecraft Mission Timer & Period Tick Generator
 *   - GPIO / Flight Status Indicators & Telemetry Mode Selection
 *   - 16 KB On-Chip SRAM Boot Memory
 *   - Zero-Latency MMIO Bus Interconnect
 */

`timescale 1ns / 1ps

module rocket_nav_soc #(
    parameter MEM_WORDS        = 4096,          // 16 KB SRAM
    parameter MEM_HEX_FILE     = "firmware.hex",// Firmware hex image
    parameter DEFAULT_BAUD_DIV = 16'd434        // 50MHz / 115200 baud
) (
    input  wire        clk,
    input  wire        rst_n,

    // UART Telemetry Transceiver
    input  wire        uart_rx,
    output wire        uart_tx,

    // Avionics GPIO & Telemetry Switches
    input  wire [ 7:0] gpio_in,
    output wire [ 7:0] gpio_out,

    // Processor Diagnostic Status
    output wire        trap
);

    // -------------------------------------------------------------
    // CPU Native Bus Interconnect Signals
    // -------------------------------------------------------------
    wire        cpu_mem_valid;
    wire        cpu_mem_instr;
    wire        cpu_mem_ready;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [ 3:0] cpu_mem_wstrb;
    wire [31:0] cpu_mem_rdata;

    // Slave Busses
    wire        ram_valid,   ram_ready;
    wire [31:0] ram_addr,    ram_wdata,   ram_rdata;
    wire [ 3:0] ram_wstrb;

    wire        uart_valid,  uart_ready;
    wire [31:0] uart_addr,   uart_wdata,  uart_rdata;
    wire [ 3:0] uart_wstrb;

    wire        fpu_valid,   fpu_ready;
    wire [31:0] fpu_addr,    fpu_wdata,   fpu_rdata;
    wire [ 3:0] fpu_wstrb;

    wire        timer_valid, timer_ready;
    wire [31:0] timer_addr,  timer_wdata, timer_rdata;
    wire [ 3:0] timer_wstrb;

    wire        gpio_valid,  gpio_ready;
    wire [31:0] gpio_addr,   gpio_wdata,  gpio_rdata;
    wire [ 3:0] gpio_wstrb;

    wire        timer_tick_irq;

    // -------------------------------------------------------------
    // PicoRV32 Core (RV32IM)
    // -------------------------------------------------------------
    picorv32 #(
        .ENABLE_COUNTERS     (1'b1),
        .ENABLE_COUNTERS64   (1'b1),
        .ENABLE_REGS_16_31   (1'b1),
        .ENABLE_REGS_DUALPORT(1'b1),
        .LATCHED_MEM_RDATA   (1'b0),
        .TWO_STAGE_SHIFT     (1'b1),
        .BARREL_SHIFTER      (1'b1),
        .TWO_CYCLE_COMPARE   (1'b0),
        .TWO_CYCLE_ALU       (1'b0),
        .COMPRESSED_ISA      (1'b0),
        .CATCH_MISALIGN      (1'b1),
        .CATCH_ILLINSN       (1'b1),
        .ENABLE_PCPI         (1'b0),
        .ENABLE_MUL          (1'b1), // RV32M Multiply
        .ENABLE_FAST_MUL     (1'b1),
        .ENABLE_DIV          (1'b1), // RV32M Divide
        .ENABLE_IRQ          (1'b0),
        .ENABLE_TRACE        (1'b0),
        .PROGADDR_RESET      (32'h0000_0000),
        .STACKADDR           (32'h0000_3FFC)
    ) u_picorv32 (
        .clk         (clk),
        .resetn      (rst_n),
        .trap        (trap),

        .mem_valid   (cpu_mem_valid),
        .mem_instr   (cpu_mem_instr),
        .mem_ready   (cpu_mem_ready),
        .mem_addr    (cpu_mem_addr),
        .mem_wdata   (cpu_mem_wdata),
        .mem_wstrb   (cpu_mem_wstrb),
        .mem_rdata   (cpu_mem_rdata),

        .mem_la_read (),
        .mem_la_write(),
        .mem_la_addr (),
        .mem_la_wdata(),
        .mem_la_wstrb(),

        .pcpi_valid  (),
        .pcpi_insn   (),
        .pcpi_rs1    (),
        .pcpi_rs2    (),
        .pcpi_wr     (1'b0),
        .pcpi_rd     (32'd0),
        .pcpi_wait   (1'b0),
        .pcpi_ready  (1'b0),

        .irq         (32'd0),
        .eoi         (),
        .trace_valid (),
        .trace_data  ()
    );

    // -------------------------------------------------------------
    // MMIO Bus Interconnect Crossbar
    // -------------------------------------------------------------
    soc_bus_interconnect u_interconnect (
        .clk           (clk),
        .rst_n         (rst_n),

        // CPU Master
        .cpu_mem_valid (cpu_mem_valid),
        .cpu_mem_instr (cpu_mem_instr),
        .cpu_mem_ready (cpu_mem_ready),
        .cpu_mem_addr  (cpu_mem_addr),
        .cpu_mem_wdata (cpu_mem_wdata),
        .cpu_mem_wstrb (cpu_mem_wstrb),
        .cpu_mem_rdata (cpu_mem_rdata),

        // Slave 0: RAM
        .ram_valid     (ram_valid),
        .ram_ready     (ram_ready),
        .ram_addr      (ram_addr),
        .ram_wdata     (ram_wdata),
        .ram_wstrb     (ram_wstrb),
        .ram_rdata     (ram_rdata),

        // Slave 1: UART
        .uart_valid    (uart_valid),
        .uart_ready    (uart_ready),
        .uart_addr     (uart_addr),
        .uart_wdata    (uart_wdata),
        .uart_wstrb    (uart_wstrb),
        .uart_rdata    (uart_rdata),

        // Slave 2: FPU Accelerator
        .fpu_valid     (fpu_valid),
        .fpu_ready     (fpu_ready),
        .fpu_addr      (fpu_addr),
        .fpu_wdata     (fpu_wdata),
        .fpu_wstrb     (fpu_wstrb),
        .fpu_rdata     (fpu_rdata),

        // Slave 3: Timer
        .timer_valid   (timer_valid),
        .timer_ready   (timer_ready),
        .timer_addr    (timer_addr),
        .timer_wdata   (timer_wdata),
        .timer_wstrb   (timer_wstrb),
        .timer_rdata   (timer_rdata),

        // Slave 4: GPIO
        .gpio_valid    (gpio_valid),
        .gpio_ready    (gpio_ready),
        .gpio_addr     (gpio_addr),
        .gpio_wdata    (gpio_wdata),
        .gpio_wstrb    (gpio_wstrb),
        .gpio_rdata    (gpio_rdata)
    );

    // -------------------------------------------------------------
    // On-Chip SRAM (16 KB)
    // -------------------------------------------------------------
    soc_ram #(
        .WORDS     (MEM_WORDS),
        .INIT_FILE (MEM_HEX_FILE)
    ) u_ram (
        .clk       (clk),
        .rst_n     (rst_n),
        .mem_valid (ram_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (ram_ready),
        .mem_addr  (ram_addr),
        .mem_wdata (ram_wdata),
        .mem_wstrb (ram_wstrb),
        .mem_rdata (ram_rdata)
    );

    // -------------------------------------------------------------
    // Telemetry & Command UART Controller
    // -------------------------------------------------------------
    uart_controller #(
        .DEFAULT_BAUD_DIV (DEFAULT_BAUD_DIV)
    ) u_uart (
        .clk       (clk),
        .rst_n     (rst_n),
        .uart_rx   (uart_rx),
        .uart_tx   (uart_tx),
        .mem_valid (uart_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (uart_ready),
        .mem_addr  (uart_addr),
        .mem_wdata (uart_wdata),
        .mem_wstrb (uart_wstrb),
        .mem_rdata (uart_rdata)
    );

    // -------------------------------------------------------------
    // Floating-Point Numerical Accelerator (FPU)
    // -------------------------------------------------------------
    fpu_mmio_accel u_fpu_accel (
        .clk       (clk),
        .rst_n     (rst_n),
        .mem_valid (fpu_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (fpu_ready),
        .mem_addr  (fpu_addr),
        .mem_wdata (fpu_wdata),
        .mem_wstrb (fpu_wstrb),
        .mem_rdata (fpu_rdata)
    );

    // -------------------------------------------------------------
    // Mission Timer
    // -------------------------------------------------------------
    timer u_timer (
        .clk       (clk),
        .rst_n     (rst_n),
        .tick_irq  (timer_tick_irq),
        .mem_valid (timer_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (timer_ready),
        .mem_addr  (timer_addr),
        .mem_wdata (timer_wdata),
        .mem_wstrb (timer_wstrb),
        .mem_rdata (timer_rdata)
    );

    // -------------------------------------------------------------
    // GPIO & Flight Status Register
    // -------------------------------------------------------------
    gpio u_gpio (
        .clk       (clk),
        .rst_n     (rst_n),
        .gpio_out  (gpio_out),
        .gpio_in   (gpio_in),
        .mem_valid (gpio_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (gpio_ready),
        .mem_addr  (gpio_addr),
        .mem_wdata (gpio_wdata),
        .mem_wstrb (gpio_wstrb),
        .mem_rdata (gpio_rdata)
    );

endmodule
