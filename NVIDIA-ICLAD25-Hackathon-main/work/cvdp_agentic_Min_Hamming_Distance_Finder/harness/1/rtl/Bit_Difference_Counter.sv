module Bit_Difference_Counter
#(
    parameter BIT_WIDTH    = 3,                          // Defines the width of the input vectors.
    localparam COUNT_WIDTH = $clog2(BIT_WIDTH + 1)       // Calculates the width required to represent the count of differing bits.
)
(
    input  wire [BIT_WIDTH-1:0] input_A,                // First input vector.
    input  wire [BIT_WIDTH-1:0] input_B,                // Second input vector.
    output reg  [COUNT_WIDTH-1:0] bit_difference_count  // Count of differing bits (Hamming distance).
);

    wire [BIT_WIDTH-1:0] different_bits;
    integer idx;

    // Instantiate the Data_Reduction module to compute bitwise XOR between input_A and input_B.
    Data_Reduction
    #(
        .REDUCTION_OP (3'b010), // XOR operation
        .DATA_WIDTH  (BIT_WIDTH),
        .DATA_COUNT  (2)
    )
    compare_bits
    (
        .data_in      ({input_A, input_B}),
        .reduced_data_out   (different_bits)
    );

    // Count set bits in different_bits to compute Hamming distance
    always @(*) begin
        bit_difference_count = 0;
        for (idx = 0; idx < BIT_WIDTH; idx = idx + 1) begin
            bit_difference_count = bit_difference_count + different_bits[idx];
        end
    end

endmodule