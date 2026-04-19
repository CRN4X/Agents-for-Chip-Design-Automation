module timer_module #(
    parameter integer SHORT_COUNT_PARAM = 10,
    parameter integer LONG_COUNT_PARAM  = 20
) (
    input  wire i_clk,
    input  wire i_rst_b,
    input  wire i_short_trigger,
    input  wire i_long_trigger,
    output reg  o_short_timer,
    output reg  o_long_timer
);

localparam integer SHORT_W = (SHORT_COUNT_PARAM <= 1) ? 1 : $clog2(SHORT_COUNT_PARAM);
localparam integer LONG_W  = (LONG_COUNT_PARAM  <= 1) ? 1 : $clog2(LONG_COUNT_PARAM);

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
            if (!o_short_timer) begin
                if (r_short_count == SHORT_COUNT_PARAM - 1) begin
                    o_short_timer <= 1'b1;
                end else begin
                    r_short_count <= r_short_count + 1'b1;
                end
            end
        end else begin
            r_short_count <= {SHORT_W{1'b0}};
            o_short_timer <= 1'b0;
        end

        if (i_long_trigger) begin
            if (!o_long_timer) begin
                if (r_long_count == LONG_COUNT_PARAM - 1) begin
                    o_long_timer <= 1'b1;
                end else begin
                    r_long_count <= r_long_count + 1'b1;
                end
            end
        end else begin
            r_long_count <= {LONG_W{1'b0}};
            o_long_timer <= 1'b0;
        end
    end
end

endmodule
