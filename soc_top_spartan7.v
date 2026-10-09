/*
 * Spartan-7 / Arty S7-50 Top-Level Wrapper
 * Target FPGA: Xilinx Spartan-7 xc7s50csga324-1 (Digilent Arty S7-50)
 *
 * Interfaces:
 *   - 100 MHz Onboard Clock (Pin R2) -> divided to 50 MHz sys_clk
 *   - Reset: BTN0 Push Button (Pin J2, Active-High) or Reset Button (Pin C18, Active-Low)
 *   - 4 User Slide Switches (SW0-SW3)
 *   - 4 Green User LEDs (LD2-LD5) for Telemetry Status
 *   - RGB LED 0 for Navigation Status
 *   - RGB LED 1 Red for CPU Trap Warning
 *   - USB-UART Interface (TX: Pin R12, RX: Pin V12)
 */

`timescale 1ns / 1ps

module soc_top_spartan7 (
    input  wire        clk_100m,   // 100 MHz oscillator (Pin R2)
    input  wire        btn_reset,  // Active-High BTN0 (Pin J2)
    input  wire [ 3:0] sw,         // 4 User Switches (SW0-SW3)
    output wire [ 3:0] leds,       // 4 Green LEDs (LD2-LD5)
    output wire [ 2:0] rgb_led0,   // RGB LED 0: [2]=B, [1]=G, [0]=R
    output wire        rgb_led1_r, // RGB LED 1 Red: CPU Trap indicator
    input  wire        uart_rx,    // USB-UART RX (Pin V12)
    output wire        uart_tx     // USB-UART TX (Pin R12)
);

    // 50 MHz internal system clock generation from 100 MHz oscillator using dedicated BUFG
    reg clk_div = 1'b0;
    always @(posedge clk_100m) begin
        clk_div <= ~clk_div;
    end

    wire clk_50m;
    BUFG u_bufg_clk50 (
        .I (clk_div),
        .O (clk_50m)
    );

    // Power-on reset & button debounce synchronizer (Registered to eliminate LUTAR glitches)
    reg [3:0] rst_pipe = 4'h0;
    reg       rst_n_reg = 1'b0;
    wire      rst_n = rst_n_reg;

    always @(posedge clk_50m) begin
        if (btn_reset) begin
            rst_pipe  <= 4'h0;
            rst_n_reg <= 1'b0;
        end else begin
            rst_pipe  <= {rst_pipe[2:0], 1'b1};
            rst_n_reg <= &rst_pipe;
        end
    end

    wire trap;
    wire [7:0] soc_gpio_out;
    wire [7:0] soc_gpio_in = {4'b0000, sw};

    // Instantiate Rocket Navigation & Telemetry SoC
    rocket_nav_soc #(
        .MEM_WORDS        (4096),
        .MEM_HEX_FILE     ("firmware.hex"),
        .DEFAULT_BAUD_DIV (16'd434) // 50 MHz / 115200 = 434
    ) u_soc (
        .clk      (clk_50m),
        .rst_n    (rst_n),
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx),
        .gpio_in  (soc_gpio_in),
        .gpio_out (soc_gpio_out),
        .trap     (trap)
    );

    // Map LEDs:
    // leds[3:0] drive the 4 green user LEDs (LD2-LD5)
    assign leds = soc_gpio_out[3:0];

    // rgb_led0 drives RGB LED 0: R = bit 4, G = bit 5, B = bit 6
    assign rgb_led0 = soc_gpio_out[6:4];

    // rgb_led1_r lights up RED if the CPU hits an illegal instruction / TRAP
    assign rgb_led1_r = trap;

endmodule
