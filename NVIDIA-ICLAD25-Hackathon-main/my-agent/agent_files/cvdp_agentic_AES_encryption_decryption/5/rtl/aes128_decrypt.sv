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

// ----------------------------------------
// - Internal Parameters
// ----------------------------------------
localparam NBW_BYTE   = 'd8;
localparam NBW_EX_KEY = 'd1408;

// ----------------------------------------
// - Wires/Registers
// ----------------------------------------
logic [NBW_BYTE-1:0] current_data_ff [0:3][0:3];
logic [NBW_BYTE-1:0] current_data_nx [0:3][0:3];
logic [NBW_BYTE-1:0] add_round_init  [0:3][0:3];
logic [NBW_BYTE-1:0] shift_rows      [0:3][0:3];
logic [NBW_BYTE-1:0] sub_bytes       [0:3][0:3];
logic [NBW_BYTE-1:0] add_round_main  [0:3][0:3];
logic [NBW_BYTE-1:0] mix_columns     [0:3][0:3];

logic [3:0]            round_ff;
logic [NBW_EX_KEY-1:0] expanded_key;
logic [NBW_DATA-1:0]   data_latched_ff;
logic                  pending_key_ff;
logic                  key_done;

function automatic [7:0] xtime(input [7:0] a);
    xtime = {a[6:0], 1'b0} ^ (8'h1B & {8{a[7]}});
endfunction

function automatic [7:0] gmul(input [7:0] a, input [7:0] b);
    logic [7:0] aa;
    logic [7:0] bb;
    logic [7:0] p;
    begin
        aa = a;
        bb = b;
        p  = 8'h00;

        for(int k = 0; k < 8; k++) begin
            if(bb[0]) begin
                p = p ^ aa;
            end
            aa = xtime(aa);
            bb = {1'b0, bb[7:1]};
        end

        gmul = p;
    end
endfunction

// ----------------------------------------
// - Output assignment
// ----------------------------------------
assign o_done = (round_ff == 4'd0) && !pending_key_ff;

generate
    for(genvar i = 0; i < 4; i++) begin : out_row
        for(genvar j = 0; j < 4; j++) begin : out_col
            assign o_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] = current_data_ff[i][j];
        end
    end
endgenerate

// ----------------------------------------
// - InvSubBytes lookup
// ----------------------------------------
generate
    for(genvar i = 0; i < 4; i++) begin : row
        for(genvar j = 0; j < 4; j++) begin : col
            inv_sbox uu_inv_sbox (
                .i_data(shift_rows[i][j]),
                .o_data(sub_bytes[i][j])
            );
        end
    end
endgenerate

// ----------------------------------------
// - Combinational decrypt datapath
// ----------------------------------------
always_comb begin : decrypt_logic
    int round_idx;

    // Inverse ShiftRows on current state
    shift_rows[0][0] = current_data_ff[0][0];
    shift_rows[0][1] = current_data_ff[0][1];
    shift_rows[0][2] = current_data_ff[0][2];
    shift_rows[0][3] = current_data_ff[0][3];

    shift_rows[1][0] = current_data_ff[1][3];
    shift_rows[1][1] = current_data_ff[1][0];
    shift_rows[1][2] = current_data_ff[1][1];
    shift_rows[1][3] = current_data_ff[1][2];

    shift_rows[2][0] = current_data_ff[2][2];
    shift_rows[2][1] = current_data_ff[2][3];
    shift_rows[2][2] = current_data_ff[2][0];
    shift_rows[2][3] = current_data_ff[2][1];

    shift_rows[3][0] = current_data_ff[3][1];
    shift_rows[3][1] = current_data_ff[3][2];
    shift_rows[3][2] = current_data_ff[3][3];
    shift_rows[3][3] = current_data_ff[3][0];

    round_idx = (round_ff == 4'd11) ? 0 : (11 - round_ff);

    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            add_round_init[i][j] = current_data_ff[i][j] ^ expanded_key[NBW_EX_KEY-10*NBW_KEY-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
            add_round_main[i][j] = sub_bytes[i][j] ^ expanded_key[NBW_EX_KEY-round_idx*NBW_KEY-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
        end
    end

    for(int c = 0; c < 4; c++) begin
        mix_columns[0][c] = gmul(add_round_main[0][c], 8'h0E) ^ gmul(add_round_main[1][c], 8'h0B) ^ gmul(add_round_main[2][c], 8'h0D) ^ gmul(add_round_main[3][c], 8'h09);
        mix_columns[1][c] = gmul(add_round_main[0][c], 8'h09) ^ gmul(add_round_main[1][c], 8'h0E) ^ gmul(add_round_main[2][c], 8'h0B) ^ gmul(add_round_main[3][c], 8'h0D);
        mix_columns[2][c] = gmul(add_round_main[0][c], 8'h0D) ^ gmul(add_round_main[1][c], 8'h09) ^ gmul(add_round_main[2][c], 8'h0E) ^ gmul(add_round_main[3][c], 8'h0B);
        mix_columns[3][c] = gmul(add_round_main[0][c], 8'h0B) ^ gmul(add_round_main[1][c], 8'h0D) ^ gmul(add_round_main[2][c], 8'h09) ^ gmul(add_round_main[3][c], 8'h0E);
    end

    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            current_data_nx[i][j] = current_data_ff[i][j];

            if(round_ff == 4'd1) begin
                current_data_nx[i][j] = add_round_init[i][j];
            end else if(round_ff >= 4'd2 && round_ff <= 4'd10) begin
                current_data_nx[i][j] = mix_columns[i][j];
            end else if(round_ff == 4'd11) begin
                current_data_nx[i][j] = add_round_main[i][j];
            end
        end
    end
end

// ----------------------------------------
// - Sequential control/data
// ----------------------------------------
always_ff @(posedge clk or negedge rst_async_n) begin : decrypt_regs
    if(!rst_async_n) begin
        round_ff       <= 4'd0;
        data_latched_ff <= '0;
        pending_key_ff <= 1'b0;

        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= 8'd0;
            end
        end
    end else begin
        if(i_start && o_done) begin
            data_latched_ff <= i_data;

            if(i_update_key) begin
                pending_key_ff <= 1'b1;
                round_ff       <= 4'd0;
            end else begin
                pending_key_ff <= 1'b0;
                round_ff       <= 4'd1;

                for(int i = 0; i < 4; i++) begin
                    for(int j = 0; j < 4; j++) begin
                        current_data_ff[i][j] <= i_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
                    end
                end
            end
        end else if(pending_key_ff) begin
            if(key_done) begin
                pending_key_ff <= 1'b0;
                round_ff       <= 4'd1;

                for(int i = 0; i < 4; i++) begin
                    for(int j = 0; j < 4; j++) begin
                        current_data_ff[i][j] <= data_latched_ff[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE];
                    end
                end
            end
        end else if(round_ff != 4'd0) begin
            for(int i = 0; i < 4; i++) begin
                for(int j = 0; j < 4; j++) begin
                    current_data_ff[i][j] <= current_data_nx[i][j];
                end
            end

            if(round_ff == 4'd11) begin
                round_ff <= 4'd0;
            end else begin
                round_ff <= round_ff + 1'b1;
            end
        end
    end
end

aes128_key_expansion uu_aes128_key_expansion (
    .clk            (clk),
    .rst_async_n    (rst_async_n),
    .i_start        (i_start & i_update_key & o_done),
    .i_key          (i_key),
    .o_done         (key_done),
    .o_expanded_key (expanded_key)
);

endmodule : aes128_decrypt
