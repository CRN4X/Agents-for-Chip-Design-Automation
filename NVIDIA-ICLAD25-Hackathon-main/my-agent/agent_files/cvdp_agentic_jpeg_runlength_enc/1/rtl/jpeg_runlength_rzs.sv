`timescale 1ns/1ns

module jpeg_runlength_rzs (
    input  wire              clk_in,
    input  wire              reset_in,
    input  wire              enable_in,
    input  wire [3:0]        rlen_in,
    input  wire [3:0]        size_in,
    input  wire signed [11:0] amp_in,
    input  wire              den_in,
    input  wire              dc_in,
    output reg  [3:0]        rlen_out,
    output reg  [3:0]        size_out,
    output reg  signed [11:0] amp_out,
    output reg               den_out,
    output reg               dc_out
);

    always @(*) begin
        rlen_out = rlen_in;
        size_out = size_in;
        amp_out  = amp_in;
        den_out  = den_in;
        dc_out   = dc_in;
    end

endmodule
