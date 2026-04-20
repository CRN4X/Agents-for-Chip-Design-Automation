module dual_port_memory #(
    parameter DATA_WIDTH = 4,
    parameter ECC_WIDTH = 3,
    parameter ADDR_WIDTH = 5,
    parameter MEM_DEPTH = (1 << ADDR_WIDTH)
)(
    input clk,
    input rst_n,
    input we,
    input [ADDR_WIDTH-1:0] addr_a,
    input [ADDR_WIDTH-1:0] addr_b,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg [ECC_WIDTH-1:0] ecc_error
);

    reg [DATA_WIDTH-1:0] ram_data [0:MEM_DEPTH-1];
    reg [ECC_WIDTH-1:0] ram_ecc [0:MEM_DEPTH-1];
    reg [DATA_WIDTH-1:0] data_word;
    reg [ECC_WIDTH-1:0] ecc_word;
    reg [ECC_WIDTH-1:0] syndrome;
    reg [ECC_WIDTH-1:0] computed_ecc;

    function automatic [ECC_WIDTH-1:0] hamming74_encode;
        input [DATA_WIDTH-1:0] d;
        begin
            hamming74_encode[0] = d[0] ^ d[1] ^ d[3];
            hamming74_encode[1] = d[0] ^ d[2] ^ d[3];
            hamming74_encode[2] = d[1] ^ d[2] ^ d[3];
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            data_out <= {DATA_WIDTH{1'b0}};
            ecc_error <= {ECC_WIDTH{1'b0}};
        end else begin
            if (we) begin
                ram_data[addr_a] <= data_in;
                ram_ecc[addr_a] <= hamming74_encode(data_in);
            end

            data_word = ram_data[addr_b];
            ecc_word = ram_ecc[addr_b];
            computed_ecc = hamming74_encode(data_word);
            syndrome = ecc_word ^ computed_ecc;

            data_out <= data_word;
            ecc_error <= {{(ECC_WIDTH-1){1'b0}}, (syndrome != {ECC_WIDTH{1'b0}})};
        end
    end
endmodule
