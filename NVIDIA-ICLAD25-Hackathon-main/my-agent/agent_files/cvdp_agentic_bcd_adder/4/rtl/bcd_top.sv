module bcd_top #(
    parameter N = 4
) (
    input  [4*N-1:0] A,
    input  [4*N-1:0] B,
    output           A_less_B,
    output           A_equal_B,
    output           A_greater_B
);

wire [4*N-1:0] sub_result;
wire borrow_out;
wire is_zero;

multi_digit_bcd_add_sub #(
    .N(N)
) u_sub_cmp (
    .A(A),
    .B(B),
    .add_sub(1'b0),
    .result(sub_result),
    .carry_borrow(borrow_out)
);

assign is_zero = (sub_result == {4*N{1'b0}});
assign A_less_B = borrow_out;
assign A_equal_B = ~borrow_out & is_zero;
assign A_greater_B = ~borrow_out & ~is_zero;

endmodule
