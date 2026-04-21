module lfsr_generator #(
    parameter WIDTH = 16,     
    parameter SEED = 16'hACE1
)(
    input  wire clk,
    input  wire rst_n,
    output reg [WIDTH-1:0] lfsr
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr <= SEED;
        else
            lfsr <= {lfsr[WIDTH-2:0], lfsr[WIDTH-1] ^ lfsr[2]};
    end

endmodule