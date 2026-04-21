`timescale 1ns/1ns

module multi_digit_bcd_add_sub #(
    parameter N = 4
)(
    input  [4*N-1:0] A,
    input  [4*N-1:0] B,
    input            add_sub,
    output [4*N-1:0] result,
    output           carry_borrow
);

wire [N:0] carry;

assign carry[0] = add_sub ? 1'b0 : 1'b1;

genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : gen_bcd_digits
        wire [3:0] b_digit;
        assign b_digit = add_sub ? B[4*i +: 4] : (4'd9 - B[4*i +: 4]);

        bcd_adder u_bcd_adder (
            .a   (A[4*i +: 4]),
            .b   (b_digit),
            .cin (carry[i]),
            .sum (result[4*i +: 4]),
            .cout(carry[i+1])
        );
    end
endgenerate

assign carry_borrow = add_sub ? carry[N] : ~carry[N];

endmodule
