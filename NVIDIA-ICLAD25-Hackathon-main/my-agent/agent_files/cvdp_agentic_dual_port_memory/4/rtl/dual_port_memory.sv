`timescale 1ns/1ns

module dual_port_memory #(
    parameter DATA_WIDTH = 4,
    parameter ECC_WIDTH  = 3,
    parameter ADDR_WIDTH = 5,
    parameter MEM_DEPTH  = (1 << ADDR_WIDTH)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] addr_a,
    input  wire [ADDR_WIDTH-1:0] addr_b,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg  [DATA_WIDTH-1:0] data_out,
    output reg  [ECC_WIDTH-1:0]  ecc_error
);

    reg [DATA_WIDTH-1:0] ram_data [0:MEM_DEPTH-1];
    reg [ECC_WIDTH-1:0]  ram_ecc  [0:MEM_DEPTH-1];

    function [ECC_WIDTH-1:0] hamming74_ecc(input [DATA_WIDTH-1:0] d);
        begin
            hamming74_ecc[0] = d[0] ^ d[1] ^ d[3];
            hamming74_ecc[1] = d[0] ^ d[2] ^ d[3];
            hamming74_ecc[2] = d[1] ^ d[2] ^ d[3];
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            data_out   <= {DATA_WIDTH{1'b0}};
            ecc_error  <= {ECC_WIDTH{1'b0}};
        end else begin
            if (we) begin
                ram_data[addr_a] <= data_in;
                ram_ecc[addr_a]  <= hamming74_ecc(data_in);
            end

            data_out  <= ram_data[addr_b];
            ecc_error <= ((ram_ecc[addr_b] ^ hamming74_ecc(ram_data[addr_b])) != {ECC_WIDTH{1'b0}})
                         ? {{(ECC_WIDTH-1){1'b0}}, 1'b1}
                         : {ECC_WIDTH{1'b0}};
        end
    end

endmodule
