`timescale 1ns/1ns

module bcd_top #(
    parameter N = 4
)(
    input  [4*N-1:0] A,
    input  [4*N-1:0] B,
    output           A_less_B,
    output           A_equal_B,
    output           A_greater_B
);

wire [4*N-1:0] diff;
wire           borrow;

multi_digit_bcd_add_sub #(
    .N(N)
) u_subtract (
    .A           (A),
    .B           (B),
    .add_sub     (1'b0),
    .result      (diff),
    .carry_borrow(borrow)
);

assign A_equal_B = (diff == {4*N{1'b0}});
assign A_less_B = borrow;
assign A_greater_B = ~borrow & ~A_equal_B;

endmodule
