`timescale 1ns/1ns

module des3_dec #(
    parameter NBW_DATA = 'd64,
    parameter NBW_KEY  = 'd192
) (
    input  logic              clk,
    input  logic              rst_async_n,
    input  logic              i_start,
    input  logic [1:NBW_DATA] i_data,
    input  logic [1:NBW_KEY]  i_key,
    output logic              o_done,
    output logic [1:NBW_DATA] o_data
);

localparam STAGE_LATENCY = 'd16;
localparam TOTAL_LATENCY = 'd48;

logic busy;
logic [5:0] cycle_cnt;

logic [1:NBW_KEY]  key_latched;

logic stage1_start;
logic stage2_start;
logic stage3_start;

logic [1:NBW_DATA] stage1_data;
logic [1:NBW_DATA] stage2_data;
logic [1:NBW_DATA] stage3_data;

assign stage1_start = (!busy) && i_start;
assign stage2_start = busy && (cycle_cnt == (STAGE_LATENCY - 1));
assign stage3_start = busy && (cycle_cnt == ((2 * STAGE_LATENCY) - 1));

always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        busy        <= 1'b0;
        cycle_cnt   <= '0;
        key_latched  <= '0;
        o_done      <= 1'b1;
    end else begin
        if (!busy) begin
            if (i_start) begin
                busy         <= 1'b1;
                cycle_cnt    <= '0;
                key_latched  <= i_key;
                o_done       <= 1'b0;
            end
        end else begin
            if (cycle_cnt == (TOTAL_LATENCY - 2)) begin
                busy      <= 1'b0;
                cycle_cnt <= '0;
                o_done    <= 1'b1;
            end else begin
                cycle_cnt <= cycle_cnt + 1'b1;
            end
        end
    end
end

des_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) uu_des_dec_k3 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_start    (stage1_start),
    .i_data     (i_data),
    .i_key      (i_key[129:192]),
    .o_data     (stage1_data)
);

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) uu_des_enc_k2 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_start    (stage2_start),
    .i_data     (stage1_data),
    .i_key      (key_latched[65:128]),
    .o_data     (stage2_data)
);

des_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY ('d64)
) uu_des_dec_k1 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_start    (stage3_start),
    .i_data     (stage2_data),
    .i_key      (key_latched[1:64]),
    .o_data     (stage3_data)
);

assign o_data = stage3_data;

endmodule : des3_dec
