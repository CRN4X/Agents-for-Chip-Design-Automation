`timescale 1ns/1ns

module timer_module #(
    parameter integer SHORT_COUNT = 10,
    parameter integer LONG_COUNT  = 20
) (
    input  wire i_clk,
    input  wire i_rst_b,
    input  wire i_short_trigger,
    input  wire i_long_trigger,
    output reg  o_short_timer,
    output reg  o_long_timer
);

localparam integer SHORT_W = (SHORT_COUNT > 1) ? $clog2(SHORT_COUNT) : 1;
localparam integer LONG_W  = (LONG_COUNT > 1) ? $clog2(LONG_COUNT) : 1;

reg [SHORT_W-1:0] r_short_count;
reg [LONG_W-1:0]  r_long_count;

always @(posedge i_clk or negedge i_rst_b) begin
    if (!i_rst_b) begin
        r_short_count <= {SHORT_W{1'b0}};
        r_long_count  <= {LONG_W{1'b0}};
        o_short_timer <= 1'b0;
        o_long_timer  <= 1'b0;
    end else begin
        if (i_short_trigger) begin
            if (o_short_timer) begin
                r_short_count <= r_short_count;
            end else if (r_short_count == SHORT_COUNT-1) begin
                r_short_count <= r_short_count;
                o_short_timer <= 1'b1;
            end else begin
                r_short_count <= r_short_count + 1'b1;
                o_short_timer <= 1'b0;
            end
        end else begin
            r_short_count <= {SHORT_W{1'b0}};
            o_short_timer <= 1'b0;
        end

        if (i_long_trigger) begin
            if (o_long_timer) begin
                r_long_count <= r_long_count;
            end else if (r_long_count == LONG_COUNT-1) begin
                r_long_count <= r_long_count;
                o_long_timer <= 1'b1;
            end else begin
                r_long_count <= r_long_count + 1'b1;
                o_long_timer <= 1'b0;
            end
        end else begin
            r_long_count <= {LONG_W{1'b0}};
            o_long_timer <= 1'b0;
        end
    end
end

endmodule
