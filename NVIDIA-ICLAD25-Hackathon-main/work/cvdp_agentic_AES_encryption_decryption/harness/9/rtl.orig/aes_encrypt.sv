module aes_encrypt #(
    parameter NBW_KEY  = 'd128,
    parameter NBW_DATA = 'd128
) (
    input  logic                clk,
    input  logic                rst_async_n,
    input  logic                i_update_key,
    input  logic [NBW_KEY-1:0]  i_key,
    input  logic                i_start,
    input  logic [NBW_DATA-1:0] i_data,
    output logic                o_done,
    output logic [NBW_DATA-1:0] o_data
);

// ----------------------------------------
// - Internal Parameters
// ----------------------------------------
localparam NBW_BYTE   = 'd8;
localparam STEPS      = 'd10;
localparam NBW_WORD   = 'd32;
localparam NBW_EX_KEY = 'd1408;

// ----------------------------------------
// - Wires/Registers creation
// ----------------------------------------
logic [NBW_BYTE-1:0]   Rcon   [STEPS];
logic [NBW_KEY-1:0]    valid_key;
logic [NBW_KEY-1:0]    step_key[STEPS];
logic [NBW_EX_KEY-1:0] expanded_key_nx;
logic [NBW_EX_KEY-1:0] expanded_key_ff;
logic [NBW_BYTE-1:0]   current_data_nx[4][4];
logic [NBW_BYTE-1:0]   current_data_ff[4][4];
logic [NBW_BYTE-1:0]   SubBytes[4][4];
logic [NBW_BYTE-1:0]   ShiftRows[4][4];
logic [NBW_BYTE-1:0]   xtimes02[4][4];
logic [NBW_BYTE-1:0]   xtimes03[4][4];
logic [NBW_BYTE-1:0]   MixColumns[4][4];
logic [3:0] round_ff;

// ----------------------------------------
// - Output assignment
// ----------------------------------------
assign o_done = (round_ff == 4'd0);

generate
    for(genvar i = 0; i < 4; i++) begin : out_row
        for(genvar j = 0; j < 4; j++) begin : out_col
            assign o_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] = current_data_ff[i][j];
        end
    end
endgenerate

always_ff @(posedge clk or negedge rst_async_n) begin : cypher_regs
    if(!rst_async_n) begin
        round_ff <= 4'd0;
        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= 8'd0;
            end
        end
    end else begin
        if(i_start & o_done || (round_ff > 4'd0 && round_ff < 4'd11)) begin
            round_ff <= round_ff + 1'b1;
        end else begin
            round_ff <= 4'd0;
        end

        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= current_data_nx[i][j];
            end
        end
    end
end

