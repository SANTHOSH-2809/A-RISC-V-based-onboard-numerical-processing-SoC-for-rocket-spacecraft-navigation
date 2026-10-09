/*
 * IEEE-754 Single-Precision Floating-Point Accelerator (FPU)
 * Designed for Rocket/Spacecraft Navigation & Telemetry Numerical Processing
 *
 * Operations Supported:
 *   OP_FADD  (4'd0): result = op_a + op_b
 *   OP_FSUB  (4'd1): result = op_a - op_b
 *   OP_FMUL  (4'd2): result = op_a * op_b
 *   OP_FDIV  (4'd3): result = op_a / op_b
 *   OP_FSQRT (4'd4): result = sqrt(op_a)
 *   OP_ITOF  (4'd5): result = (float)op_a (signed 32-bit int to float)
 *   OP_FTOI  (4'd6): result = (int)op_a   (float to signed 32-bit int)
 *   OP_FMAC  (4'd7): result = (op_a * op_b) + op_c (Fused Multiply-Accumulate)
 *
 * Status / Exception Flags:
 *   flags[0]: Inexact
 *   flags[1]: Underflow
 *   flags[2]: Overflow
 *   flags[3]: Division by Zero
 *   flags[4]: Invalid Operation (e.g. sqrt of negative number, NaN input)
 */

