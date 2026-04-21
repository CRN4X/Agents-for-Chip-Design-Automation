`timescale 1ns/1ns

module ethernet_dp_ram #(
    parameter integer WIDTH  = 32,
    parameter integer ADDR_W = 10
) (
    input  wire                 clk_in,
    input  wire [ADDR_W-1:0]    addr0_in,
    input  wire [WIDTH-1:0]     data0_in,
    input  wire                 wr0_in,
    output reg  [WIDTH-1:0]     data0_out,
    input  wire [ADDR_W-1:0]    addr1_in,
    input  wire [WIDTH-1:0]     data1_in,
    input  wire                 wr1_in,
    output reg  [WIDTH-1:0]     data1_out
);

    localparam integer DEPTH = (1 << ADDR_W);

    reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk_in) begin
        if (wr0_in) begin
            mem[addr0_in] <= data0_in;
        end
        if (wr1_in) begin
            mem[addr1_in] <= data1_in;
        end

        // Registered outputs provide one-cycle read latency on both ports.
        data0_out <= mem[addr0_in];
        data1_out <= mem[addr1_in];
    end

endmodule
