module bst_tree_construct #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire                                 clk,
    input  wire                                 reset,
    input  wire                                 start,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0]     data_in,
    output reg  [$clog2(ARRAY_SIZE):0]          root,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0]     out_keys,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_left_child,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_right_child,
    output reg                                  done,
    output reg                                  invalid
);
    localparam integer PTR_W = $clog2(ARRAY_SIZE) + 1;
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};
    localparam [PTR_W-1:0]      INVALID_PTR = {PTR_W{1'b1}};

    reg [DATA_WIDTH-1:0] key_arr [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0]      left_arr [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0]      right_arr[0:ARRAY_SIZE-1];
    integer i, cur, ins, next_free;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 1'b0;
            invalid <= 1'b0;
            root <= INVALID_PTR;
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                key_arr[i] <= INVALID_KEY;
                left_arr[i] <= INVALID_PTR;
                right_arr[i] <= INVALID_PTR;
                out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                out_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                out_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
            end
        end else begin
            done <= 1'b0;
            if (start) begin
                invalid <= 1'b0;
                root <= 0;
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    key_arr[i] = INVALID_KEY;
                    left_arr[i] = INVALID_PTR;
                    right_arr[i] = INVALID_PTR;
                end

                next_free = 0;
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    if (data_in[i*DATA_WIDTH +: DATA_WIDTH] == INVALID_KEY) begin
                        invalid <= 1'b1;
                    end else if (next_free == 0) begin
                        key_arr[0] = data_in[i*DATA_WIDTH +: DATA_WIDTH];
                        next_free = 1;
                    end else begin
                        cur = 0;
                        while (1) begin
                            if (data_in[i*DATA_WIDTH +: DATA_WIDTH] < key_arr[cur]) begin
                                if (left_arr[cur] == INVALID_PTR) begin
                                    ins = next_free;
                                    left_arr[cur] = ins[PTR_W-1:0];
                                    key_arr[ins] = data_in[i*DATA_WIDTH +: DATA_WIDTH];
                                    next_free = next_free + 1;
                                    break;
                                end
                                cur = left_arr[cur];
                            end else begin
                                if (right_arr[cur] == INVALID_PTR) begin
                                    ins = next_free;
                                    right_arr[cur] = ins[PTR_W-1:0];
                                    key_arr[ins] = data_in[i*DATA_WIDTH +: DATA_WIDTH];
                                    next_free = next_free + 1;
                                    break;
                                end
                                cur = right_arr[cur];
                            end
                        end
                    end
                end

                if (invalid) begin
                    root <= INVALID_PTR;
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                        out_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        out_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                    end
                end else begin
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= key_arr[i];
                        out_left_child[i*PTR_W +: PTR_W] <= left_arr[i];
                        out_right_child[i*PTR_W +: PTR_W] <= right_arr[i];
                    end
                end
                done <= 1'b1;
            end
        end
    end
endmodule
