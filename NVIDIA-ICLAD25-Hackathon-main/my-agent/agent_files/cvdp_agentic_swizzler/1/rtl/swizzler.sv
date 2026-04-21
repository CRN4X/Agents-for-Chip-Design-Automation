`timescale 1ns/1ns

module swizzler #(
    parameter integer NUM_LANES = 4,
    parameter integer DATA_WIDTH = 8,
    parameter integer REGISTER_OUTPUT = 0,
    parameter integer ENABLE_PARITY_CHECK = 0
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire                               bypass,
    input  wire [NUM_LANES*DATA_WIDTH-1:0]    data_in,
    input  wire [NUM_LANES*$clog2(NUM_LANES)-1:0] swizzle_map_flat,
    output reg  [NUM_LANES*DATA_WIDTH-1:0]    data_out,
    output reg                                parity_error
);

    localparam integer MAP_WIDTH = (NUM_LANES > 1) ? $clog2(NUM_LANES) : 1;

    integer i;
    reg [NUM_LANES*DATA_WIDTH-1:0] data_next;
    reg                            parity_next;
    reg [MAP_WIDTH-1:0]            src_lane;
    reg [DATA_WIDTH-1:0]           lane_val;

    always @* begin
        data_next   = {NUM_LANES*DATA_WIDTH{1'b0}};
        parity_next = 1'b0;

        for (i = 0; i < NUM_LANES; i = i + 1) begin
            if (bypass) begin
                src_lane = i[MAP_WIDTH-1:0];
            end else begin
                src_lane = swizzle_map_flat[i*MAP_WIDTH +: MAP_WIDTH];
            end

            lane_val = data_in[src_lane*DATA_WIDTH +: DATA_WIDTH];
            data_next[i*DATA_WIDTH +: DATA_WIDTH] = lane_val;

            if (ENABLE_PARITY_CHECK != 0) begin
                parity_next = parity_next | (^lane_val);
            end
        end
    end

    generate
        if (REGISTER_OUTPUT != 0) begin : g_reg_out
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    data_out     <= {NUM_LANES*DATA_WIDTH{1'b0}};
                    parity_error <= 1'b0;
                end else begin
                    data_out     <= data_next;
                    parity_error <= parity_next;
                end
            end
        end else begin : g_comb_out
            always @* begin
                data_out = data_next;
                if (!rst_n) begin
                    parity_error = 1'b0;
                end else begin
                    parity_error = parity_next;
                end
            end
        end
    endgenerate

endmodule
