module Min_Hamming_Distance_Finder #(
    parameter BIT_WIDTH = 8,
    parameter REFERENCE_COUNT = 4,
    localparam DIST_WIDTH = $clog2(BIT_WIDTH + 1),
    localparam INDEX_WIDTH = $clog2(REFERENCE_COUNT)
) (
    input  wire [BIT_WIDTH-1:0]                     input_query,
    input  wire [REFERENCE_COUNT*BIT_WIDTH-1:0]     references,
    output reg  [INDEX_WIDTH-1:0]                   best_match_index,
    output reg  [DIST_WIDTH-1:0]                    min_distance
);

    wire [DIST_WIDTH-1:0] distances [0:REFERENCE_COUNT-1];

    genvar ref_idx;
    generate
        for (ref_idx = 0; ref_idx < REFERENCE_COUNT; ref_idx = ref_idx + 1) begin : gen_distance
            Bit_Difference_Counter #(
                .BIT_WIDTH(BIT_WIDTH)
            ) u_bit_difference_counter (
                .input_A(input_query),
                .input_B(references[(ref_idx+1)*BIT_WIDTH-1 -: BIT_WIDTH]),
                .bit_difference_count(distances[ref_idx])
            );
        end
    endgenerate

    integer i;
    always @(*) begin
        min_distance = distances[0];
        best_match_index = {INDEX_WIDTH{1'b0}};

        for (i = 1; i < REFERENCE_COUNT; i = i + 1) begin
            if (distances[i] < min_distance) begin
                min_distance = distances[i];
                best_match_index = i[INDEX_WIDTH-1:0];
            end
        end
    end

endmodule
