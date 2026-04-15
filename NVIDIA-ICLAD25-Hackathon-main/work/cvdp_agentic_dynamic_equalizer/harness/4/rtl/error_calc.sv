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

    // Error calculation using LMS (Least Mean Squares) algorithm
    always_comb begin
            error_real = (desired_real - data_real);
            error_imag = (desired_imag - data_imag);
    end

endmodule