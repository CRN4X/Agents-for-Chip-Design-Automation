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

    localparam S_IDLE      = 1'b0;
    localparam S_WAIT_SORT = 1'b1;

    reg state;

    reg                      cb_latched;
    reg [8*PRICE_WIDTH-1:0]  bid_latched;
    reg [8*PRICE_WIDTH-1:0]  ask_latched;
    wire                     sort_start;

    wire                     bid_done;
    wire                     ask_done;
    wire [8*PRICE_WIDTH-1:0] bid_sorted;
    wire [8*PRICE_WIDTH-1:0] ask_sorted;

    wire [PRICE_WIDTH-1:0] best_bid;
    wire [PRICE_WIDTH-1:0] best_ask;

    assign best_bid = bid_sorted[7*PRICE_WIDTH +: PRICE_WIDTH];
    assign best_ask = ask_sorted[0*PRICE_WIDTH +: PRICE_WIDTH];

    assign sort_start = (state == S_IDLE) && start;

    // Lowest-latency sorter among provided engines.
    brick_sorting_engine #(
        .N(8),
        .WIDTH(PRICE_WIDTH)
    ) u_bid_sort (
        .clk(clk),
        .rst(rst),
        .start(sort_start),
        .in_data(bid_latched),
        .done(bid_done),
        .out_data(bid_sorted)
    );

    brick_sorting_engine #(
        .N(8),
        .WIDTH(PRICE_WIDTH)
    ) u_ask_sort (
        .clk(clk),
        .rst(rst),
        .start(sort_start),
        .in_data(ask_latched),
        .done(ask_done),
        .out_data(ask_sorted)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= S_IDLE;
            done          <= 1'b0;
            match_valid   <= 1'b0;
            matched_price <= {PRICE_WIDTH{1'b0}};
            cb_latched    <= 1'b0;
            bid_latched   <= {8*PRICE_WIDTH{1'b0}};
            ask_latched   <= {8*PRICE_WIDTH{1'b0}};
        end else begin
            done       <= 1'b0;

            case (state)
                S_IDLE: begin
                    match_valid   <= 1'b0;
                    matched_price <= {PRICE_WIDTH{1'b0}};
                    if (start) begin
                        bid_latched <= bid_orders;
                        ask_latched <= ask_orders;
                        cb_latched  <= circuit_breaker;
                        state       <= S_WAIT_SORT;
                    end
                end

                S_WAIT_SORT: begin
                    if (bid_done && ask_done) begin
                        if (!cb_latched && (best_bid >= best_ask)) begin
                            match_valid   <= 1'b1;
                            matched_price <= best_bid;
                        end else begin
                            match_valid   <= 1'b0;
                            matched_price <= {PRICE_WIDTH{1'b0}};
                        end
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
