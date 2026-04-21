`timescale 1ns/1ns

module binary_to_gray #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] binary_in,
    output logic [WIDTH-1:0] gray_out
);
    assign gray_out = binary_in ^ (binary_in >> 1);

endmodule
