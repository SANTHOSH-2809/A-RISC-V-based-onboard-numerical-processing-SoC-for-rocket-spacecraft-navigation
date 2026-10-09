/*
 * 64-bit High-Resolution Spacecraft Mission Timer & Telemetry Tick Generator
 *
 * Register Map:
 *   Offset 0x00: TIMER_LO    (RO)  - Lower 32 bits of 64-bit tick counter
 *   Offset 0x04: TIMER_HI    (RO)  - Upper 32 bits of 64-bit tick counter
 *   Offset 0x08: TIMER_CTRL  (R/W) - [0] = Enable, [1] = Reset Counter, [15:8] = Prescaler
 *   Offset 0x0C: TIMER_MATCH (R/W) - Match compare register for periodic telemetry packets
 */

`timescale 1ns / 1ps

module timer (
    input  wire        clk,
    input  wire        rst_n,

    // Interrupt / Telemetry Tick Pulse
    output reg         tick_irq,

    // MMIO Slave Interface
    input  wire        mem_valid,
    input  wire        mem_instr,
    output reg         mem_ready,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [ 3:0] mem_wstrb,
    output reg  [31:0] mem_rdata
);

    reg [63:0] mtime;
    reg [31:0] mtime_match;
    reg [ 7:0] prescaler;
    reg [ 7:0] prescaler_cnt;
    reg        timer_en;

    wire [1:0] reg_addr = mem_addr[3:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime         <= 64'd0;
            mtime_match   <= 32'hFFFFFFFF;
            prescaler     <= 8'd0;
            prescaler_cnt <= 8'd0;
            timer_en      <= 1'b1; // Default enabled
            tick_irq      <= 1'b0;
            mem_ready     <= 1'b0;
            mem_rdata     <= 32'd0;
        end else begin
            tick_irq  <= 1'b0;
            mem_ready <= 1'b0;

            // Timer counting logic
            if (timer_en) begin
                if (prescaler_cnt >= prescaler) begin
                    prescaler_cnt <= 8'd0;
                    mtime         <= mtime + 64'd1;
                    if (mtime[31:0] == mtime_match) begin
                        tick_irq <= 1'b1;
                    end
                end else begin
                    prescaler_cnt <= prescaler_cnt + 8'd1;
                end
            end

            // MMIO handler
            if (mem_valid && !mem_ready) begin
                if (|mem_wstrb) begin
                    case (reg_addr)
                        2'b00: mtime[31:0]  <= mem_wdata;
                        2'b01: mtime[63:32] <= mem_wdata;
                        2'b10: begin
                            timer_en  <= mem_wdata[0];
                            if (mem_wdata[1]) mtime <= 64'd0;
                            prescaler <= mem_wdata[15:8];
                        end
                        2'b11: mtime_match <= mem_wdata;
                    endcase
                    mem_ready <= 1'b1;
                end else begin
                    case (reg_addr)
                        2'b00: mem_rdata <= mtime[31:0];
                        2'b01: mem_rdata <= mtime[63:32];
                        2'b10: mem_rdata <= {16'd0, prescaler, 6'd0, 1'b0, timer_en};
                        2'b11: mem_rdata <= mtime_match;
                    endcase
                    mem_ready <= 1'b1;
                end
            end
        end
    end

endmodule
