`timescale 1ns/1ns

module coeff_update #(
    parameter int TAP_NUM     = 7,
    parameter int DATA_WIDTH  = 16,
    parameter int COEFF_WIDTH = 16,
    parameter int MU          = 15
) (
    input  logic clk,
    input  logic rst_n,
    input  logic signed [TAP_NUM*DATA_WIDTH-1:0] data_real,
    input  logic signed [TAP_NUM*DATA_WIDTH-1:0] data_imag,
    input  logic signed [DATA_WIDTH-1:0] error_real,
    input  logic signed [DATA_WIDTH-1:0] error_imag,
    output logic signed [TAP_NUM*COEFF_WIDTH-1:0] coeff_real,
    output logic signed [TAP_NUM*COEFF_WIDTH-1:0] coeff_imag
);
    localparam int CENTER_TAP = TAP_NUM / 2;
    localparam signed [COEFF_WIDTH-1:0] ONE_Q2_13 = (1 <<< 13);

    integer i;
    logic signed [DATA_WIDTH-1:0] x_r;
    logic signed [DATA_WIDTH-1:0] x_i;
    logic signed [COEFF_WIDTH-1:0] wr;
    logic signed [COEFF_WIDTH-1:0] wi;
    logic signed [2*DATA_WIDTH-1:0] grad_r;
    logic signed [2*DATA_WIDTH-1:0] grad_i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < TAP_NUM; i = i + 1) begin
                coeff_real[i*COEFF_WIDTH +: COEFF_WIDTH] <= '0;
                coeff_imag[i*COEFF_WIDTH +: COEFF_WIDTH] <= '0;
            end
            coeff_real[CENTER_TAP*COEFF_WIDTH +: COEFF_WIDTH] <= ONE_Q2_13;
        end else begin
            // LMS-style coefficient adaptation in fixed-point.
            for (i = 0; i < TAP_NUM; i = i + 1) begin
                x_r = data_real[i*DATA_WIDTH +: DATA_WIDTH];
                x_i = data_imag[i*DATA_WIDTH +: DATA_WIDTH];
                wr  = coeff_real[i*COEFF_WIDTH +: COEFF_WIDTH];
                wi  = coeff_imag[i*COEFF_WIDTH +: COEFF_WIDTH];

                grad_r = (error_real * x_r) + (error_imag * x_i);
                grad_i = (error_imag * x_r) - (error_real * x_i);

                coeff_real[i*COEFF_WIDTH +: COEFF_WIDTH] <= wr + (grad_r >>> MU);
                coeff_imag[i*COEFF_WIDTH +: COEFF_WIDTH] <= wi + (grad_i >>> MU);
            end
        end
    end

endmodule
