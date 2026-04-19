module multi_digit_bcd_add_sub #(
    parameter N = 4
) (
    input  [4*N-1:0] A,
    input  [4*N-1:0] B,
    input            add_sub,      // 1: add, 0: subtract
    output [4*N-1:0] result,
    output           carry_borrow
);

wire [N:0] carry_chain;
assign carry_chain[0] = ~add_sub; // add:0, subtract (9's comp +1):1

genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : gen_digits
        wire [3:0] b_digit;
        wire [3:0] b_eff;

        assign b_digit = B[(i*4)+3:(i*4)];
        assign b_eff = add_sub ? b_digit : (4'd9 - b_digit);

        bcd_adder u_bcd_adder (
            .a   (A[(i*4)+3:(i*4)]),
            .b   (b_eff),
            .cin (carry_chain[i]),
            .sum (result[(i*4)+3:(i*4)]),
            .cout(carry_chain[i+1])
        );
    end
endgenerate

assign carry_borrow = add_sub ? carry_chain[N] : ~carry_chain[N];

endmodule
