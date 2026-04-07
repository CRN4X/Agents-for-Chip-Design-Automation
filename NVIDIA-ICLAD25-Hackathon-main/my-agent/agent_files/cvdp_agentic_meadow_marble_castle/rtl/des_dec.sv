module des_dec #(
    parameter NBW_DATA = 'd64,
    parameter NBW_KEY  = 'd64
) (
    input  logic              clk,
    input  logic              rst_async_n,
    input  logic              i_valid,
    input  logic [1:NBW_DATA] i_data,
    input  logic [1:NBW_KEY]  i_key,
    output logic              o_valid,
    output logic [1:NBW_DATA] o_data
);

localparam ROUNDS = 'd16;
localparam EXPANDED_BLOCK = 'd48;
localparam USED_KEY = 'd56;

logic [1:(NBW_DATA/2)] L16;
logic [1:(NBW_DATA/2)] R16;
logic [1:(NBW_DATA/2)] L_ff [0:ROUNDS-1];
logic [1:(NBW_DATA/2)] R_ff [0:ROUNDS-1];
logic [1:(USED_KEY/2)] C16;
logic [1:(USED_KEY/2)] D16;
logic [1:(USED_KEY/2)] C_ff [0:ROUNDS-1];
logic [1:(USED_KEY/2)] D_ff [0:ROUNDS-1];
logic [1:NBW_DATA]     last_perm;
logic [ROUNDS-1:0]     valid_ff;

always_ff @ (posedge clk or negedge rst_async_n) begin
    if(!rst_async_n) begin
        valid_ff <= 0;
    end else begin
        valid_ff <= {valid_ff[ROUNDS-2:0], i_valid};
    end
end

assign o_valid = valid_ff[ROUNDS-1];

assign R16 = {i_data[58], i_data[50], i_data[42], i_data[34], i_data[26], i_data[18], i_data[10], i_data[2],
              i_data[60], i_data[52], i_data[44], i_data[36], i_data[28], i_data[20], i_data[12], i_data[4],
              i_data[62], i_data[54], i_data[46], i_data[38], i_data[30], i_data[22], i_data[14], i_data[6],
              i_data[64], i_data[56], i_data[48], i_data[40], i_data[32], i_data[24], i_data[16], i_data[8]};

assign L16 = {i_data[57], i_data[49], i_data[41], i_data[33], i_data[25], i_data[17], i_data[ 9], i_data[1],
              i_data[59], i_data[51], i_data[43], i_data[35], i_data[27], i_data[19], i_data[11], i_data[3],
              i_data[61], i_data[53], i_data[45], i_data[37], i_data[29], i_data[21], i_data[13], i_data[5],
              i_data[63], i_data[55], i_data[47], i_data[39], i_data[31], i_data[23], i_data[15], i_data[7]};

assign C16 = {i_key[57], i_key[49], i_key[41], i_key[33], i_key[25], i_key[17], i_key[ 9],
              i_key[ 1], i_key[58], i_key[50], i_key[42], i_key[34], i_key[26], i_key[18],
              i_key[10], i_key[ 2], i_key[59], i_key[51], i_key[43], i_key[35], i_key[27],
              i_key[19], i_key[11], i_key[ 3], i_key[60], i_key[52], i_key[44], i_key[36]};

assign D16 = {i_key[63], i_key[55], i_key[47], i_key[39], i_key[31], i_key[23], i_key[15],
              i_key[ 7], i_key[62], i_key[54], i_key[46], i_key[38], i_key[30], i_key[22],
              i_key[14], i_key[ 6], i_key[61], i_key[53], i_key[45], i_key[37], i_key[29],
              i_key[21], i_key[13], i_key[ 5], i_key[28], i_key[20], i_key[12], i_key[ 4]};

