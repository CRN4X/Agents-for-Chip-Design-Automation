module padding_top #(
    parameter NBW_KEY  = 'd256,
    parameter NBW_DATA = 'd128,
    parameter NBW_MODE = 'd3,
    parameter NBW_CNTR = 'd32,
    parameter NBW_PADD = 'd4,
    parameter NBW_PMOD = 'd2,
    parameter W3C_BYTE = 8'hAF
) (
    input  logic                clk,
    input  logic                rst_async_n,
    input  logic                i_encrypt,
    input  logic                i_update_padding_mode,
    input  logic [NBW_PMOD-1:0] i_padding_mode,
    input  logic [NBW_PADD-1:0] i_padding_bytes,
    input  logic                i_reset_counter,
    input  logic                i_update_iv,
    input  logic [NBW_DATA-1:0] i_iv,
    input  logic                i_update_mode,
    input  logic [NBW_MODE-1:0] i_mode,
    input  logic                i_update_key,
    input  logic [NBW_KEY-1:0]  i_key,
    input  logic                i_start,
    input  logic [NBW_DATA-1:0] i_data,
    output logic                o_done,
    output logic [NBW_DATA-1:0] o_data
);

localparam PKCS         = 2'b00;
localparam ONEANDZEROES = 2'b01;
localparam ANSIX923     = 2'b10;
localparam W3C          = 2'b11;

logic [NBW_PMOD-1:0] padding_mode_ff;
logic [NBW_DATA-1:0] padded_data;
logic [7:0] pad_byte;

logic enc_done;
logic [NBW_DATA-1:0] enc_data;
logic dec_done;
logic [NBW_DATA-1:0] dec_data;

assign pad_byte = {{(8-NBW_PADD){1'b0}}, i_padding_bytes};

always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        padding_mode_ff <= {NBW_PMOD{1'b0}};
    end else if (i_update_padding_mode) begin
        padding_mode_ff <= i_padding_mode;
    end
end

always_comb begin
    int b;
    padded_data = i_data;
    if (i_padding_bytes != {NBW_PADD{1'b0}}) begin
        for (b = 0; b < i_padding_bytes; b = b + 1) begin
            case (padding_mode_ff)
                PKCS: begin
                    padded_data[b*8 +: 8] = pad_byte;
                end
                ONEANDZEROES: begin
                    if (b == (i_padding_bytes - 1)) begin
                        padded_data[b*8 +: 8] = 8'h80;
                    end else begin
                        padded_data[b*8 +: 8] = 8'h00;
                    end
                end
                ANSIX923: begin
                    if (b == 0) begin
                        padded_data[b*8 +: 8] = pad_byte;
                    end else begin
                        padded_data[b*8 +: 8] = 8'h00;
                    end
                end
                default: begin
                    if (b == 0) begin
                        padded_data[b*8 +: 8] = pad_byte;
                    end else begin
                        padded_data[b*8 +: 8] = W3C_BYTE;
                    end
                end
            endcase
        end
    end
end

aes_enc_top #(
    .NBW_KEY (NBW_KEY ),
    .NBW_DATA(NBW_DATA),
    .NBW_MODE(NBW_MODE),
    .NBW_CNTR(NBW_CNTR)
) u_aes_enc_top (
    .clk            (clk                       ),
    .rst_async_n    (rst_async_n               ),
    .i_reset_counter(i_reset_counter & i_encrypt),
    .i_update_iv    (i_update_iv & i_encrypt   ),
    .i_iv           (i_iv                      ),
    .i_update_mode  (i_update_mode & i_encrypt ),
    .i_mode         (i_mode                    ),
    .i_update_key   (i_update_key & i_encrypt  ),
    .i_key          (i_key                     ),
    .i_start        (i_start & i_encrypt       ),
    .i_plaintext    (padded_data               ),
    .o_done         (enc_done                  ),
    .o_ciphertext   (enc_data                  )
);

aes_dec_top #(
    .NBW_KEY (NBW_KEY ),
    .NBW_DATA(NBW_DATA),
    .NBW_MODE(NBW_MODE),
    .NBW_CNTR(NBW_CNTR)
) u_aes_dec_top (
    .clk            (clk                        ),
    .rst_async_n    (rst_async_n                ),
    .i_reset_counter(i_reset_counter & (~i_encrypt)),
    .i_update_iv    (i_update_iv & (~i_encrypt) ),
    .i_iv           (i_iv                       ),
    .i_update_mode  (i_update_mode & (~i_encrypt)),
    .i_mode         (i_mode                     ),
    .i_update_key   (i_update_key & (~i_encrypt)),
    .i_key          (i_key                      ),
    .i_start        (i_start & (~i_encrypt)     ),
    .i_ciphertext   (padded_data                ),
    .o_done         (dec_done                   ),
    .o_plaintext    (dec_data                   )
);

always_comb begin
    if (i_encrypt) begin
        o_done = enc_done;
        o_data = enc_data;
    end else begin
        o_done = dec_done;
        o_data = dec_data;
    end
end

endmodule : padding_top
