module order_matching_engine #(
    parameter PRICE_WIDTH = 16
)(
    input                          clk,
    input                          rst,
    input                          start,
    input      [8*PRICE_WIDTH-1:0] bid_orders,
    input      [8*PRICE_WIDTH-1:0] ask_orders,
    output reg                     match_valid,
    output reg [PRICE_WIDTH-1:0]   matched_price,
    output reg                     done,
    output reg                     latency_error
);

    localparam S_IDLE = 1'b0;
    localparam S_WAIT = 1'b1;

    reg state;

    reg [8*PRICE_WIDTH-1:0] bid_latched;
    reg [8*PRICE_WIDTH-1:0] ask_latched;

    wire sort_done_bid;
    wire sort_done_ask;
    wire sort_start;
    wire [8*PRICE_WIDTH-1:0] bid_sorted;
    wire [8*PRICE_WIDTH-1:0] ask_sorted;

    wire [PRICE_WIDTH-1:0] best_bid = bid_sorted[7*PRICE_WIDTH +: PRICE_WIDTH];
    wire [PRICE_WIDTH-1:0] best_ask = ask_sorted[0*PRICE_WIDTH +: PRICE_WIDTH];

    assign sort_start = (state == S_IDLE) && start;

    sorting_engine #(.WIDTH(PRICE_WIDTH)) u_sort_bid (
        .clk(clk), .rst(rst), .start(sort_start), .in_data(bid_latched), .done(sort_done_bid), .out_data(bid_sorted)
    );

    sorting_engine #(.WIDTH(PRICE_WIDTH)) u_sort_ask (
        .clk(clk), .rst(rst), .start(sort_start), .in_data(ask_latched), .done(sort_done_ask), .out_data(ask_sorted)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 1'b0;
            match_valid <= 1'b0;
            matched_price <= {PRICE_WIDTH{1'b0}};
            latency_error <= 1'b0;
            bid_latched <= 0;
            ask_latched <= 0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    match_valid <= 1'b0;
                    matched_price <= {PRICE_WIDTH{1'b0}};
                    latency_error <= 1'b0;
                    if (start) begin
                        bid_latched <= bid_orders;
                        ask_latched <= ask_orders;
                    state <= S_WAIT;
                end
                end

                S_WAIT: begin
                    if (sort_done_bid && sort_done_ask) begin
                        done <= 1'b1;
                        latency_error <= 1'b0;
                        if (best_bid >= best_ask) begin
                            match_valid <= 1'b1;
                            matched_price <= best_ask;
                        end else begin
                            match_valid <= 1'b0;
                            matched_price <= {PRICE_WIDTH{1'b0}};
                        end
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
