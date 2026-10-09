/*
 * Spacecraft Status, Flight Indicator & ZedBoard GPIO Peripheral
 *
 * Register Map:
 *   Offset 0x00: GPIO_OUT (R/W) - Status LEDs / Avionics Flag outputs
 *   Offset 0x04: GPIO_IN  (RO)  - Flight mode switches / Telemetry enable inputs
 *   Offset 0x08: GPIO_DIR (R/W) - Direction register
 */

`timescale 1ns / 1ps

module gpio (
    input  wire        clk,
    input  wire        rst_n,

    // External Pins
    output reg  [ 7:0] gpio_out,
    input  wire [ 7:0] gpio_in,

    // MMIO Slave Interface
    input  wire        mem_valid,
    input  wire        mem_instr,
    output reg         mem_ready,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [ 3:0] mem_wstrb,
    output reg  [31:0] mem_rdata
);

    reg [7:0] gpio_dir;
    reg [7:0] gpio_in_sync1;
    reg [7:0] gpio_in_sync2;

    // 2-stage synchronizer for input pins
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_in_sync1 <= 8'd0;
            gpio_in_sync2 <= 8'd0;
        end else begin
            gpio_in_sync1 <= gpio_in;
            gpio_in_sync2 <= gpio_in_sync1;
        end
    end

    wire [1:0] reg_addr = mem_addr[3:2];

    reg [2:0] latched_sw_data;
    reg       sw3_prev;

    // Latch SW0-SW2 data on rising edge of SW3 (ENTER strobe) or when SW3 is high
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_sw_data <= 3'b000;
            sw3_prev        <= 1'b0;
        end else begin
            sw3_prev <= gpio_in_sync2[3];
            // When SW3 (ENTER switch) goes from 0 to 1, or is active high, latch SW2-SW0 data
            if (gpio_in_sync2[3] && !sw3_prev) begin
                latched_sw_data <= gpio_in_sync2[2:0];
            end
        end
    end

    wire [7:0] gpio_in_latched = {gpio_in_sync2[7:4], gpio_in_sync2[3], (gpio_in_sync2[3] ? gpio_in_sync2[2:0] : latched_sw_data)};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_out  <= 8'd0;
            gpio_dir  <= 8'hFF;
            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;
        end else begin
            mem_ready <= 1'b0;

            if (mem_valid && !mem_ready) begin
                if (|mem_wstrb) begin
                    case (reg_addr)
                        2'b00: gpio_out <= mem_wdata[7:0];
                        2'b10: gpio_dir <= mem_wdata[7:0];
                        default: ;
                    endcase
                    mem_ready <= 1'b1;
                end else begin
                    case (reg_addr)
                        2'b00: mem_rdata <= {24'd0, gpio_out};
                        2'b01: mem_rdata <= {24'd0, gpio_in_latched};
                        2'b10: mem_rdata <= {24'd0, gpio_dir};
                        default: mem_rdata <= 32'd0;
                    endcase
                    mem_ready <= 1'b1;
                end
            end
        end
    end

endmodule
