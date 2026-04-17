module simd_lane #(
    parameter DATA_WIDTH = 16
)(
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    input  wire [2:0] op_sel,
    input  wire valid,
    output reg  [DATA_WIDTH-1:0] result,
    output reg  ready
);

    always @(*) begin
        if (!valid) begin
            result = 0;
            ready  = 0;
        end else begin
            case (op_sel)
                3'b000: result = a + b;
                3'b001: result = a - b;
                3'b010: result = a * b;
                default: result = 0;
            endcase
            ready = 1;
        end
    end

endmodule
module simd_datapath #(
    parameter SIMD_WIDTH = 4,
    parameter DATA_WIDTH = 16
)(
    input  wire [SIMD_WIDTH*DATA_WIDTH-1:0] a_flat,
    input  wire [SIMD_WIDTH*DATA_WIDTH-1:0] b_flat,
    input  wire [SIMD_WIDTH-1:0] valid_lanes,
    input  wire [2:0] op_sel,
    output wire [SIMD_WIDTH*DATA_WIDTH-1:0] result_flat,
    output wire ready
);

    wire [DATA_WIDTH-1:0] a_arr [0:SIMD_WIDTH-1];
    wire [DATA_WIDTH-1:0] b_arr [0:SIMD_WIDTH-1];
    wire [DATA_WIDTH-1:0] result_arr [0:SIMD_WIDTH-1];
    wire [SIMD_WIDTH-1:0] lane_ready;

    genvar i;
    generate
        for (i = 0; i < SIMD_WIDTH; i = i + 1) begin : SIMD_LANES
            assign a_arr[i] = a_flat[i*DATA_WIDTH +: DATA_WIDTH];
            assign b_arr[i] = b_flat[i*DATA_WIDTH +: DATA_WIDTH];

            simd_lane #(.DATA_WIDTH(DATA_WIDTH)) u_lane (
                .a(a_arr[i]),
                .b(b_arr[i]),
                .op_sel(op_sel),
                .valid(valid_lanes[i]),
                .result(result_arr[i]),
                .ready(lane_ready[i])
            );

            assign result_flat[i*DATA_WIDTH +: DATA_WIDTH] = result_arr[i];
        end
    endgenerate

    assign ready = &lane_ready;

endmodule
module simd_matrix_engine_top #(
    parameter N = 8,
    parameter SIMD_WIDTH = 4,
    parameter DATA_WIDTH = 16
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire [2:0] op_select,

    input  wire [N*N*DATA_WIDTH-1:0] mat_a_flat,
    input  wire [N*N*DATA_WIDTH-1:0] mat_b_flat,
    output reg  [N*N*DATA_WIDTH-1:0] mat_result_flat,

    output reg done
);

    // --- Internal State ---
    reg [SIMD_WIDTH*DATA_WIDTH-1:0] a_row_flat;
    reg [SIMD_WIDTH*DATA_WIDTH-1:0] b_row_flat;
    wire [SIMD_WIDTH*DATA_WIDTH-1:0] result_flat;
    wire [SIMD_WIDTH-1:0] valid_lanes;
    wire simd_ready;

    reg [$clog2(N)-1:0] row_idx;
    reg [$clog2(N)-1:0] col_idx;
    reg [1:0] state;

    localparam IDLE    = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam STORE   = 2'b10;
    localparam DONE    = 2'b11;

    // Valid mask for all SIMD lanes
    assign valid_lanes = {SIMD_WIDTH{1'b1}};

    // SIMD datapath
    simd_datapath #(
        .SIMD_WIDTH(SIMD_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_simd (
        .a_flat(a_row_flat),
        .b_flat(b_row_flat),
        .valid_lanes(valid_lanes),
        .op_sel(op_select),
        .result_flat(result_flat),
        .ready(simd_ready)
    );

    // FSM + control
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            row_idx <= 0;
            col_idx <= 0;
            done <= 0;
            a_row_flat <= 0;
            b_row_flat <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        row_idx <= 0;
                        col_idx <= 0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Extract current SIMD-width row chunk
                    for (int i = 0; i < SIMD_WIDTH; i++) begin
                        a_row_flat[i*DATA_WIDTH +: DATA_WIDTH] <=
                            mat_a_flat[((row_idx * N) + col_idx + i) * DATA_WIDTH +: DATA_WIDTH];
                        b_row_flat[i*DATA_WIDTH +: DATA_WIDTH] <=
                            mat_b_flat[((row_idx * N) + col_idx + i) * DATA_WIDTH +: DATA_WIDTH];
                    end

                    if (simd_ready)
                        state <= STORE;
                end

                STORE: begin
                    for (int i = 0; i < SIMD_WIDTH; i++) begin
                        mat_result_flat[((row_idx * N) + col_idx + i) * DATA_WIDTH +: DATA_WIDTH] <=
                            result_flat[i*DATA_WIDTH +: DATA_WIDTH];
                    end

                    if (col_idx + SIMD_WIDTH >= N) begin
                        col_idx <= 0;
                        if (row_idx + 1 == N) begin
                            state <= DONE;
                        end else begin
                            row_idx <= row_idx + 1;
                            state <= COMPUTE;
                        end
                    end else begin
                        col_idx <= col_idx + SIMD_WIDTH;
                        state <= COMPUTE;
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