generate
    for (genvar i = ROUNDS-1; i >= 0; i--) begin : rounds
        logic [1:EXPANDED_BLOCK] round_key;
        logic [1:(USED_KEY/2)]   C_nx;
        logic [1:(USED_KEY/2)]   D_nx;
        logic [1:USED_KEY]       perm_ch;
        logic [1:(NBW_DATA/2)]   L_nx;
        logic [1:EXPANDED_BLOCK] L_expanded;
        logic [1:6]              Primitive_input  [1:8];
        logic [1:4]              Primitive_output [1:8];
        logic [1:(NBW_DATA/2)]   perm_in;

        if(i == 15) begin
            assign perm_ch = {C16, D16};
        end else begin
            assign perm_ch = {C_ff[i+1], D_ff[i+1]};
        end
        assign round_key = {perm_ch[14], perm_ch[17], perm_ch[11], perm_ch[24], perm_ch[ 1], perm_ch[ 5],
                            perm_ch[ 3], perm_ch[28], perm_ch[15], perm_ch[ 6], perm_ch[21], perm_ch[10],
                            perm_ch[23], perm_ch[19], perm_ch[12], perm_ch[ 4], perm_ch[26], perm_ch[ 8],
                            perm_ch[16], perm_ch[ 7], perm_ch[27], perm_ch[20], perm_ch[13], perm_ch[ 2],
                            perm_ch[41], perm_ch[52], perm_ch[31], perm_ch[37], perm_ch[47], perm_ch[55],
                            perm_ch[30], perm_ch[40], perm_ch[51], perm_ch[45], perm_ch[33], perm_ch[48],
                            perm_ch[44], perm_ch[49], perm_ch[39], perm_ch[56], perm_ch[34], perm_ch[53],
                            perm_ch[46], perm_ch[42], perm_ch[50], perm_ch[36], perm_ch[29], perm_ch[32]};

        if(i == 0 || i == 1 || i == 8 || i == 15) begin
            if(i == 15) begin
                assign C_nx = {C16[(USED_KEY/2)], C16[1:(USED_KEY/2)-1]};
                assign D_nx = {D16[(USED_KEY/2)], D16[1:(USED_KEY/2)-1]};
            end else begin
                assign C_nx = {C_ff[i+1][(USED_KEY/2)], C_ff[i+1][1:(USED_KEY/2)-1]};
                assign D_nx = {D_ff[i+1][(USED_KEY/2)], D_ff[i+1][1:(USED_KEY/2)-1]};
            end
        end else begin
            assign C_nx = {C_ff[i+1][(USED_KEY/2)-1+:2], C_ff[i+1][1:(USED_KEY/2)-2]};
            assign D_nx = {D_ff[i+1][(USED_KEY/2)-1+:2], D_ff[i+1][1:(USED_KEY/2)-2]};
        end

        assign Primitive_input[1] = L_expanded[ 1:6 ] ^ round_key[ 1:6 ];
        assign Primitive_input[2] = L_expanded[ 7:12] ^ round_key[ 7:12];
        assign Primitive_input[3] = L_expanded[13:18] ^ round_key[13:18];
        assign Primitive_input[4] = L_expanded[19:24] ^ round_key[19:24];
        assign Primitive_input[5] = L_expanded[25:30] ^ round_key[25:30];
        assign Primitive_input[6] = L_expanded[31:36] ^ round_key[31:36];
        assign Primitive_input[7] = L_expanded[37:42] ^ round_key[37:42];
        assign Primitive_input[8] = L_expanded[43:48] ^ round_key[43:48];

        S1 uu_S1 (
            .i_data(Primitive_input [1]),
            .o_data(Primitive_output[1])
        );

        S2 uu_S2 (
            .i_data(Primitive_input [2]),
            .o_data(Primitive_output[2])
        );

        S3 uu_S3 (
            .i_data(Primitive_input [3]),
            .o_data(Primitive_output[3])
        );

        S4 uu_S4 (
            .i_data(Primitive_input [4]),
            .o_data(Primitive_output[4])
        );

        S5 uu_S5 (
            .i_data(Primitive_input [5]),
            .o_data(Primitive_output[5])
        );

        S6 uu_S6 (
            .i_data(Primitive_input [6]),
            .o_data(Primitive_output[6])
        );

        S7 uu_S7 (
            .i_data(Primitive_input [7]),
            .o_data(Primitive_output[7])
        );

        S8 uu_S8 (
            .i_data(Primitive_input [8]),
            .o_data(Primitive_output[8])
        );

        assign perm_in = {Primitive_output[1], Primitive_output[2], Primitive_output[3], Primitive_output[4],
                          Primitive_output[5], Primitive_output[6], Primitive_output[7], Primitive_output[8]};

        assign L_nx = {perm_in[16], perm_in[ 7], perm_in[20], perm_in[21],
                       perm_in[29], perm_in[12], perm_in[28], perm_in[17],
                       perm_in[ 1], perm_in[15], perm_in[23], perm_in[26],
                       perm_in[ 5], perm_in[18], perm_in[31], perm_in[10],
                       perm_in[ 2], perm_in[ 8], perm_in[24], perm_in[14],
                       perm_in[32], perm_in[27], perm_in[ 3], perm_in[ 9],
                       perm_in[19], perm_in[13], perm_in[30], perm_in[ 6],
                       perm_in[22], perm_in[11], perm_in[ 4], perm_in[25]};

        if(i == 15) begin
            assign L_expanded = {L16[32], L16[ 1], L16[ 2], L16[ 3], L16[ 4], L16[ 5],
                                 L16[ 4], L16[ 5], L16[ 6], L16[ 7], L16[ 8], L16[ 9],
                                 L16[ 8], L16[ 9], L16[10], L16[11], L16[12], L16[13],
                                 L16[12], L16[13], L16[14], L16[15], L16[16], L16[17],
                                 L16[16], L16[17], L16[18], L16[19], L16[20], L16[21],
                                 L16[20], L16[21], L16[22], L16[23], L16[24], L16[25],
                                 L16[24], L16[25], L16[26], L16[27], L16[28], L16[29],
                                 L16[28], L16[29], L16[30], L16[31], L16[32], L16[ 1]};

            always_ff @ (posedge clk or negedge rst_async_n) begin
                if(!rst_async_n) begin
                    L_ff[i] <= 0;
                    R_ff[i] <= 0;
                    C_ff[i] <= 0;
                    D_ff[i] <= 0;
                end else begin
                    if(i_valid) begin
                        L_ff[i] <= L_nx ^ R16;
                        R_ff[i] <= L16;
                        C_ff[i] <= C_nx;
                        D_ff[i] <= D_nx;
                    end
                end
            end
        end else begin
            assign L_expanded = {L_ff[i+1][32], L_ff[i+1][ 1], L_ff[i+1][ 2], L_ff[i+1][ 3], L_ff[i+1][ 4], L_ff[i+1][ 5],
                                 L_ff[i+1][ 4], L_ff[i+1][ 5], L_ff[i+1][ 6], L_ff[i+1][ 7], L_ff[i+1][ 8], L_ff[i+1][ 9],
                                 L_ff[i+1][ 8], L_ff[i+1][ 9], L_ff[i+1][10], L_ff[i+1][11], L_ff[i+1][12], L_ff[i+1][13],
                                 L_ff[i+1][12], L_ff[i+1][13], L_ff[i+1][14], L_ff[i+1][15], L_ff[i+1][16], L_ff[i+1][17],
                                 L_ff[i+1][16], L_ff[i+1][17], L_ff[i+1][18], L_ff[i+1][19], L_ff[i+1][20], L_ff[i+1][21],
                                 L_ff[i+1][20], L_ff[i+1][21], L_ff[i+1][22], L_ff[i+1][23], L_ff[i+1][24], L_ff[i+1][25],
                                 L_ff[i+1][24], L_ff[i+1][25], L_ff[i+1][26], L_ff[i+1][27], L_ff[i+1][28], L_ff[i+1][29],
                                 L_ff[i+1][28], L_ff[i+1][29], L_ff[i+1][30], L_ff[i+1][31], L_ff[i+1][32], L_ff[i+1][ 1]};

            always_ff @ (posedge clk or negedge rst_async_n) begin
                if(!rst_async_n) begin
                    L_ff[i] <= 0;
                    R_ff[i] <= 0;
                    C_ff[i] <= 0;
                    D_ff[i] <= 0;
                end else begin
                    L_ff[i] <= L_nx ^ R_ff[i+1];
                    R_ff[i] <= L_ff[i+1];
                    C_ff[i] <= C_nx;
                    D_ff[i] <= D_nx;
                end
            end
        end
    end
