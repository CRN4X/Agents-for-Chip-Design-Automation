module dual_port_memory #(
    parameter DATA_WIDTH = 4,  // Data width
    parameter ADDR_WIDTH = 5,  // Address width
    parameter MEM_DEPTH = (1 << ADDR_WIDTH)  // Explicit memory depth
)(
    input clk,
    input rst_n,                         // Active-low synchronous reset
    input we,                           // Write enable 
    input [ADDR_WIDTH-1:0] addr_a,        // Address for port A
    input [ADDR_WIDTH-1:0] addr_b,        // Address for port B
    input [DATA_WIDTH-1:0] data_in,     // Data input 
    output reg [DATA_WIDTH-1:0] data_out, // Data output for port A
);

    // Define RAM
    reg [DATA_WIDTH-1:0] ram [MEM_DEPTH-1:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            data_out <= 0;
        end else begin
            if (we) begin
                ram[addr_a] <= data_in;
            end else begin
                    data_out <= ram[addr_b];
            end
        end
    end
endmodule