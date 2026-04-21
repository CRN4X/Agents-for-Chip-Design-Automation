`timescale 1ns/1ns

module aes128_decrypt #(
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

localparam NBW_BYTE    = 'd8;
localparam NBW_EX_KEY  = 'd1408;
localparam ROUND_IDLE  = 4'd0;
localparam ROUND_WAITK = 4'd12;

logic [NBW_BYTE-1:0]   current_data_nx[4][4];
logic [NBW_BYTE-1:0]   current_data_ff[4][4];
logic [NBW_BYTE-1:0]   inv_shift_rows[4][4];
logic [NBW_BYTE-1:0]   inv_sub_bytes[4][4];
logic [NBW_BYTE-1:0]   add_round_key[4][4];
logic [NBW_BYTE-1:0]   mix_columns[4][4];
logic [3:0]            round_ff;
logic [NBW_DATA-1:0]   data_pending_ff;
logic                  key_done;
logic [NBW_EX_KEY-1:0] expanded_key;

function automatic [7:0] gf_xtime(input [7:0] a);
    begin
        gf_xtime = {a[6:0], 1'b0} ^ (8'h1B & {8{a[7]}});
    end
endfunction

function automatic [7:0] gf_mul(input [7:0] a, input [7:0] b);
    logic [7:0] aa;
    logic [7:0] bb;
    logic [7:0] p;
    begin
        aa = a;
        bb = b;
        p  = 8'h00;
        for (int k = 0; k < 8; k++) begin
            if (bb[0]) begin
                p = p ^ aa;
            end
            aa = gf_xtime(aa);
            bb = bb >> 1;
        end
        gf_mul = p;
    end
endfunction

function automatic [7:0] get_round_key_byte(
    input [NBW_EX_KEY-1:0] key_bus,
    input int              round_idx,
    input int              row_idx,
    input int              col_idx
);
    begin
        get_round_key_byte = key_bus[NBW_EX_KEY-round_idx*NBW_KEY-(4*col_idx+row_idx)*NBW_BYTE-1-:NBW_BYTE];
    end
endfunction

assign o_done = (round_ff == ROUND_IDLE);

generate
    for (genvar i = 0; i < 4; i++) begin : out_row
        for (genvar j = 0; j < 4; j++) begin : out_col
            assign o_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] = current_data_ff[i][j];
        end
    end
endgenerate

always_ff @(posedge clk or negedge rst_async_n) begin : inv_cipher_regs
    if (!rst_async_n) begin
        round_ff        <= ROUND_IDLE;
        data_pending_ff <= '0;
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= 8'h00;
            end
        end
    end else begin
        if ((round_ff == ROUND_IDLE) && i_start) begin
            data_pending_ff <= i_data;
        end

        case (round_ff)
            ROUND_IDLE: begin
                if (i_start) begin
                    if (i_update_key) begin
                        round_ff <= ROUND_WAITK;
                    end else begin
                        round_ff <= 4'd1;
                    end
                end
            end
            ROUND_WAITK: begin
                if (key_done) begin
                    round_ff <= 4'd1;
                end
            end
            4'd1, 4'd2, 4'd3, 4'd4, 4'd5,
            4'd6, 4'd7, 4'd8, 4'd9, 4'd10: begin
                round_ff <= round_ff + 1'b1;
            end
            4'd11: begin
                round_ff <= ROUND_IDLE;
            end
            default: begin
                round_ff <= ROUND_IDLE;
            end
        endcase

        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= current_data_nx[i][j];
            end
        end
    end
end

always_comb begin : next_data
    for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
            current_data_nx[i][j] = current_data_ff[i][j];

            if ((round_ff == ROUND_IDLE) && i_start && !i_update_key) begin
                current_data_nx[i][j] = i_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
            end else if ((round_ff == ROUND_WAITK) && key_done) begin
                current_data_nx[i][j] = data_pending_ff[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
            end else if (round_ff == 4'd1) begin
                current_data_nx[i][j] = add_round_key[i][j];
            end else if ((round_ff >= 4'd2) && (round_ff <= 4'd10)) begin
                current_data_nx[i][j] = mix_columns[i][j];
            end else if (round_ff == 4'd11) begin
                current_data_nx[i][j] = add_round_key[i][j];
            end
        end
    end
end

always_comb begin : inv_shift_rows_logic
    for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
            inv_shift_rows[i][j] = current_data_ff[i][j];
        end
    end

    inv_shift_rows[1][0] = current_data_ff[1][3];
    inv_shift_rows[1][1] = current_data_ff[1][0];
    inv_shift_rows[1][2] = current_data_ff[1][1];
    inv_shift_rows[1][3] = current_data_ff[1][2];

    inv_shift_rows[2][0] = current_data_ff[2][2];
    inv_shift_rows[2][1] = current_data_ff[2][3];
    inv_shift_rows[2][2] = current_data_ff[2][0];
    inv_shift_rows[2][3] = current_data_ff[2][1];

    inv_shift_rows[3][0] = current_data_ff[3][1];
    inv_shift_rows[3][1] = current_data_ff[3][2];
    inv_shift_rows[3][2] = current_data_ff[3][3];
    inv_shift_rows[3][3] = current_data_ff[3][0];
end

generate
    for (genvar i = 0; i < 4; i++) begin : row
        for (genvar j = 0; j < 4; j++) begin : col
            inv_sbox u_inv_sbox (
                .i_data(inv_shift_rows[i][j]),
                .o_data(inv_sub_bytes[i][j])
            );
        end
    end
endgenerate

always_comb begin : round_logic
    int key_round;

    for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
            add_round_key[i][j] = 8'h00;
            mix_columns[i][j]   = 8'h00;
        end
    end

    if (round_ff == 4'd1) begin
        key_round = 10;
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                add_round_key[i][j] = current_data_ff[i][j] ^ get_round_key_byte(expanded_key, key_round, i, j);
            end
        end
    end else if ((round_ff >= 4'd2) && (round_ff <= 4'd11)) begin
        key_round = 11 - round_ff;
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                add_round_key[i][j] = inv_sub_bytes[i][j] ^ get_round_key_byte(expanded_key, key_round, i, j);
            end
        end

        if (round_ff <= 4'd10) begin
            for (int c = 0; c < 4; c++) begin
                mix_columns[0][c] = gf_mul(add_round_key[0][c], 8'h0E) ^ gf_mul(add_round_key[1][c], 8'h0B) ^
                                    gf_mul(add_round_key[2][c], 8'h0D) ^ gf_mul(add_round_key[3][c], 8'h09);
                mix_columns[1][c] = gf_mul(add_round_key[0][c], 8'h09) ^ gf_mul(add_round_key[1][c], 8'h0E) ^
                                    gf_mul(add_round_key[2][c], 8'h0B) ^ gf_mul(add_round_key[3][c], 8'h0D);
                mix_columns[2][c] = gf_mul(add_round_key[0][c], 8'h0D) ^ gf_mul(add_round_key[1][c], 8'h09) ^
                                    gf_mul(add_round_key[2][c], 8'h0E) ^ gf_mul(add_round_key[3][c], 8'h0B);
                mix_columns[3][c] = gf_mul(add_round_key[0][c], 8'h0B) ^ gf_mul(add_round_key[1][c], 8'h0D) ^
                                    gf_mul(add_round_key[2][c], 8'h09) ^ gf_mul(add_round_key[3][c], 8'h0E);
            end
        end
    end
end

aes128_key_expansion u_aes128_key_expansion (
    .clk            (clk),
    .rst_async_n    (rst_async_n),
    .i_start        (i_start & i_update_key & o_done),
    .i_key          (i_key),
    .o_done         (key_done),
    .o_expanded_key (expanded_key)
);

endmodule : aes128_decrypt
