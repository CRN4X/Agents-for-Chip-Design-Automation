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
    // Local parameters
    localparam DATA_SQ    = DATA_WIDTH * 2;
    localparam DATA_RAD   = DATA_SQ + 1;
    localparam ERROR_FULL = DATA_WIDTH + DATA_RAD;

    // Internal signals
    logic signed [DATA_SQ-1:0] data_real_sq;
    logic signed [DATA_SQ-1:0] data_imag_sq;

    logic signed [DATA_RAD-1:0] data_real_rad;
    logic signed [DATA_RAD-1:0] data_imag_rad;

    logic signed [ERROR_FULL-1:0] error_real_full;
    logic signed [ERROR_FULL-1:0] error_imag_full;

    logic signed [ERROR_FULL-1:0] error_real_rnd;
    logic signed [ERROR_FULL-1:0] error_imag_rnd;

    // Error calculation using MCMA (Multimodulus Constant Modulus Algorithm) algorithm
    always_comb begin
        data_real_sq    = data_real * data_real;
        data_real_rad   = data_real_sq - 32'h04000000;
        error_real_full = data_real_rad * data_real;
        error_real_rnd  = error_real_full <<< 6;

        data_imag_sq    = data_imag * data_imag;
        data_imag_rad   = data_imag_sq - 32'h04000000;
        error_imag_full = data_imag_rad * data_imag;
        error_imag_rnd  = error_imag_full <<< 6;

        error_real = error_real_rnd[(ERROR_FULL - 1) -: DATA_WIDTH];
        error_imag = error_imag_rnd[(ERROR_FULL - 1) -: DATA_WIDTH];
    end

endmodule