endgenerate

assign last_perm = {L_ff[0], R_ff[0]};

assign o_data = {last_perm[40], last_perm[8], last_perm[48], last_perm[16], last_perm[56], last_perm[24], last_perm[64], last_perm[32],
                 last_perm[39], last_perm[7], last_perm[47], last_perm[15], last_perm[55], last_perm[23], last_perm[63], last_perm[31],
                 last_perm[38], last_perm[6], last_perm[46], last_perm[14], last_perm[54], last_perm[22], last_perm[62], last_perm[30],
                 last_perm[37], last_perm[5], last_perm[45], last_perm[13], last_perm[53], last_perm[21], last_perm[61], last_perm[29],
                 last_perm[36], last_perm[4], last_perm[44], last_perm[12], last_perm[52], last_perm[20], last_perm[60], last_perm[28],
                 last_perm[35], last_perm[3], last_perm[43], last_perm[11], last_perm[51], last_perm[19], last_perm[59], last_perm[27],
                 last_perm[34], last_perm[2], last_perm[42], last_perm[10], last_perm[50], last_perm[18], last_perm[58], last_perm[26],
                 last_perm[33], last_perm[1], last_perm[41], last_perm[ 9], last_perm[49], last_perm[17], last_perm[57], last_perm[25]};

endmodule : des_dec