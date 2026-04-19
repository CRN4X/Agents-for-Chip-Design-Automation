module bcd_adder(
                 input  [3:0] a,             // 4-bit input a
                 input  [3:0] b,             // 4-bit input b
                 input        cin,           // Carry input for chaining
                 output [3:0] sum,           // 4-bit BCD sum output
                 output       cout           // BCD carry output
                );

wire [4:0] raw_sum;
wire [4:0] corrected_sum;

assign raw_sum = {1'b0, a} + {1'b0, b} + {4'b0000, cin};
assign cout = (raw_sum > 5'd9);
assign corrected_sum = cout ? (raw_sum + 5'd6) : raw_sum;
assign sum = corrected_sum[3:0];

endmodule
