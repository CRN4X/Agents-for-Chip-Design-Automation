`timescale 1ns/1ns

module order_matching_engine #(
    parameter PRICE_WIDTH = 16
)(
    input                           clk,
    input                           rst,
    input                           start,
    input                           circuit_breaker,
    input      [8*PRICE_WIDTH-1:0]  bid_orders,
    input      [8*PRICE_WIDTH-1:0]  ask_orders,
    output reg                      match_valid,
    output reg [PRICE_WIDTH-1:0]    matched_price,
    output reg                      done
);

    localparam integer NUM_ORDERS = 8;
    localparam integer EXTRA_LATENCY = 12;

    reg [PRICE_WIDTH-1:0] best_bid_calc;
    reg [PRICE_WIDTH-1:0] best_ask_calc;
    reg [PRICE_WIDTH-1:0] best_bid_latched;
    reg [PRICE_WIDTH-1:0] best_ask_latched;
    reg                   cb_latched;
    reg                   active;
    reg [4:0]             cycle_ctr;
    integer i;
    reg [PRICE_WIDTH-1:0] value_tmp;

    always @(*) begin
        best_bid_calc = bid_orders[PRICE_WIDTH-1:0];
        best_ask_calc = ask_orders[PRICE_WIDTH-1:0];
        for (i = 1; i < NUM_ORDERS; i = i + 1) begin
            value_tmp = bid_orders[i*PRICE_WIDTH +: PRICE_WIDTH];
            if (value_tmp > best_bid_calc) begin
                best_bid_calc = value_tmp;
            end
            value_tmp = ask_orders[i*PRICE_WIDTH +: PRICE_WIDTH];
            if (value_tmp < best_ask_calc) begin
                best_ask_calc = value_tmp;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            best_bid_latched <= {PRICE_WIDTH{1'b0}};
            best_ask_latched <= {PRICE_WIDTH{1'b0}};
            cb_latched       <= 1'b0;
            active           <= 1'b0;
            cycle_ctr        <= 5'd0;
            match_valid      <= 1'b0;
            matched_price    <= {PRICE_WIDTH{1'b0}};
            done             <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !active) begin
                best_bid_latched <= best_bid_calc;
                best_ask_latched <= best_ask_calc;
                cb_latched       <= circuit_breaker;
                cycle_ctr        <= 5'd0;
                active           <= 1'b1;
                match_valid      <= 1'b0;
                matched_price    <= {PRICE_WIDTH{1'b0}};
            end else if (active) begin
                if (cycle_ctr == EXTRA_LATENCY-1) begin
                    done          <= 1'b1;
                    active        <= 1'b0;
                    matched_price <= best_bid_latched;
                    if (!cb_latched && (best_bid_latched >= best_ask_latched)) begin
                        match_valid <= 1'b1;
                    end else begin
                        match_valid <= 1'b0;
                    end
                end else begin
                    cycle_ctr <= cycle_ctr + 5'd1;
                end
            end
        end
    end

endmodule
