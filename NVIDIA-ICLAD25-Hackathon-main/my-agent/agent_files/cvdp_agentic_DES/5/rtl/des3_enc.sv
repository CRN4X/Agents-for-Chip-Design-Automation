`timescale 1ns/1ns

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

localparam DES_LATENCY = 16;

logic [1:NBW_DATA] stage1_data;
logic [1:NBW_DATA] stage2_data;
logic              stage1_valid;
logic              stage2_valid;

logic [1:64] k2_pipe [0:DES_LATENCY-1];
logic [1:64] k3_pipe [0:(2*DES_LATENCY)-1];
integer idx;

always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        for (idx = 0; idx < DES_LATENCY; idx = idx + 1) begin
            k2_pipe[idx] <= '0;
        end
        for (idx = 0; idx < (2*DES_LATENCY); idx = idx + 1) begin
            k3_pipe[idx] <= '0;
        end
    end else begin
        k2_pipe[0] <= i_key[65:128];
        for (idx = 1; idx < DES_LATENCY; idx = idx + 1) begin
            k2_pipe[idx] <= k2_pipe[idx-1];
        end

        k3_pipe[0] <= i_key[129:192];
        for (idx = 1; idx < (2*DES_LATENCY); idx = idx + 1) begin
            k3_pipe[idx] <= k3_pipe[idx-1];
        end
    end
end

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) u_des_enc_1 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (i_valid),
    .i_data     (i_data),
    .i_key      (i_key[1:64]),
    .o_valid    (stage1_valid),
    .o_data     (stage1_data)
);

des_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) u_des_dec_2 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (stage1_valid),
    .i_data     (stage1_data),
    .i_key      (k2_pipe[DES_LATENCY-1]),
    .o_valid    (stage2_valid),
    .o_data     (stage2_data)
);

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) u_des_enc_3 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (stage2_valid),
    .i_data     (stage2_data),
    .i_key      (k3_pipe[(2*DES_LATENCY)-1]),
    .o_valid    (o_valid),
    .o_data     (o_data)
);

endmodule : des3_enc
