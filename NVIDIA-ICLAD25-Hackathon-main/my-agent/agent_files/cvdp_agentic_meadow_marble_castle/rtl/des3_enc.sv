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

logic               stage1_valid;
logic               stage2_valid;
logic               stage3_valid;
logic [1:NBW_DATA]  stage1_data;
logic [1:NBW_DATA]  stage2_data;
logic [1:NBW_DATA]  stage3_data;

des_enc u_des_enc_k1 (
    .clk       (clk          ),
    .rst_async_n(rst_async_n ),
    .i_valid   (i_valid      ),
    .i_data    (i_data       ),
    .i_key     (i_key[1:64]  ),
    .o_valid   (stage1_valid ),
    .o_data    (stage1_data  )
);

des_dec u_des_dec_k2 (
    .clk       (clk           ),
    .rst_async_n(rst_async_n  ),
    .i_valid   (stage1_valid  ),
    .i_data    (stage1_data   ),
    .i_key     (i_key[65:128] ),
    .o_valid   (stage2_valid  ),
    .o_data    (stage2_data   )
);

des_enc u_des_enc_k3 (
    .clk       (clk            ),
    .rst_async_n(rst_async_n   ),
    .i_valid   (stage2_valid   ),
    .i_data    (stage2_data    ),
    .i_key     (i_key[129:192] ),
    .o_valid   (stage3_valid   ),
    .o_data    (stage3_data    )
);

assign o_valid = stage3_valid;
assign o_data  = stage3_data;

endmodule : des3_enc
