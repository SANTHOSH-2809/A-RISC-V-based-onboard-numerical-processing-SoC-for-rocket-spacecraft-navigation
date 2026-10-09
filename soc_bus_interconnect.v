/*
 * PicoRV32 MMIO Bus Crossbar / Address Decoder Interconnect
 *
 * Address Space Decoding:
 *   0x0000_0000 - 0x0000_3FFF: On-Chip SRAM (16 KB)
 *   0x1000_0000 - 0x1000_00FF: Telemetry UART Controller
 *   0x2000_0000 - 0x2000_00FF: IEEE-754 FPU Accelerator
 *   0x3000_0000 - 0x3000_00FF: Mission Timer / Counter
 *   0x4000_0000 - 0x4000_00FF: Flight Status & GPIO
 */

`timescale 1ns / 1ps

module soc_bus_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Bus Interface (Master)
    input  wire        cpu_mem_valid,
    input  wire        cpu_mem_instr,
    output wire        cpu_mem_ready,
    input  wire [31:0] cpu_mem_addr,
    input  wire [31:0] cpu_mem_wdata,
    input  wire [ 3:0] cpu_mem_wstrb,
    output reg  [31:0] cpu_mem_rdata,

    // Slave 0: SRAM (0x0000_0000)
    output wire        ram_valid,
    input  wire        ram_ready,
    output wire [31:0] ram_addr,
    output wire [31:0] ram_wdata,
    output wire [ 3:0] ram_wstrb,
    input  wire [31:0] ram_rdata,

    // Slave 1: UART (0x1000_0000)
    output wire        uart_valid,
    input  wire        uart_ready,
    output wire [31:0] uart_addr,
    output wire [31:0] uart_wdata,
    output wire [ 3:0] uart_wstrb,
    input  wire [31:0] uart_rdata,

    // Slave 2: FPU Accelerator (0x2000_0000)
    output wire        fpu_valid,
    input  wire        fpu_ready,
    output wire [31:0] fpu_addr,
    output wire [31:0] fpu_wdata,
    output wire [ 3:0] fpu_wstrb,
    input  wire [31:0] fpu_rdata,

    // Slave 3: Mission Timer (0x3000_0000)
    output wire        timer_valid,
    input  wire        timer_ready,
    output wire [31:0] timer_addr,
    output wire [31:0] timer_wdata,
    output wire [ 3:0] timer_wstrb,
    input  wire [31:0] timer_rdata,

    // Slave 4: GPIO / Flight Status (0x4000_0000)
    output wire        gpio_valid,
    input  wire        gpio_ready,
    output wire [31:0] gpio_addr,
    output wire [31:0] gpio_wdata,
    output wire [ 3:0] gpio_wstrb,
    input  wire [31:0] gpio_rdata
);

    // Address Decoding (top 4 bits: addr[31:28])
    wire sel_ram   = (cpu_mem_addr[31:28] == 4'h0);
    wire sel_uart  = (cpu_mem_addr[31:28] == 4'h1);
    wire sel_fpu   = (cpu_mem_addr[31:28] == 4'h2);
    wire sel_timer = (cpu_mem_addr[31:28] == 4'h3);
    wire sel_gpio  = (cpu_mem_addr[31:28] == 4'h4);
    wire sel_unmapped = !(sel_ram | sel_uart | sel_fpu | sel_timer | sel_gpio);

    // Dispatch valid signals
    assign ram_valid   = cpu_mem_valid & sel_ram;
    assign uart_valid  = cpu_mem_valid & sel_uart;
    assign fpu_valid   = cpu_mem_valid & sel_fpu;
    assign timer_valid = cpu_mem_valid & sel_timer;
    assign gpio_valid  = cpu_mem_valid & sel_gpio;

    // Distribute address and data
    assign ram_addr    = cpu_mem_addr;
    assign ram_wdata   = cpu_mem_wdata;
    assign ram_wstrb   = cpu_mem_wstrb;

    assign uart_addr   = cpu_mem_addr;
    assign uart_wdata  = cpu_mem_wdata;
    assign uart_wstrb  = cpu_mem_wstrb;

    assign fpu_addr    = cpu_mem_addr;
    assign fpu_wdata   = cpu_mem_wdata;
    assign fpu_wstrb   = cpu_mem_wstrb;

    assign timer_addr  = cpu_mem_addr;
    assign timer_wdata = cpu_mem_wdata;
    assign timer_wstrb = cpu_mem_wstrb;

    assign gpio_addr   = cpu_mem_addr;
    assign gpio_wdata  = cpu_mem_wdata;
    assign gpio_wstrb  = cpu_mem_wstrb;

    // Unmapped address ready pulse (to avoid deadlock)
    reg unmapped_ready;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) unmapped_ready <= 1'b0;
        else unmapped_ready <= cpu_mem_valid & sel_unmapped & !unmapped_ready;
    end

    // Ready multiplexing
    assign cpu_mem_ready = ram_ready | uart_ready | fpu_ready | timer_ready | gpio_ready | unmapped_ready;

    // Read Data multiplexing
    always @(*) begin
        if (ram_ready)        cpu_mem_rdata = ram_rdata;
        else if (uart_ready)  cpu_mem_rdata = uart_rdata;
        else if (fpu_ready)   cpu_mem_rdata = fpu_rdata;
        else if (timer_ready) cpu_mem_rdata = timer_rdata;
        else if (gpio_ready)  cpu_mem_rdata = gpio_rdata;
        else if (unmapped_ready) cpu_mem_rdata = 32'hDEADBEEF;
        else                  cpu_mem_rdata = 32'h00000000;
    end

endmodule
