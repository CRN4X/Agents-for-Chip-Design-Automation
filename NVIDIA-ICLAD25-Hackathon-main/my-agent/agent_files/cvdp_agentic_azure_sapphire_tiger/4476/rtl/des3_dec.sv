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

logic              busy_ff;
logic [47:0]       valid_shift_ff;
logic              accept_start;
logic              stage1_valid;
logic              stage2_valid;
logic              stage3_valid;
logic [1:NBW_DATA] stage1_data;
logic [1:NBW_DATA] stage2_data;
logic [1:NBW_DATA] stage3_data;
logic [1:NBW_KEY]  start_key_ff;

assign accept_start = i_start & ~busy_ff;
assign stage1_valid = valid_shift_ff[15];
assign stage2_valid = valid_shift_ff[31];
assign stage3_valid = valid_shift_ff[46];
assign o_data       = stage3_data;

des_dec u_des_dec_k3 (
    .clk        (clk           ),
    .rst_async_n(rst_async_n   ),
    .i_start    (accept_start  ),
    .i_data     (i_data        ),
    .i_key      (i_key[129:192]),
    .o_data     (stage1_data   )
);

des_enc u_des_enc_k2 (
    .clk        (clk          ),
    .rst_async_n(rst_async_n  ),
    .i_start    (stage1_valid ),
    .i_data     (stage1_data  ),
    .i_key      (start_key_ff[65:128]),
    .o_data     (stage2_data  )
);

des_dec u_des_dec_k1 (
    .clk        (clk        ),
    .rst_async_n(rst_async_n),
    .i_start    (stage2_valid),
    .i_data     (stage2_data ),
    .i_key      (start_key_ff[1:64] ),
    .o_data     (stage3_data )
);

always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        busy_ff        <= 1'b0;
        valid_shift_ff <= '0;
        start_key_ff   <= '0;
        o_done         <= 1'b1;
    end else begin
        valid_shift_ff <= {valid_shift_ff[46:0], accept_start};

        if (accept_start) begin
            busy_ff <= 1'b1;
            o_done  <= 1'b0;
            start_key_ff  <= i_key;
        end

        if (stage3_valid) begin
            busy_ff <= 1'b0;
            o_done  <= 1'b1;
        end
    end
end

endmodule : des3_dec
