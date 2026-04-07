module binary_search_tree_sort #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire                                 clk,
    input  wire                                 reset,
    input  wire                                 start,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0]     in_keys,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0]     sorted_out,
    output reg                                  done
);
    reg [DATA_WIDTH-1:0] arr [0:ARRAY_SIZE-1];
    integer i, j;
    reg [DATA_WIDTH-1:0] t;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 1'b0;
            for (i = 0; i < ARRAY_SIZE; i = i + 1)
                sorted_out[i*DATA_WIDTH +: DATA_WIDTH] <= {DATA_WIDTH{1'b1}};
        end else begin
            done <= 1'b0;
            if (start) begin
                for (i = 0; i < ARRAY_SIZE; i = i + 1)
                    arr[i] = in_keys[i*DATA_WIDTH +: DATA_WIDTH];

                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    for (j = i + 1; j < ARRAY_SIZE; j = j + 1) begin
                        if (arr[j] < arr[i]) begin
                            t = arr[i];
                            arr[i] = arr[j];
                            arr[j] = t;
                        end
                    end
                end

                for (i = 0; i < ARRAY_SIZE; i = i + 1)
                    sorted_out[i*DATA_WIDTH +: DATA_WIDTH] <= arr[i];
                done <= 1'b1;
            end
        end
    end
endmodule
