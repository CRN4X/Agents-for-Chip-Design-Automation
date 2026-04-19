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

localparam integer NBW_SUBKEY = NBW_KEY / 3;
localparam integer STAGE_LAT  = 16;

logic [1:NBW_SUBKEY] k1;
logic [1:NBW_SUBKEY] k2;
logic [1:NBW_SUBKEY] k3;

logic [1:NBW_SUBKEY] k2_pipe [0:STAGE_LAT-1];
logic [1:NBW_SUBKEY] k3_pipe [0:(2*STAGE_LAT)-1];

logic              s1_valid;
logic [1:NBW_DATA] s1_data;
logic              s2_valid;
logic [1:NBW_DATA] s2_data;

assign k1 = i_key[1 +: NBW_SUBKEY];
assign k2 = i_key[NBW_SUBKEY + 1 +: NBW_SUBKEY];
assign k3 = i_key[(2*NBW_SUBKEY) + 1 +: NBW_SUBKEY];

always_ff @(posedge clk or negedge rst_async_n) begin
    integer idx;
    if (!rst_async_n) begin
        for (idx = 0; idx < STAGE_LAT; idx = idx + 1) begin
            k2_pipe[idx] <= '0;
        end
        for (idx = 0; idx < (2*STAGE_LAT); idx = idx + 1) begin
            k3_pipe[idx] <= '0;
        end
    end else begin
        k2_pipe[0] <= k2;
        for (idx = 1; idx < STAGE_LAT; idx = idx + 1) begin
            k2_pipe[idx] <= k2_pipe[idx-1];
        end

        k3_pipe[0] <= k3;
        for (idx = 1; idx < (2*STAGE_LAT); idx = idx + 1) begin
            k3_pipe[idx] <= k3_pipe[idx-1];
        end
    end
end

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY (NBW_SUBKEY)
) u_des_enc_1 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (i_valid),
    .i_data     (i_data),
    .i_key      (k1),
    .o_valid    (s1_valid),
    .o_data     (s1_data)
);

des_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY (NBW_SUBKEY)
) u_des_dec_2 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (s1_valid),
    .i_data     (s1_data),
    .i_key      (k2_pipe[STAGE_LAT-1]),
    .o_valid    (s2_valid),
    .o_data     (s2_data)
);

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY (NBW_SUBKEY)
) u_des_enc_3 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (s2_valid),
    .i_data     (s2_data),
    .i_key      (k3_pipe[(2*STAGE_LAT)-1]),
    .o_valid    (o_valid),
    .o_data     (o_data)
);

endmodule
