`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// modular_multiplier module: Computes (A * B) mod mod_val
// Implements a sequential shift‐and‐add multiplication followed by a
// single modulo operation at the end.
//-----------------------------------------------------------------------------
module modular_multiplier #(
    parameter WIDTH = 8
)(
    input                     clk,
    input                     rst,
    input                     start,
    input      [WIDTH-1:0]    A,
    input      [WIDTH-1:0]    B,
    input      [WIDTH-1:0]    mod_val,
    output reg [WIDTH-1:0]    result,
    output reg                done
);
    // a_reg now stores A extended to 2*WIDTH bits to accommodate shifts.
    reg [2*WIDTH-1:0] a_reg;
    reg [WIDTH-1:0]   b_reg;
    reg [2*WIDTH-1:0] prod;   // Accumulates the full product
    reg [($clog2(WIDTH+1))-1:0] count;  // Iteration counter for WIDTH bits
    reg busy;

    always @(posedge clk) begin
        if(rst) begin
            result  <= 0;
            prod    <= 0;
            a_reg   <= 0;
            b_reg   <= 0;
            count   <= 0;
            busy    <= 0;
            done    <= 0;
        end else begin
            if(start && !busy) begin
                busy    <= 1;
                // Initialize registers.
                // Extend A to 2*WIDTH bits.
                a_reg   <= { {WIDTH{1'b0}}, A };
                b_reg   <= B;
                prod    <= 0;
                count   <= WIDTH;
                done    <= 0;
            end else if(busy) begin
                if(count > 0) begin
                    // If the current LSB of b_reg is 1, add a_reg to the product.
                    if(b_reg[0] == 1'b1)
                        prod <= prod + a_reg;
                    // Shift a_reg left to align with the next bit.
                    a_reg <= a_reg << 1;
                    // Shift b_reg right to process the next bit.
                    b_reg <= b_reg >> 1;
                    count <= count - 1;
                end else begin
                    // Once multiplication is done, perform the modulo operation.
                    result <= prod % mod_val;
                    done   <= 1;
                    busy   <= 0;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule