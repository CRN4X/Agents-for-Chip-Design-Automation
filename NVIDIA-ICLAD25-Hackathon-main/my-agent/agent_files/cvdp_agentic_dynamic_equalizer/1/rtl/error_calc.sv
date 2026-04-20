module error_calc #(
    parameter integer DATA_WIDTH = 16
) (
    input  wire signed [DATA_WIDTH-1:0] data_real,
    input  wire signed [DATA_WIDTH-1:0] data_imag,
    input  wire signed [DATA_WIDTH-1:0] desired_real,
    input  wire signed [DATA_WIDTH-1:0] desired_imag,
    output wire signed [DATA_WIDTH-1:0] error_real,
    output wire signed [DATA_WIDTH-1:0] error_imag
);

    assign error_real = desired_real - data_real;
    assign error_imag = desired_imag - data_imag;

endmodule
