`timescale 1ns/1ns

module top_64b66b_codec (
    input  logic         clk_in,
    input  logic         rst_in,
    input  logic [63:0]  enc_data_in,
    input  logic [7:0]   enc_control_in,
    output logic [65:0]  enc_data_out,
    input  logic         dec_data_valid_in,
    input  logic [65:0]  dec_data_in,
    output logic [63:0]  dec_data_out,
    output logic [7:0]   dec_control_out,
    output logic [1:0]   dec_sync_error,
    output logic [1:0]   dec_error_out
);

    logic [65:0] enc_data_path_out;
    logic [65:0] enc_control_path_out;
    logic        dec_sync_error_i;
    logic        dec_error_out_i;

    encoder_data_64b66b u_encoder_data_64b66b (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .encoder_data_in(enc_data_in),
        .encoder_control_in(enc_control_in),
        .encoder_data_out(enc_data_path_out)
    );

    encoder_control_64b66b u_encoder_control_64b66b (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .encoder_data_in(enc_data_in),
        .encoder_control_in(enc_control_in),
        .encoder_data_out(enc_control_path_out)
    );

    decoder_data_control_64b66b u_decoder_data_control_64b66b (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .decoder_data_valid_in(dec_data_valid_in),
        .decoder_data_in(dec_data_in),
        .decoder_data_out(dec_data_out),
        .decoder_control_out(dec_control_out),
        .sync_error(dec_sync_error_i),
        .decoder_error_out(dec_error_out_i)
    );

    assign dec_sync_error = {1'b0, dec_sync_error_i};
    assign dec_error_out  = {1'b0, dec_error_out_i};

    always_comb begin
        if (enc_control_in == 8'h00) begin
            enc_data_out = enc_data_path_out;
        end else begin
            enc_data_out = enc_control_path_out;
        end
    end

endmodule
