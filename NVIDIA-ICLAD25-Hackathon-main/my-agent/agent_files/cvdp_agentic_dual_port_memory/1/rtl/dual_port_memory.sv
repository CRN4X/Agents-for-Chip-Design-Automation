module dual_port_memory #(
    parameter DATA_WIDTH = 4,  // Data width 4
    parameter ADDR_WIDTH = 5   // Address width 5
)(
    input clk,
    input we_a,                           
    input we_b,                           
    input [ADDR_WIDTH-1:0] addr_a,        
    input [ADDR_WIDTH-1:0] addr_b,        
    input [DATA_WIDTH-1:0] data_in_a,     
    input [DATA_WIDTH-1:0] data_in_b,     
    output reg [DATA_WIDTH-1:0] data_out_a, 
    output reg [DATA_WIDTH-1:0] data_out_b  
);

    reg [DATA_WIDTH-1:0] ram [(2**ADDR_WIDTH)-1:0];

    always @(posedge clk) begin
        // Write ports: preserve true written data.
        if (we_a) begin
            ram[addr_a] <= data_in_a;
        end
        if (we_b) begin
            ram[addr_b] <= data_in_b;
        end

        // Synchronous reads.
        data_out_a <= ram[addr_a];
        data_out_b <= ram[addr_b];
    end
endmodule
