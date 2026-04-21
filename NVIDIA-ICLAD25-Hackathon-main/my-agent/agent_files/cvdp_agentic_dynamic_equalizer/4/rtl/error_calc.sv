`timescale 1ns/1ns

module error_calc #(
    parameter DATA_WIDTH = 16
)(
    input  logic signed [DATA_WIDTH-1:0] data_real,
    input  logic signed [DATA_WIDTH-1:0] data_imag,
    input  logic signed [DATA_WIDTH-1:0] desired_real,
    input  logic signed [DATA_WIDTH-1:0] desired_imag,
    output logic signed [DATA_WIDTH-1:0] error_real,
    output logic signed [DATA_WIDTH-1:0] error_imag
);

    localparam int FRAC_BITS = DATA_WIDTH - 3;  // Q2.(DATA_WIDTH-3)
    localparam logic signed [DATA_WIDTH-1:0] R_REF = (1 <<< FRAC_BITS);

    logic signed [(2*DATA_WIDTH)-1:0] sq_real;
    logic signed [(2*DATA_WIDTH)-1:0] sq_imag;
    logic signed [DATA_WIDTH-1:0] norm_real;
    logic signed [DATA_WIDTH-1:0] norm_imag;
    logic signed [DATA_WIDTH-1:0] delta_real;
    logic signed [DATA_WIDTH-1:0] delta_imag;
    logic signed [(2*DATA_WIDTH)-1:0] err_real_mul;
    logic signed [(2*DATA_WIDTH)-1:0] err_imag_mul;

    // MCMA error (desired_* kept for interface compatibility, not used here).
    always_comb begin
            sq_real = data_real * data_real;
            sq_imag = data_imag * data_imag;

            norm_real = sq_real >>> FRAC_BITS;
            norm_imag = sq_imag >>> FRAC_BITS;

            delta_real = norm_real - R_REF;
            delta_imag = norm_imag - R_REF;

            err_real_mul = data_real * delta_real;
            err_imag_mul = data_imag * delta_imag;

            error_real = err_real_mul >>> FRAC_BITS;
            error_imag = err_imag_mul >>> FRAC_BITS;
    end

endmodule
