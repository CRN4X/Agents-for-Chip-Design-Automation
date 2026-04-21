`timescale 1ns/1ns

module order_matching_engine #(
    parameter PRICE_WIDTH = 16
)(
    input                          clk,
    input                          rst,
    input                          start,
    input                          circuit_breaker,
    input      [8*PRICE_WIDTH-1:0] bid_orders,
    input      [8*PRICE_WIDTH-1:0] ask_orders,
    output reg                     match_valid,
    output reg [PRICE_WIDTH-1:0]   matched_price,
    output reg                     done
);

    localparam integer NUM_ORDERS = 8;
    localparam integer PIPELINE_LATENCY = 12;
    localparam integer CNT_W = $clog2(PIPELINE_LATENCY + 1);

    reg [CNT_W-1:0] cycle_cnt;
    reg             busy;

    reg [PRICE_WIDTH-1:0] best_bid;
    reg [PRICE_WIDTH-1:0] best_ask;
    reg                   pending_match_valid;
    reg [PRICE_WIDTH-1:0] pending_matched_price;

    integer i;
    reg [PRICE_WIDTH-1:0] bid_i;
    reg [PRICE_WIDTH-1:0] ask_i;
    always @(*) begin
        best_bid = bid_orders[0 +: PRICE_WIDTH];
        best_ask = ask_orders[0 +: PRICE_WIDTH];

        for (i = 1; i < NUM_ORDERS; i = i + 1) begin
            bid_i = bid_orders[i*PRICE_WIDTH +: PRICE_WIDTH];
            ask_i = ask_orders[i*PRICE_WIDTH +: PRICE_WIDTH];

            if (bid_i > best_bid)
                best_bid = bid_i;
            if (ask_i < best_ask)
                best_ask = ask_i;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_cnt            <= {CNT_W{1'b0}};
            busy                 <= 1'b0;
            done                 <= 1'b0;
            match_valid          <= 1'b0;
            matched_price        <= {PRICE_WIDTH{1'b0}};
            pending_match_valid  <= 1'b0;
            pending_matched_price<= {PRICE_WIDTH{1'b0}};
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy                 <= 1'b1;
                cycle_cnt            <= {CNT_W{1'b0}};
                pending_match_valid  <= (!circuit_breaker) && (best_bid >= best_ask);
                pending_matched_price<= best_bid;
            end else if (busy) begin
                if (cycle_cnt == PIPELINE_LATENCY-1) begin
                    busy          <= 1'b0;
                    done          <= 1'b1;
                    match_valid   <= pending_match_valid;
                    matched_price <= pending_match_valid ? pending_matched_price : {PRICE_WIDTH{1'b0}};
                end else begin
                    cycle_cnt <= cycle_cnt + 1'b1;
                end
            end
        end
    end

endmodule
