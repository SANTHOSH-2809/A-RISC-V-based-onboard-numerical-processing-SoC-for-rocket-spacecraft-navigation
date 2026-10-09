/*
 * ZedBoard Top-Level Wrapper (Avnet ZedBoard xc7z020clg484-1)
 *
 * Interfaces:
 *   - 100 MHz Oscillator (Pin Y9) -> divided to 50 MHz sys_clk
 *   - Active-Low Reset from BTNC or Center Button
 *   - 8 Status LEDs (LD0-LD7)
 *   - 8 Configuration Switches (SW0-SW7)
 *   - UART TX/RX routed to PMOD JA (JA1: TX, JA2: RX)
 */

`timescale 1ns / 1ps

module soc_top_zedboard (
    input  wire        clk_100m,   // 100MHz onboard clock (Pin Y9)
    input  wire        btn_reset,  // Active-high push button BTNC (Pin P16)
    input  wire [ 7:0] sw,         // 8 user slide switches (SW0-SW7)
    output wire [ 7:0] leds,       // 8 user LEDs (LD0-LD7)
    input  wire        uart_rx,    // UART RX (e.g. PMOD JA2 - Pin AA11)
    output wire        uart_tx     // UART TX (e.g. PMOD JA1 - Pin Y11)
);

    // 50 MHz clock generation from 100 MHz oscillator
    reg clk_50m = 1'b0;
    always @(posedge clk_100m) begin
        clk_50m <= ~clk_50m;
    end

    // Power-on reset & button debounce synchronizer
    reg [3:0] rst_pipe = 4'h0;
    wire rst_n = &rst_pipe;

    always @(posedge clk_50m or posedge btn_reset) begin
        if (btn_reset) begin
            rst_pipe <= 4'h0;
        end else begin
            rst_pipe <= {rst_pipe[2:0], 1'b1};
        end
    end

    wire trap;
    wire [7:0] soc_gpio_out;

    // Instantiate Rocket Navigation SoC
    rocket_nav_soc #(
        .MEM_WORDS        (4096),
        .MEM_HEX_FILE     ("firmware.hex"),
        .DEFAULT_BAUD_DIV (16'd434) // 50 MHz / 115200 = 434
    ) u_soc (
        .clk      (clk_50m),
        .rst_n    (rst_n),
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx),
        .gpio_in  (sw),
        .gpio_out (soc_gpio_out),
        .trap     (trap)
    );

    // Map LEDs: LD7 indicates CPU TRAP (if 1, error), LD6-LD0 indicate flight status
    assign leds[7]   = trap;
    assign leds[6:0] = soc_gpio_out[6:0];

endmodule
