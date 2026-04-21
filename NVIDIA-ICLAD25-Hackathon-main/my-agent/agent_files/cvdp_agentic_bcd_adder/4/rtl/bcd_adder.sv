`timescale 1ns/1ns

module bcd_adder(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

wire [4:0] raw_sum;
wire [4:0] corrected_sum;
wire       needs_correction;

assign raw_sum = {1'b0, a} + {1'b0, b} + {4'b0, cin};
assign needs_correction = (raw_sum > 5'd9);
assign corrected_sum = needs_correction ? (raw_sum + 5'd6) : raw_sum;

assign sum = corrected_sum[3:0];
assign cout = corrected_sum[4];

endmodule