`timescale 1ns / 1ps

module fpu_sp (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [ 3:0] op,
    input  wire [31:0] op_a,
    input  wire [31:0] op_b,
    input  wire [31:0] op_c,
    output reg  [31:0] result,
    output reg         done,
    output reg         busy,
    output reg  [ 4:0] flags
);

    // Operation Opcodes
    localparam OP_FADD  = 4'd0;
    localparam OP_FSUB  = 4'd1;
    localparam OP_FMUL  = 4'd2;
    localparam OP_FDIV  = 4'd3;
    localparam OP_FSQRT = 4'd4;
    localparam OP_ITOF  = 4'd5;
    localparam OP_FTOI  = 4'd6;
    localparam OP_FMAC  = 4'd7;

    // FSM States
    localparam S_IDLE       = 4'd0;
    localparam S_UNPACK     = 4'd1;
    localparam S_ADD_ALIGN  = 4'd2;
    localparam S_ADD_CALC   = 4'd3;
    localparam S_ADD_NORM   = 4'd4;
    localparam S_MUL_CALC   = 4'd5;
    localparam S_MUL_NORM   = 4'd6;
    localparam S_DIV_ITER   = 4'd7;
    localparam S_SQRT_ITER  = 4'd8;
    localparam S_CONV       = 4'd9;
    localparam S_MAC_ADD    = 4'd10;
    localparam S_ROUND_PACK = 4'd11;
    localparam S_DONE       = 4'd12;

    reg [3:0] state;

    // Latched inputs
    reg [ 3:0] op_reg;
    reg [31:0] a_reg, b_reg, c_reg;

    // Unpacked fields
    reg        sign_a, sign_b, sign_c;
    reg [ 7:0] exp_a, exp_b, exp_c;
    reg [23:0] mant_a, mant_b, mant_c; // 1.23 format (implicit 1 for normal)
    reg        is_zero_a, is_zero_b, is_zero_c;

    // Intermediate computation registers
    reg        res_sign;
    reg signed [9:0] res_exp;
    reg [50:0] res_mant; // wide mantissa accumulator
    reg [ 5:0] iter_count;

    // Divider registers
    reg [49:0] div_rem;
    reg [26:0] div_quot;
    reg [26:0] div_denom;

    // Square root registers
    reg [51:0] sqrt_radicand;
    reg [25:0] sqrt_root;
    reg [25:0] sqrt_rem;

    // Integer conversion helper
    reg signed [31:0] int_val;

    // Helper functions
    function [5:0] clz48(input [47:0] val);
        integer k;
        reg [5:0] count;
        reg found;
        begin
            count = 6'd0;
            found = 1'b0;
            for (k = 47; k >= 0; k = k - 1) begin
                if (!found && val[k]) begin
                    count = 47 - k;
                    found = 1'b1;
                end
            end
            if (!found) count = 6'd48;
            clz48 = count;
        end
    endfunction

    function [4:0] clz32(input [31:0] val);
        integer k;
        reg [4:0] count;
        reg found;
        begin
            count = 5'd0;
            found = 1'b0;
            for (k = 31; k >= 0; k = k - 1) begin
                if (!found && val[k]) begin
                    count = 31 - k;
                    found = 1'b1;
                end
            end
            if (!found) count = 5'd31;
            clz32 = count;
        end
    endfunction

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            result      <= 32'h00000000;
            done        <= 1'b0;
            busy        <= 1'b0;
            flags       <= 5'b00000;
            op_reg      <= 4'd0;
            a_reg       <= 32'd0;
            b_reg       <= 32'd0;
            c_reg       <= 32'd0;
            res_sign    <= 1'b0;
            res_exp     <= 10'd0;
            res_mant    <= 50'd0;
            iter_count  <= 6'd0;
            div_rem     <= 50'd0;
            div_quot    <= 27'd0;
            div_denom   <= 27'd0;
            sqrt_radicand <= 52'd0;
            sqrt_root   <= 26'd0;
            sqrt_rem    <= 26'd0;
        end else begin
            done <= 1'b0; // default pulse

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy       <= 1'b1;
                        op_reg     <= op;
                        a_reg      <= op_a;
                        b_reg      <= op_b;
                        c_reg      <= op_c;
                        flags      <= 5'b00000;
                        state      <= S_UNPACK;
                    end
                end

                S_UNPACK: begin
                    // Extract fields
                    sign_a    <= a_reg[31];
                    exp_a     <= a_reg[30:23];
                    mant_a    <= (a_reg[30:23] == 8'd0) ? {1'b0, a_reg[22:0]} : {1'b1, a_reg[22:0]};
                    is_zero_a <= (a_reg[30:0] == 31'd0);

                    // For subtraction, invert sign_b
                    sign_b    <= (op_reg == OP_FSUB) ? ~b_reg[31] : b_reg[31];
                    exp_b     <= b_reg[30:23];
                    mant_b    <= (b_reg[30:23] == 8'd0) ? {1'b0, b_reg[22:0]} : {1'b1, b_reg[22:0]};
                    is_zero_b <= (b_reg[30:0] == 31'd0);

                    sign_c    <= c_reg[31];
                    exp_c     <= c_reg[30:23];
                    mant_c    <= (c_reg[30:23] == 8'd0) ? {1'b0, c_reg[22:0]} : {1'b1, c_reg[22:0]};
                    is_zero_c <= (c_reg[30:0] == 31'd0);

                    case (op_reg)
                        OP_FADD, OP_FSUB: begin
                            state <= S_ADD_ALIGN;
                        end

                        OP_FMUL, OP_FMAC: begin
                            state <= S_MUL_CALC;
                        end

                        OP_FDIV: begin
                            if (b_reg[30:0] == 31'd0) begin
                                // Division by zero
                                flags[3] <= 1'b1; // Div by zero
                                if (a_reg[30:0] == 31'd0) begin
                                    result <= 32'h7FC00000; // 0/0 = NaN
                                    flags[4] <= 1'b1;       // Invalid
                                end else begin
                                    result <= {a_reg[31] ^ b_reg[31], 8'hFF, 23'd0}; // Inf
                                end
                                state <= S_DONE;
                            end else if (a_reg[30:0] == 31'd0) begin
                                result <= {a_reg[31] ^ b_reg[31], 31'd0}; // 0.0
                                state <= S_DONE;
                            end else begin
                                res_sign  <= a_reg[31] ^ b_reg[31];
                                res_exp   <= a_reg[30:23] - b_reg[30:23] + 10'd127;
                                div_rem   <= {26'd0, 1'b1, a_reg[22:0]} << 24;
                                div_denom <= {3'd0, 1'b1, b_reg[22:0]};
                                div_quot  <= 27'd0;
                                iter_count<= 6'd26;
                                state     <= S_DIV_ITER;
                            end
                        end

                        OP_FSQRT: begin
                            if (a_reg[31] && (a_reg[30:0] != 31'd0)) begin
                                // Negative sqrt -> NaN
                                flags[4] <= 1'b1; // Invalid op
                                result   <= 32'h7FC00000;
                                state    <= S_DONE;
                            end else if (a_reg[30:0] == 31'd0) begin
                                result <= 32'h00000000;
                                state  <= S_DONE;
                            end else begin
                                res_sign <= 1'b0;
                                // If biased exponent - 127 is odd
                                if (a_reg[23] ^ 1'b1) begin // odd exponent
                                    res_exp       <= ((a_reg[30:23] - 10'd127) >>> 1) + 10'd127;
                                    sqrt_radicand <= {2'b01, a_reg[22:0], 27'd0};
                                end else begin // even exponent
                                    res_exp       <= ((a_reg[30:23] - 10'd127 - 10'd1) >>> 1) + 10'd127;
                                    sqrt_radicand <= {3'b001, a_reg[22:0], 26'd0} << 1;
                                end
                                sqrt_root  <= 26'd0;
                                sqrt_rem   <= 26'd0;
                                iter_count <= 6'd25;
                                state      <= S_SQRT_ITER;
                            end
                        end

                        OP_ITOF, OP_FTOI: begin
                            state <= S_CONV;
                        end

                        default: state <= S_IDLE;
                    endcase
                end

                // -------------------------------------------------------------
                // FADD / FSUB Pipeline
                // -------------------------------------------------------------
                S_ADD_ALIGN: begin
                    if (is_zero_a && is_zero_b) begin
                        result <= 32'h00000000;
                        state  <= S_DONE;
                    end else if (is_zero_a) begin
                        result <= {sign_b, exp_b, mant_b[22:0]};
                        state  <= S_DONE;
                    end else if (is_zero_b) begin
                        result <= {sign_a, exp_a, mant_a[22:0]};
                        state  <= S_DONE;
                    end else begin
                        if (exp_a >= exp_b) begin
                            res_exp  <= exp_a;
                            res_sign <= sign_a;
                            res_mant <= {mant_a, 26'd0};
                            // Shift B
                            if ((exp_a - exp_b) >= 25)
                                mant_b <= 24'd0;
                            else
                                mant_b <= mant_b >> (exp_a - exp_b);
                        end else begin
                            res_exp  <= exp_b;
                            res_sign <= sign_b;
                            res_mant <= {mant_b, 26'd0};
                            // Shift A
                            if ((exp_b - exp_a) >= 25)
                                mant_a <= 24'd0;
                            else
                                mant_a <= mant_a >> (exp_b - exp_a);
                        end
                        state <= S_ADD_CALC;
                    end
                end

                S_ADD_CALC: begin
                    if (exp_a >= exp_b) begin
                        if (sign_a == sign_b) begin
                            res_mant <= res_mant + {mant_b, 26'd0};
                        end else begin
                            if (res_mant >= {mant_b, 26'd0})
                                res_mant <= res_mant - {mant_b, 26'd0};
                            else begin
                                res_mant <= {mant_b, 26'd0} - res_mant;
                                res_sign <= sign_b;
                            end
                        end
                    end else begin
                        if (sign_a == sign_b) begin
                            res_mant <= res_mant + {mant_a, 26'd0};
                        end else begin
                            if (res_mant >= {mant_a, 26'd0})
                                res_mant <= res_mant - {mant_a, 26'd0};
                            else begin
                                res_mant <= {mant_a, 26'd0} - res_mant;
                                res_sign <= sign_a;
                            end
                        end
                    end
                    state <= S_ADD_NORM;
                end

                S_ADD_NORM: begin
                    if (res_mant == 50'd0) begin
                        result <= 32'h00000000;
                        state  <= S_DONE;
                    end else if (res_mant[50]) begin // Carry out of MSB
                        res_mant <= res_mant >> 1;
                        res_exp  <= res_exp + 10'd1;
                        state    <= S_ROUND_PACK;
                    end else if (res_mant[49]) begin // Normalized
                        state <= S_ROUND_PACK;
                    end else begin // Shift left to find leading 1
                        res_mant <= res_mant << 1;
                        res_exp  <= res_exp - 10'd1;
                        // Stay in S_ADD_NORM until bit 49 is set or exp hits 0
                        if (res_exp <= 10'd1) begin
                            state <= S_ROUND_PACK;
                        end
                    end
                end

                // -------------------------------------------------------------
                // FMUL Pipeline
                // -------------------------------------------------------------
                S_MUL_CALC: begin
                    if (is_zero_a || is_zero_b) begin
                        result <= {sign_a ^ sign_b, 31'd0};
                        if (op_reg == OP_FMAC && !is_zero_c) begin
                            result <= {sign_c, exp_c, mant_c[22:0]};
                        end
                        state <= S_DONE;
                    end else begin
                        res_sign <= sign_a ^ sign_b;
                        res_exp  <= exp_a + exp_b - 10'd127;
                        res_mant <= mant_a * mant_b; // 24x24 = 48 bits, stored in res_mant
                        state    <= S_MUL_NORM;
                    end
                end

                S_MUL_NORM: begin
                    if (res_mant[47]) begin
                        res_mant <= res_mant >> 1;
                        res_exp  <= res_exp + 10'd1;
                    end
                    // Align res_mant so implicit 1 is at bit 49
                    res_mant <= res_mant << 3;

                    if (op_reg == OP_FMAC) begin
                        state <= S_MAC_ADD;
                    end else begin
                        state <= S_ROUND_PACK;
                    end
                end

                // -------------------------------------------------------------
                // FMAC Add Step
                // -------------------------------------------------------------
                S_MAC_ADD: begin
                    if (is_zero_c) begin
                        state <= S_ROUND_PACK;
                    end else begin
                        // Prepare addition between (res_sign, res_exp, res_mant) and (sign_c, exp_c, mant_c)
                        if (res_exp >= exp_c) begin
                            if ((res_exp - exp_c) < 26) begin
                                if (res_sign == sign_c)
                                    res_mant <= res_mant + ({mant_c, 26'd0} >> (res_exp - exp_c));
                                else begin
                                    if (res_mant >= ({mant_c, 26'd0} >> (res_exp - exp_c)))
                                        res_mant <= res_mant - ({mant_c, 26'd0} >> (res_exp - exp_c));
                                    else begin
                                        res_mant <= ({mant_c, 26'd0} >> (res_exp - exp_c)) - res_mant;
                                        res_sign <= sign_c;
                                    end
                                end
                            end
                        end else begin
                            if ((exp_c - res_exp) < 26) begin
                                if (res_sign == sign_c)
                                    res_mant <= {mant_c, 26'd0} + (res_mant >> (exp_c - res_exp));
                                else begin
                                    if ({mant_c, 26'd0} >= (res_mant >> (exp_c - res_exp))) begin
                                        res_mant <= {mant_c, 26'd0} - (res_mant >> (exp_c - res_exp));
                                        res_sign <= sign_c;
                                    end else begin
                                        res_mant <= (res_mant >> (exp_c - res_exp)) - {mant_c, 26'd0};
                                    end
                                end
                            end else begin
                                res_mant <= {mant_c, 26'd0};
                                res_sign <= sign_c;
                            end
                            res_exp <= exp_c;
                        end
                        state <= S_ADD_NORM;
                    end
                end

                // -------------------------------------------------------------
                // FDIV Iterative Division
                // -------------------------------------------------------------
                S_DIV_ITER: begin
                    if (div_rem >= {23'd0, div_denom}) begin
                        div_rem  <= (div_rem - {23'd0, div_denom}) << 1;
                        div_quot <= {div_quot[25:0], 1'b1};
                    end else begin
                        div_rem  <= div_rem << 1;
                        div_quot <= {div_quot[25:0], 1'b0};
                    end

                    if (iter_count == 6'd0) begin
                        res_mant <= {div_quot[24:0], 25'd0};
                        state    <= S_ROUND_PACK;
                    end else begin
                        iter_count <= iter_count - 6'd1;
                    end
                end

                // -------------------------------------------------------------
                // FSQRT Iterative Square Root
                // -------------------------------------------------------------
                S_SQRT_ITER: begin
                    // Digit-by-digit square root
                    if ({sqrt_rem[23:0], sqrt_radicand[51:50]} >= {sqrt_root[23:0], 2'b01}) begin
                        sqrt_rem  <= {sqrt_rem[23:0], sqrt_radicand[51:50]} - {sqrt_root[23:0], 2'b01};
                        sqrt_root <= {sqrt_root[24:0], 1'b1};
                    end else begin
                        sqrt_rem  <= {sqrt_rem[23:0], sqrt_radicand[51:50]};
                        sqrt_root <= {sqrt_root[24:0], 1'b0};
                    end
                    sqrt_radicand <= sqrt_radicand << 2;

                    if (iter_count == 6'd0) begin
                        res_mant <= {sqrt_root[23:0], 26'd0};
                        state    <= S_ROUND_PACK;
                    end else begin
                        iter_count <= iter_count - 6'd1;
                    end
                end

                // -------------------------------------------------------------
                // Conversion: ITOF / FTOI
                // -------------------------------------------------------------
                S_CONV: begin
                    if (op_reg == OP_ITOF) begin
                        // Integer to Float
                        if (a_reg == 32'd0) begin
                            result <= 32'h00000000;
                            state  <= S_DONE;
                        end else begin
                            if (a_reg[31]) begin
                                res_sign <= 1'b1;
                                int_val  <= -a_reg;
                            end else begin
                                res_sign <= 1'b0;
                                int_val  <= a_reg;
                            end
                            // Calculate leading zeros of int_val
                            res_exp  <= 10'd127 + 10'd31 - clz32(a_reg[31] ? -a_reg : a_reg);
                            res_mant <= ((a_reg[31] ? -a_reg : a_reg) << (clz32(a_reg[31] ? -a_reg : a_reg))) << 18;
                            state    <= S_ROUND_PACK;
                        end
                    end else begin
                        // Float to Integer (FTOI)
                        if (a_reg[30:23] < 8'd127) begin
                            result <= 32'd0;
                        end else if (a_reg[30:23] >= (8'd127 + 8'd31)) begin
                            // Overflow 32-bit signed int
                            flags[2] <= 1'b1; // Overflow
                            result   <= a_reg[31] ? 32'h80000000 : 32'h7FFFFFFF;
                        end else begin
                            if (a_reg[30:23] - 8'd127 <= 8'd23) begin
                                int_val <= {1'b1, a_reg[22:0]} >> (8'd23 - (a_reg[30:23] - 8'd127));
                            end else begin
                                int_val <= {1'b1, a_reg[22:0]} << ((a_reg[30:23] - 8'd127) - 8'd23);
                            end
                            result <= a_reg[31] ? -int_val : int_val;
                        end
                        state <= S_DONE;
                    end
                end

                // -------------------------------------------------------------
                // Rounding and Packing
                // -------------------------------------------------------------
                S_ROUND_PACK: begin
                    // Check for exponent overflow / underflow
                    if (res_exp >= 10'd255) begin
                        flags[2] <= 1'b1; // Overflow
                        result   <= {res_sign, 8'hFF, 23'd0}; // Infinity
                    end else if (res_exp <= 10'd0) begin
                        flags[1] <= 1'b1; // Underflow
                        result   <= {res_sign, 31'd0}; // Flush to zero
                    end else begin
                        // Round to nearest, ties to even using guard/round bits
                        if (res_mant[25] && (res_mant[26] || (|res_mant[24:0]))) begin
                            result <= {res_sign, res_exp[7:0], res_mant[48:26]} + 1'b1;
                        end else begin
                            result <= {res_sign, res_exp[7:0], res_mant[48:26]};
                        end
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
