/*
 * Memory-Mapped I/O (MMIO) Accelerator Interface for IEEE-754 FPU
 *
 * Register Map (32-bit aligned):
 *   Offset 0x00: FPU_REG_OPA  (R/W) - Operand A [31:0]
 *   Offset 0x04: FPU_REG_OPB  (R/W) - Operand B [31:0]
 *   Offset 0x08: FPU_REG_OPC  (R/W) - Operand C [31:0] (for FMAC)
 *   Offset 0x0C: FPU_REG_CTRL (R/W) -
 *                  Write: [3:0] = Opcode, [4] = Start pulse
 *                  Read:  [0] = Busy, [1] = Done, [6:2] = Flags, [11:8] = Opcode
 *   Offset 0x10: FPU_REG_RES  (RO)  - 32-bit Computation Result (auto-stalls until done)
 *   Offset 0x14: FPU_REG_PERF (RO)  - Execution Cycle Counter (telemetry/profiling)
 */

`timescale 1ns / 1ps

module fpu_mmio_accel (
    input  wire        clk,
    input  wire        rst_n,

    // MMIO Slave Interface (PicoRV32-compatible handshake)
    input  wire        mem_valid,
    input  wire        mem_instr,
    output reg         mem_ready,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [ 3:0] mem_wstrb,
    output reg  [31:0] mem_rdata
);

    // Internal Registers
    reg [31:0] reg_op_a;
    reg [31:0] reg_op_b;
    reg [31:0] reg_op_c;
    reg [ 3:0] reg_opcode;
    reg [31:0] reg_perf_cycles;
    reg        fpu_start;

    // FPU Signals
    wire [31:0] fpu_result;
    wire        fpu_done;
    wire        fpu_busy;
    wire [ 4:0] fpu_flags;

    reg         fpu_done_latch;
    reg  [ 4:0] fpu_flags_latch;
    reg  [31:0] fpu_result_latch;

    // Instantiate FPU core
    fpu_sp u_fpu (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (fpu_start),
        .op     (reg_opcode),
        .op_a   (reg_op_a),
        .op_b   (reg_op_b),
        .op_c   (reg_op_c),
        .result (fpu_result),
        .done   (fpu_done),
        .busy   (fpu_busy),
        .flags  (fpu_flags)
    );

    // Register address decoding (bits [5:2])
    wire [3:0] reg_addr = mem_addr[5:2];

    // Latch FPU completion
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fpu_done_latch   <= 1'b0;
            fpu_flags_latch  <= 5'b00000;
            fpu_result_latch <= 32'd0;
            reg_perf_cycles  <= 32'd0;
        end else begin
            if (fpu_start) begin
                fpu_done_latch  <= 1'b0;
                reg_perf_cycles <= 32'd0;
            end else if (fpu_busy) begin
                reg_perf_cycles <= reg_perf_cycles + 1'b1;
            end

            if (fpu_done) begin
                fpu_done_latch   <= 1'b1;
                fpu_flags_latch  <= fpu_flags;
                fpu_result_latch <= fpu_result;
            end
        end
    end

    // MMIO read/write bus handler
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready  <= 1'b0;
            mem_rdata  <= 32'd0;
            reg_op_a   <= 32'd0;
            reg_op_b   <= 32'd0;
            reg_op_c   <= 32'd0;
            reg_opcode <= 4'd0;
            fpu_start  <= 1'b0;
        end else begin
            fpu_start <= 1'b0; // Default pulse
            mem_ready <= 1'b0;

            if (mem_valid && !mem_ready) begin
                if (|mem_wstrb) begin
                    // Write operation (single cycle ready)
                    case (reg_addr)
                        4'h0: begin // 0x00: OPA
                            if (mem_wstrb[0]) reg_op_a[ 7: 0] <= mem_wdata[ 7: 0];
                            if (mem_wstrb[1]) reg_op_a[15: 8] <= mem_wdata[15: 8];
                            if (mem_wstrb[2]) reg_op_a[23:16] <= mem_wdata[23:16];
                            if (mem_wstrb[3]) reg_op_a[31:24] <= mem_wdata[31:24];
                        end
                        4'h1: begin // 0x04: OPB
                            if (mem_wstrb[0]) reg_op_b[ 7: 0] <= mem_wdata[ 7: 0];
                            if (mem_wstrb[1]) reg_op_b[15: 8] <= mem_wdata[15: 8];
                            if (mem_wstrb[2]) reg_op_b[23:16] <= mem_wdata[23:16];
                            if (mem_wstrb[3]) reg_op_b[31:24] <= mem_wdata[31:24];
                        end
                        4'h2: begin // 0x08: OPC
                            if (mem_wstrb[0]) reg_op_c[ 7: 0] <= mem_wdata[ 7: 0];
                            if (mem_wstrb[1]) reg_op_c[15: 8] <= mem_wdata[15: 8];
                            if (mem_wstrb[2]) reg_op_c[23:16] <= mem_wdata[23:16];
                            if (mem_wstrb[3]) reg_op_c[31:24] <= mem_wdata[31:24];
                        end
                        4'h3: begin // 0x0C: CTRL
                            reg_opcode <= mem_wdata[3:0];
                            if (mem_wdata[4]) begin
                                fpu_start <= 1'b1;
                            end
                        end
                        default: ;
                    endcase
                    mem_ready <= 1'b1;
                end else begin
                    // Read operation
                    case (reg_addr)
                        4'h0: begin // 0x00: OPA
                            mem_rdata <= reg_op_a;
                            mem_ready <= 1'b1;
                        end
                        4'h1: begin // 0x04: OPB
                            mem_rdata <= reg_op_b;
                            mem_ready <= 1'b1;
                        end
                        4'h2: begin // 0x08: OPC
                            mem_rdata <= reg_op_c;
                            mem_ready <= 1'b1;
                        end
                        4'h3: begin // 0x0C: CTRL (Status register: non-blocking)
                            mem_rdata <= {20'd0, reg_opcode, 1'b0, fpu_flags_latch, fpu_done_latch, fpu_busy};
                            mem_ready <= 1'b1;
                        end
                        4'h4: begin // 0x10: RESULT (Hardware auto-synchronization)
                            if (fpu_busy || fpu_start) begin
                                // Wait until computation completes
                                mem_ready <= 1'b0;
                            end else begin
                                mem_rdata <= fpu_result_latch;
                                mem_ready <= 1'b1;
                            end
                        end
                        4'h5: begin // 0x14: PERF CYCLE COUNTER
                            mem_rdata <= reg_perf_cycles;
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
