`timescale 1ns/1ps

module des3_enc #(
    parameter NBW_DATA = 'd64,
    parameter NBW_KEY  = 'd192
) (
    input  logic              clk,
    input  logic              rst_async_n,
    input  logic              i_valid,
    input  logic [1:NBW_DATA] i_data,
    input  logic [1:NBW_KEY]  i_key,
    output logic              o_valid,
    output logic [1:NBW_DATA] o_data
);

localparam DES_LATENCY = 'd16;

logic [1:NBW_DATA] data_stage1;
logic [1:NBW_DATA] data_stage2;
logic              valid_stage1;
logic              valid_stage2;
logic [1:64]       key2_ff [0:DES_LATENCY-1];
logic [1:64]       key3_ff [0:(2*DES_LATENCY)-1];

integer idx;
always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        for (idx = 0; idx < DES_LATENCY; idx = idx + 1) begin
            key2_ff[idx] <= '0;
        end
        for (idx = 0; idx < (2*DES_LATENCY); idx = idx + 1) begin
            key3_ff[idx] <= '0;
        end
    end else begin
        key2_ff[0] <= i_key[65:128];
        for (idx = 1; idx < DES_LATENCY; idx = idx + 1) begin
            key2_ff[idx] <= key2_ff[idx-1];
        end

        key3_ff[0] <= i_key[129:192];
        for (idx = 1; idx < (2*DES_LATENCY); idx = idx + 1) begin
            key3_ff[idx] <= key3_ff[idx-1];
        end
    end
end

// 3DES EDE mode: Encrypt(K1) -> Decrypt(K2) -> Encrypt(K3)
des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) uu_des_enc_1 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (i_valid),
    .i_data     (i_data),
    .i_key      (i_key[1:64]),
    .o_valid    (valid_stage1),
    .o_data     (data_stage1)
);

des_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) uu_des_dec_1 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (valid_stage1),
    .i_data     (data_stage1),
    .i_key      (key2_ff[DES_LATENCY-1]),
    .o_valid    (valid_stage2),
    .o_data     (data_stage2)
);

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) uu_des_enc_2 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (valid_stage2),
    .i_data     (data_stage2),
    .i_key      (key3_ff[(2*DES_LATENCY)-1]),
    .o_valid    (o_valid),
    .o_data     (o_data)
);

endmodule : des3_enc
