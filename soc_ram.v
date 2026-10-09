/*
 * Dual-Port / Single-Cycle Byte-Addressable On-Chip SRAM
 * Pre-initialized with Firmware Instructions + Optional $readmemh override
 */

`timescale 1ns / 1ps

module soc_ram #(
    parameter WORDS = 4096,               // 4096 words * 4 bytes = 16 KB
    parameter INIT_FILE = "firmware.hex"
) (
    input  wire        clk,
    input  wire        rst_n,

    // Bus interface
    input  wire        mem_valid,
    input  wire        mem_instr,
    output reg         mem_ready,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [ 3:0] mem_wstrb,
    output reg  [31:0] mem_rdata
);

    // RAM array: 32 bits wide, WORDS deep
    reg [31:0] mem [0:WORDS-1];

    // Word address: mem_addr[13:2] for 4096 words
    wire [$clog2(WORDS)-1:0] word_addr = mem_addr[$clog2(WORDS)+1:2];

    integer i;
    initial begin
        // 1. Initialize memory array with zeros
        for (i = 0; i < WORDS; i = i + 1) begin
            mem[i] = 32'h00000000;
        end

        // 2. Pre-load embedded rocket flight firmware instructions
        mem[0] = 32'h00004137;
        mem[1] = 32'hffc10113;
        mem[2] = 32'h400002b7;
        mem[3] = 32'h00028293;
        mem[4] = 32'h00000337;
        mem[5] = 32'h00130313;
        mem[6] = 32'h0062a023;
        mem[7] = 32'h00000537;
        mem[8] = 32'h20850513;
        mem[9] = 32'h1b0000ef;
        mem[10] = 32'h00000337;
        mem[11] = 32'h00330313;
        mem[12] = 32'h0062a023;
        mem[13] = 32'h200003b7;
        mem[14] = 32'h00038393;
        mem[15] = 32'h41480e37;
        mem[16] = 32'h000e0e13;
        mem[17] = 32'h01c3a023;
        mem[18] = 32'h40e80e37;
        mem[19] = 32'h000e0e13;
        mem[20] = 32'h01c3a223;
        mem[21] = 32'h00000e37;
        mem[22] = 32'h010e0e13;
        mem[23] = 32'h01c3a623;
        mem[24] = 32'h0103a403;
        mem[25] = 32'h00000537;
        mem[26] = 32'h2f050513;
        mem[27] = 32'h168000ef;
        mem[28] = 32'h40400e37;
        mem[29] = 32'h000e0e13;
        mem[30] = 32'h01c3a023;
        mem[31] = 32'h40900e37;
        mem[32] = 32'h000e0e13;
        mem[33] = 32'h01c3a223;
        mem[34] = 32'h00000e37;
        mem[35] = 32'h012e0e13;
        mem[36] = 32'h01c3a623;
        mem[37] = 32'h0103a483;
        mem[38] = 32'h00000537;
        mem[39] = 32'h31c50513;
        mem[40] = 32'h134000ef;
        mem[41] = 32'h41100e37;
        mem[42] = 32'h000e0e13;
        mem[43] = 32'h01c3a023;
        mem[44] = 32'h00000e37;
        mem[45] = 32'h014e0e13;
        mem[46] = 32'h01c3a623;
        mem[47] = 32'h0103a903;
        mem[48] = 32'h00000537;
        mem[49] = 32'h34450513;
        mem[50] = 32'h10c000ef;
        mem[51] = 32'h3f800e37;
        mem[52] = 32'h000e0e13;
        mem[53] = 32'h01c3a023;
        mem[54] = 32'h01c3a223;
        mem[55] = 32'h00000e37;
        mem[56] = 32'h012e0e13;
        mem[57] = 32'h01c3a623;
        mem[58] = 32'h0103ae83;
        mem[59] = 32'h40000e37;
        mem[60] = 32'h000e0e13;
        mem[61] = 32'h01c3a023;
        mem[62] = 32'h01c3a223;
        mem[63] = 32'h00000e37;
        mem[64] = 32'h012e0e13;
        mem[65] = 32'h01c3a623;
        mem[66] = 32'h0103af03;
        mem[67] = 32'h40000e37;
        mem[68] = 32'h000e0e13;
        mem[69] = 32'h01c3a023;
        mem[70] = 32'h01c3a223;
        mem[71] = 32'h00000e37;
        mem[72] = 32'h012e0e13;
        mem[73] = 32'h01c3a623;
        mem[74] = 32'h0103af83;
        mem[75] = 32'h01d3a023;
        mem[76] = 32'h01e3a223;
        mem[77] = 32'h00000e37;
        mem[78] = 32'h010e0e13;
        mem[79] = 32'h01c3a623;
        mem[80] = 32'h0103a583;
        mem[81] = 32'h00b3a023;
        mem[82] = 32'h01f3a223;
        mem[83] = 32'h00000e37;
        mem[84] = 32'h010e0e13;
        mem[85] = 32'h01c3a623;
        mem[86] = 32'h0103a603;
        mem[87] = 32'h00c3a023;
        mem[88] = 32'h00000e37;
        mem[89] = 32'h014e0e13;
        mem[90] = 32'h01c3a623;
        mem[91] = 32'h0103a983;
        mem[92] = 32'h00000537;
        mem[93] = 32'h36c50513;
        mem[94] = 32'h05c000ef;
        mem[95] = 32'h300006b7;
        mem[96] = 32'h00068693;
        mem[97] = 32'h0006a703;
        mem[98] = 32'h00000537;
        mem[99] = 32'h3a450513;
        mem[100] = 32'h044000ef;
        mem[101] = 32'h00000537;
        mem[102] = 32'h3d450513;
        mem[103] = 32'h038000ef;
        mem[104] = 32'h400002b7;
        mem[105] = 32'h00028293;
        mem[106] = 32'h00000337;
        mem[107] = 32'h05530313;
        mem[108] = 32'h0062a023;
        mem[109] = 32'h0000006f;
        mem[110] = 32'h100002b7;
        mem[111] = 32'h00028293;
        mem[112] = 32'h0042a303;
        mem[113] = 32'h00137313;
        mem[114] = 32'hfe031ce3;
        mem[115] = 32'h00a2a023;
        mem[116] = 32'h00008067;
        mem[117] = 32'hff810113;
        mem[118] = 32'h00112223;
        mem[119] = 32'h00812023;
        mem[120] = 32'h00050413;
        mem[121] = 32'h00040503;
        mem[122] = 32'h00050863;
        mem[123] = 32'hfcdff0ef;
        mem[124] = 32'h00140413;
        mem[125] = 32'hff1ff06f;
        mem[126] = 32'h00012403;
        mem[127] = 32'h00412083;
        mem[128] = 32'h00810113;
        mem[129] = 32'h00008067;
        mem[130] = 32'h3d3d0a0d;
        mem[131] = 32'h3d3d3d3d;
        mem[132] = 32'h3d3d3d3d;
        mem[133] = 32'h3d3d3d3d;
        mem[134] = 32'h3d3d3d3d;
        mem[135] = 32'h3d3d3d3d;
        mem[136] = 32'h3d3d3d3d;
        mem[137] = 32'h3d3d3d3d;
        mem[138] = 32'h3d3d3d3d;
        mem[139] = 32'h3d3d3d3d;
        mem[140] = 32'h3d3d3d3d;
        mem[141] = 32'h3d3d3d3d;
        mem[142] = 32'h3d3d3d3d;
        mem[143] = 32'h3d3d3d3d;
        mem[144] = 32'h415b0a0d;
        mem[145] = 32'h534f5245;
        mem[146] = 32'h45434150;
        mem[147] = 32'h434f532d;
        mem[148] = 32'h4950205d;
        mem[149] = 32'h522d4f43;
        mem[150] = 32'h49323356;
        mem[151] = 32'h202b204d;
        mem[152] = 32'h45454549;
        mem[153] = 32'h3435372d;
        mem[154] = 32'h55504620;
        mem[155] = 32'h49564120;
        mem[156] = 32'h43494e4f;
        mem[157] = 32'h4f422053;
        mem[158] = 32'h0a0d544f;
        mem[159] = 32'h5245415b;
        mem[160] = 32'h4150534f;
        mem[161] = 32'h532d4543;
        mem[162] = 32'h205d434f;
        mem[163] = 32'h63617053;
        mem[164] = 32'h61726365;
        mem[165] = 32'h54207466;
        mem[166] = 32'h6d656c65;
        mem[167] = 32'h79727465;
        mem[168] = 32'h4e202620;
        mem[169] = 32'h67697661;
        mem[170] = 32'h6f697461;
        mem[171] = 32'h6f43206e;
        mem[172] = 32'h0a0d6572;
        mem[173] = 32'h3d3d3d3d;
        mem[174] = 32'h3d3d3d3d;
        mem[175] = 32'h3d3d3d3d;
        mem[176] = 32'h3d3d3d3d;
        mem[177] = 32'h3d3d3d3d;
        mem[178] = 32'h3d3d3d3d;
        mem[179] = 32'h3d3d3d3d;
        mem[180] = 32'h3d3d3d3d;
        mem[181] = 32'h3d3d3d3d;
        mem[182] = 32'h3d3d3d3d;
        mem[183] = 32'h3d3d3d3d;
        mem[184] = 32'h3d3d3d3d;
        mem[185] = 32'h3d3d3d3d;
        mem[186] = 32'h0a0d3d3d;
        mem[187] = 32'h00000000;
        mem[188] = 32'h5550465b;
        mem[189] = 32'h4146205d;
        mem[190] = 32'h203a4444;
        mem[191] = 32'h53534150;
        mem[192] = 32'h32312820;
        mem[193] = 32'h2b20352e;
        mem[194] = 32'h322e3720;
        mem[195] = 32'h203d2035;
        mem[196] = 32'h372e3931;
        mem[197] = 32'h0a0d2935;
        mem[198] = 32'h00000000;
        mem[199] = 32'h5550465b;
        mem[200] = 32'h4d46205d;
        mem[201] = 32'h203a4c55;
        mem[202] = 32'h53534150;
        mem[203] = 32'h2e332820;
        mem[204] = 32'h202a2030;
        mem[205] = 32'h20352e34;
        mem[206] = 32'h3331203d;
        mem[207] = 32'h0d29352e;
        mem[208] = 32'h0000000a;
        mem[209] = 32'h5550465b;
        mem[210] = 32'h5346205d;
        mem[211] = 32'h3a545251;
        mem[212] = 32'h53415020;
        mem[213] = 32'h73282053;
        mem[214] = 32'h28747271;
        mem[215] = 32'h29302e39;
        mem[216] = 32'h33203d20;
        mem[217] = 32'h0d29302e;
        mem[218] = 32'h0000000a;
        mem[219] = 32'h4d4c545b;
        mem[220] = 32'h4433205d;
        mem[221] = 32'h56414e20;
        mem[222] = 32'h43434120;
        mem[223] = 32'h4e204c45;
        mem[224] = 32'h204d524f;
        mem[225] = 32'h2e33203d;
        mem[226] = 32'h2f6d2030;
        mem[227] = 32'h20325e73;
        mem[228] = 32'h434f4c5b;
        mem[229] = 32'h4341204b;
        mem[230] = 32'h56454948;
        mem[231] = 32'h0d5d4445;
        mem[232] = 32'h0000000a;
        mem[233] = 32'h4d4c545b;
        mem[234] = 32'h494d205d;
        mem[235] = 32'h4f495353;
        mem[236] = 32'h4954204e;
        mem[237] = 32'h2052454d;
        mem[238] = 32'h4b434954;
        mem[239] = 32'h50414320;
        mem[240] = 32'h45525554;
        mem[241] = 32'h415b2044;
        mem[242] = 32'h56495443;
        mem[243] = 32'h0a0d5d45;
        mem[244] = 32'h00000000;
        mem[245] = 32'h3d3d3d3d;
        mem[246] = 32'h3d3d3d3d;
        mem[247] = 32'h3d3d3d3d;
        mem[248] = 32'h3d3d3d3d;
        mem[249] = 32'h3d3d3d3d;
        mem[250] = 32'h3d3d3d3d;
        mem[251] = 32'h3d3d3d3d;
        mem[252] = 32'h3d3d3d3d;
        mem[253] = 32'h3d3d3d3d;
        mem[254] = 32'h3d3d3d3d;
        mem[255] = 32'h3d3d3d3d;
        mem[256] = 32'h3d3d3d3d;
        mem[257] = 32'h3d3d3d3d;
        mem[258] = 32'h0a0d3d3d;
        mem[259] = 32'h5245415b;
        mem[260] = 32'h4150534f;
        mem[261] = 32'h532d4543;
        mem[262] = 32'h205d434f;
        mem[263] = 32'h204c4c41;
        mem[264] = 32'h47494c46;
        mem[265] = 32'h53205448;
        mem[266] = 32'h45545359;
        mem[267] = 32'h4e20534d;
        mem[268] = 32'h4e494d4f;
        mem[269] = 32'h202e4c41;
        mem[270] = 32'h454c4554;
        mem[271] = 32'h5254454d;
        mem[272] = 32'h4b4f2059;
        mem[273] = 32'h3d3d0a0d;
        mem[274] = 32'h3d3d3d3d;
        mem[275] = 32'h3d3d3d3d;
        mem[276] = 32'h3d3d3d3d;
        mem[277] = 32'h3d3d3d3d;
        mem[278] = 32'h3d3d3d3d;
        mem[279] = 32'h3d3d3d3d;
        mem[280] = 32'h3d3d3d3d;
        mem[281] = 32'h3d3d3d3d;
        mem[282] = 32'h3d3d3d3d;
        mem[283] = 32'h3d3d3d3d;
        mem[284] = 32'h3d3d3d3d;
        mem[285] = 32'h3d3d3d3d;
        mem[286] = 32'h3d3d3d3d;
        mem[287] = 32'h00000a0d;

        // 3. Optional $readmemh override if external file is present
        $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;
        end else begin
            mem_ready <= 1'b0;
            if (mem_valid && !mem_ready) begin
                if (mem_wstrb[0]) mem[word_addr][ 7: 0] <= mem_wdata[ 7: 0];
                if (mem_wstrb[1]) mem[word_addr][15: 8] <= mem_wdata[15: 8];
                if (mem_wstrb[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) mem[word_addr][31:24] <= mem_wdata[31:24];

                mem_rdata <= mem[word_addr];
                mem_ready <= 1'b1;
            end
        end
    end

endmodule
