/*
 * Full-Duplex Memory-Mapped UART Controller for Telemetry & Command Downlink
 *
 * Register Map:
 *   Offset 0x00: UART_DATA     (R/W) - [7:0] Data byte (write to transmit, read received)
 *   Offset 0x04: UART_STATUS   (RO)  - [0] = tx_busy, [1] = rx_valid, [2] = tx_ready
 *   Offset 0x08: UART_BAUD_DIV (R/W) - [15:0] Baud divisor (sys_clk / baud_rate)
 */

`timescale 1ns / 1ps

module uart_controller #(
    parameter DEFAULT_BAUD_DIV = 16'd434 // e.g. 50MHz / 115200 baud = 434
) (
    input  wire        clk,
    input  wire        rst_n,

    // UART Physical Pins
    input  wire        uart_rx,
    output reg         uart_tx,

    // MMIO Slave Interface
    input  wire        mem_valid,
    input  wire        mem_instr,
    output reg         mem_ready,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [ 3:0] mem_wstrb,
    output reg  [31:0] mem_rdata
);

    // Registers
    reg [15:0] baud_div;
    reg [ 7:0] tx_data_reg;
    reg        tx_start;
    wire       tx_busy;

    reg [ 7:0] rx_data_reg;
    reg        rx_valid;

    // -------------------------------------------------------------
    // UART Transmitter Logic
    // -------------------------------------------------------------
    reg [15:0] tx_clk_cnt;
    reg [ 3:0] tx_bit_idx;
    reg [ 9:0] tx_shift_reg; // start bit (0), 8 data bits, stop bit (1)
    reg        tx_active;

    assign tx_busy = tx_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx      <= 1'b1; // Idle high
            tx_clk_cnt   <= 16'd0;
            tx_bit_idx   <= 4'd0;
            tx_shift_reg <= 10'h3FF;
            tx_active    <= 1'b0;
        end else begin
            if (!tx_active) begin
                uart_tx <= 1'b1;
                if (tx_start) begin
                    tx_shift_reg <= {1'b1, tx_data_reg, 1'b0}; // Stop bit, data, Start bit
                    tx_clk_cnt   <= 16'd0;
                    tx_bit_idx   <= 4'd0;
                    tx_active    <= 1'b1;
                end
            end else begin
                if (tx_clk_cnt < baud_div - 1'b1) begin
                    tx_clk_cnt <= tx_clk_cnt + 1'b1;
                end else begin
                    tx_clk_cnt <= 16'd0;
                    uart_tx    <= tx_shift_reg[0];
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                    if (tx_bit_idx == 4'd9) begin
                        tx_active <= 1'b0;
                    end else begin
                        tx_bit_idx <= tx_bit_idx + 1'b1;
                    end
                end
            end
        end
    end

    // -------------------------------------------------------------
    // UART Receiver Logic (with 2-stage synchronizer and 8x oversample)
    // -------------------------------------------------------------
    reg [1:0] rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rx_sync <= 2'b11;
        else rx_sync <= {rx_sync[0], uart_rx};
    end
    wire rx_in = rx_sync[1];

    reg [15:0] rx_clk_cnt;
    reg [ 3:0] rx_bit_idx;
    reg [ 7:0] rx_shift_reg;
    reg        rx_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_clk_cnt   <= 16'd0;
            rx_bit_idx   <= 4'd0;
            rx_shift_reg <= 8'd0;
            rx_busy      <= 1'b0;
            rx_data_reg  <= 8'd0;
            rx_valid     <= 1'b0;
        end else begin
            // Clear rx_valid on read
            if (mem_valid && !mem_ready && !(|mem_wstrb) && (mem_addr[3:2] == 2'b00)) begin
                rx_valid <= 1'b0;
            end

            if (!rx_busy) begin
                if (rx_in == 1'b0) begin // Start bit detected
                    rx_busy    <= 1'b1;
                    rx_clk_cnt <= baud_div >> 1; // Sample in the middle of bit period
                    rx_bit_idx <= 4'd0;
                end
            end else begin
                if (rx_clk_cnt < baud_div - 1'b1) begin
                    rx_clk_cnt <= rx_clk_cnt + 1'b1;
                end else begin
                    rx_clk_cnt <= 16'd0;
                    if (rx_bit_idx == 4'd0) begin
                        // Check valid start bit
                        if (rx_in == 1'b0) begin
                            rx_bit_idx <= rx_bit_idx + 1'b1;
                        end else begin
                            rx_busy <= 1'b0; // False start bit
                        end
                    end else if (rx_bit_idx <= 4'd8) begin
                        rx_shift_reg <= {rx_in, rx_shift_reg[7:1]};
                        rx_bit_idx   <= rx_bit_idx + 1'b1;
                    end else begin
                        // Stop bit
                        rx_busy     <= 1'b0;
                        rx_data_reg <= rx_shift_reg;
                        rx_valid    <= 1'b1;
                    end
                end
            end
        end
    end

    // -------------------------------------------------------------
    // MMIO Interface
    // -------------------------------------------------------------
    wire [1:0] reg_addr = mem_addr[3:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready   <= 1'b0;
            mem_rdata   <= 32'd0;
            baud_div    <= DEFAULT_BAUD_DIV;
            tx_data_reg <= 8'd0;
            tx_start    <= 1'b0;
        end else begin
            tx_start  <= 1'b0;
            mem_ready <= 1'b0;

            if (mem_valid && !mem_ready) begin
                if (|mem_wstrb) begin
                    // Write
                    case (reg_addr)
                        2'b00: begin // 0x00: DATA
                            tx_data_reg <= mem_wdata[7:0];
                            tx_start    <= 1'b1;
                        end
                        2'b10: begin // 0x08: BAUD_DIV
                            baud_div <= mem_wdata[15:0];
                        end
                        default: ;
                    endcase
                    mem_ready <= 1'b1;
                end else begin
                    // Read
                    case (reg_addr)
                        2'b00: begin // 0x00: DATA
                            mem_rdata <= {24'd0, rx_data_reg};
                            mem_ready <= 1'b1;
                        end
                        2'b01: begin // 0x04: STATUS
                            mem_rdata <= {29'd0, ~tx_busy, rx_valid, tx_busy};
                            mem_ready <= 1'b1;
                        end
                        2'b10: begin // 0x08: BAUD_DIV
                            mem_rdata <= {16'd0, baud_div};
                            mem_ready <= 1'b1;
                        end
                        default: begin
                            mem_rdata <= 32'd0;
                            mem_ready <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

endmodule
