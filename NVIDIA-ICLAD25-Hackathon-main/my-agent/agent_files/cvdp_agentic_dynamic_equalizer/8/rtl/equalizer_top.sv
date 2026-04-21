`timescale 1ns/1ns

module equalizer_top #(
    parameter TAP_NUM     = 7,
    parameter DATA_WIDTH  = 16,
    parameter COEFF_WIDTH = 16,
    parameter MU          = 15,
    parameter LUT_SIZE    = 16
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic signed [DATA_WIDTH-1:0] data_in_real,
    input  logic signed [DATA_WIDTH-1:0] data_in_imag,
    input  logic        [3:0]            noise_index,
    input  logic signed [DATA_WIDTH-1:0] noise_scale,
    output logic signed [DATA_WIDTH-1:0] data_out_real,
    output logic signed [DATA_WIDTH-1:0] data_out_imag
);
    logic signed [DATA_WIDTH-1:0] awgn_out_real;
    logic signed [DATA_WIDTH-1:0] awgn_out_imag;
    logic signed [DATA_WIDTH-1:0] eq_out_real;
    logic signed [DATA_WIDTH-1:0] eq_out_imag;

    logic signed [DATA_WIDTH-1:0] data_pipe_real [0:3];
    logic signed [DATA_WIDTH-1:0] data_pipe_imag [0:3];

    awgn #(
        .DATA_WIDTH(DATA_WIDTH),
        .LUT_SIZE  (LUT_SIZE)
    ) uu_awgn_real (
        .signal_in  (data_in_real),
        .noise_index(noise_index),
        .noise_scale(noise_scale),
        .signal_out (awgn_out_real)
    );

    awgn #(
        .DATA_WIDTH(DATA_WIDTH),
        .LUT_SIZE  (LUT_SIZE)
    ) uu_awgn_imag (
        .signal_in  (data_in_imag),
        .noise_index(noise_index),
        .noise_scale(noise_scale),
        .signal_out (awgn_out_imag)
    );

    dynamic_equalizer #(
        .TAP_NUM    (TAP_NUM),
        .DATA_WIDTH (DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .MU         (MU)
    ) uu_dynamic_equalizer (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_in_real(awgn_out_real),
        .data_in_imag(awgn_out_imag),
        .data_out_real(eq_out_real),
        .data_out_imag(eq_out_imag)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++) begin
                data_pipe_real[i] <= '0;
                data_pipe_imag[i] <= '0;
            end
        end else begin
            data_pipe_real[0] <= data_in_real;
            data_pipe_imag[0] <= data_in_imag;
            for (int i = 1; i < 4; i++) begin
                data_pipe_real[i] <= data_pipe_real[i-1];
                data_pipe_imag[i] <= data_pipe_imag[i-1];
            end
        end
    end

    assign data_out_real = data_pipe_real[3];
    assign data_out_imag = data_pipe_imag[3];

endmodule