always_comb begin : next_data
    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            if(i_start & o_done) begin
                if(i_update_key) begin
                    current_data_nx[i][j] = i_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] ^ i_key[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
                end else begin
                    current_data_nx[i][j] = i_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] ^ expanded_key_ff[NBW_EX_KEY-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
                end
            end else begin
                if(round_ff > 4'd1) begin
                    if(round_ff != 11) begin
                        current_data_nx[i][j] = MixColumns[i][j] ^ expanded_key_ff[NBW_EX_KEY-(round_ff-1)*NBW_KEY-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
                    end else begin
                        current_data_nx[i][j] = ShiftRows[i][j] ^ expanded_key_ff[NBW_EX_KEY-(round_ff-1)*NBW_KEY-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
                    end
                end else begin
                    current_data_nx[i][j] = current_data_ff[i][j];
                end
            end
        end
    end
end

generate
    for(genvar i = 0; i < 4; i++) begin : row
        for(genvar j = 0; j < 4; j++) begin : col
            sbox uu_sbox0 (
                .i_data(current_data_ff[i][j]),
                .o_data(SubBytes[i][j])
            );
        end
    end
endgenerate

always_comb begin : cypher_logic
    // Shift Rows logic
    // Line 0: No shift
    ShiftRows[0][0] = SubBytes[0][0];
    ShiftRows[0][1] = SubBytes[0][1];
    ShiftRows[0][2] = SubBytes[0][2];
    ShiftRows[0][3] = SubBytes[0][3];

    // Line 1: Shift 1 left
    ShiftRows[1][0] = SubBytes[1][1];
    ShiftRows[1][1] = SubBytes[1][2];
    ShiftRows[1][2] = SubBytes[1][3];
    ShiftRows[1][3] = SubBytes[1][0];

    // Line 2: Shift 2 left
    ShiftRows[2][0] = SubBytes[2][2];
    ShiftRows[2][1] = SubBytes[2][3];
    ShiftRows[2][2] = SubBytes[2][0];
    ShiftRows[2][3] = SubBytes[2][1];

    // Line 3: Shift 3 left
    ShiftRows[3][0] = SubBytes[3][3];
    ShiftRows[3][1] = SubBytes[3][0];
    ShiftRows[3][2] = SubBytes[3][1];
    ShiftRows[3][3] = SubBytes[3][2];

    // Mix Columns logic
    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            if(ShiftRows[i][j][NBW_BYTE-1]) begin
                xtimes02[i][j] = {ShiftRows[i][j][NBW_BYTE-2:0], 1'b0} ^ 8'h1B;
                xtimes03[i][j] = {ShiftRows[i][j][NBW_BYTE-2:0], 1'b0} ^ 8'h1B ^ ShiftRows[i][j];
            end else begin
                xtimes02[i][j] = {ShiftRows[i][j][NBW_BYTE-2:0], 1'b0};
                xtimes03[i][j] = {ShiftRows[i][j][NBW_BYTE-2:0], 1'b0} ^ ShiftRows[i][j];
            end
        end
    end

    for(int i = 0; i < 4; i++) begin
        MixColumns[0][i] = xtimes02[0][i] ^ xtimes03[1][i] ^ ShiftRows[2][i] ^ ShiftRows[3][i];
        MixColumns[1][i] = xtimes02[1][i] ^ xtimes03[2][i] ^ ShiftRows[3][i] ^ ShiftRows[0][i];
        MixColumns[2][i] = xtimes02[2][i] ^ xtimes03[3][i] ^ ShiftRows[0][i] ^ ShiftRows[1][i];
        MixColumns[3][i] = xtimes02[3][i] ^ xtimes03[0][i] ^ ShiftRows[1][i] ^ ShiftRows[2][i];
    end
end

// ****************************************
// - Key Expansion logic
// ****************************************

// ----------------------------------------
// - Registers
// ----------------------------------------
always_ff @(posedge clk or negedge rst_async_n) begin : reset_regs
    if(~rst_async_n) begin
        expanded_key_ff <= {NBW_EX_KEY{1'b0}};
    end else begin
        expanded_key_ff <= expanded_key_nx;
    end
end


// ----------------------------------------
// - Operation logic
// ----------------------------------------
assign Rcon[0] = 8'h01;
assign Rcon[1] = 8'h02;
assign Rcon[2] = 8'h04;
assign Rcon[3] = 8'h08;
assign Rcon[4] = 8'h10;
assign Rcon[5] = 8'h20;
assign Rcon[6] = 8'h40;
assign Rcon[7] = 8'h80;
assign Rcon[8] = 8'h1b;
assign Rcon[9] = 8'h36;

generate
    for(genvar i = 0; i < STEPS; i++) begin : steps
        logic [NBW_WORD-1:0] RotWord;
        logic [NBW_WORD-1:0] SubWord;
        logic [NBW_WORD-1:0] RconXor;

        sbox uu_sbox0 (
            .i_data(RotWord[NBW_WORD-1-:NBW_BYTE]),
            .o_data(SubWord[NBW_WORD-1-:NBW_BYTE])
        );

        sbox uu_sbox1 (
            .i_data(RotWord[NBW_WORD-NBW_BYTE-1-:NBW_BYTE]),
            .o_data(SubWord[NBW_WORD-NBW_BYTE-1-:NBW_BYTE])
        );

        sbox uu_sbox2 (
            .i_data(RotWord[NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE]),
            .o_data(SubWord[NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE])
        );

        sbox uu_sbox3 (
            .i_data(RotWord[NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE]),
            .o_data(SubWord[NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE])
        );

        always_comb begin : main_operation
            RotWord = {expanded_key_ff[NBW_EX_KEY-(i+1)*NBW_KEY+NBW_WORD-NBW_BYTE-1-:(NBW_WORD-NBW_BYTE)], expanded_key_ff[NBW_EX_KEY-(i+1)*NBW_KEY+NBW_WORD-1-:NBW_BYTE]};
            RconXor = {SubWord[NBW_WORD-1-:NBW_BYTE]^Rcon[i], SubWord[NBW_WORD-NBW_BYTE-1-:(NBW_WORD-NBW_BYTE)]};

            step_key[i][NBW_KEY-1-:NBW_WORD]            = expanded_key_ff[NBW_EX_KEY-(4*i  )*NBW_WORD-1-:NBW_WORD] ^ RconXor;
            step_key[i][NBW_KEY-NBW_WORD-1-:NBW_WORD]   = expanded_key_ff[NBW_EX_KEY-(4*i+1)*NBW_WORD-1-:NBW_WORD] ^ step_key[i][NBW_KEY-1-:NBW_WORD];
            step_key[i][NBW_KEY-2*NBW_WORD-1-:NBW_WORD] = expanded_key_ff[NBW_EX_KEY-(4*i+2)*NBW_WORD-1-:NBW_WORD] ^ step_key[i][NBW_KEY-NBW_WORD-1-:NBW_WORD];
            step_key[i][NBW_KEY-3*NBW_WORD-1-:NBW_WORD] = expanded_key_ff[NBW_EX_KEY-(4*i+3)*NBW_WORD-1-:NBW_WORD] ^ step_key[i][NBW_KEY-2*NBW_WORD-1-:NBW_WORD];
        end
    end
endgenerate

assign expanded_key_nx = {valid_key  , step_key[0], step_key[1], step_key[2],
                          step_key[3], step_key[4], step_key[5], step_key[6],
                          step_key[7], step_key[8], step_key[9]};

always_comb begin : input_data
    if (i_update_key & o_done) begin
        valid_key = i_key;
    end else begin
        valid_key = expanded_key_ff[NBW_EX_KEY-1-:NBW_KEY];
    end
end

endmodule : aes_encrypt