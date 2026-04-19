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

  reg                        bid_start;
  reg                        ask_start;
  wire                       bid_done;
  wire                       ask_done;
  wire [8*PRICE_WIDTH-1:0]   bid_sorted;
  wire [8*PRICE_WIDTH-1:0]   ask_sorted;

  reg                        active;
  reg [5:0]                  latency_cnt;
  reg [8*PRICE_WIDTH-1:0]    bid_latched;
  reg [8*PRICE_WIDTH-1:0]    ask_latched;

  reg [PRICE_WIDTH-1:0] best_bid;
  reg [PRICE_WIDTH-1:0] best_ask;
  integer idx;

  always @(*) begin
    best_bid = bid_latched[0 +: PRICE_WIDTH];
    best_ask = ask_latched[0 +: PRICE_WIDTH];
    for (idx = 1; idx < 8; idx = idx + 1) begin
      if (bid_latched[idx*PRICE_WIDTH +: PRICE_WIDTH] > best_bid)
        best_bid = bid_latched[idx*PRICE_WIDTH +: PRICE_WIDTH];
      if (ask_latched[idx*PRICE_WIDTH +: PRICE_WIDTH] < best_ask)
        best_ask = ask_latched[idx*PRICE_WIDTH +: PRICE_WIDTH];
    end
  end

  sorting_engine #(
      .WIDTH(PRICE_WIDTH)
  ) u_bid_sort (
      .clk(clk),
      .rst(rst),
      .start(bid_start),
      .in_data(bid_orders),
      .done(bid_done),
      .out_data(bid_sorted)
  );

  sorting_engine #(
      .WIDTH(PRICE_WIDTH)
  ) u_ask_sort (
      .clk(clk),
      .rst(rst),
      .start(ask_start),
      .in_data(ask_orders),
      .done(ask_done),
      .out_data(ask_sorted)
  );

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      bid_start      <= 1'b0;
      ask_start      <= 1'b0;
      active         <= 1'b0;
      latency_cnt    <= 6'd0;
      bid_latched    <= {8*PRICE_WIDTH{1'b0}};
      ask_latched    <= {8*PRICE_WIDTH{1'b0}};
      match_valid    <= 1'b0;
      matched_price  <= {PRICE_WIDTH{1'b0}};
      done           <= 1'b0;
      latency_error  <= 1'b0;
    end else begin
      bid_start <= 1'b0;
      ask_start <= 1'b0;
      done      <= 1'b0;

      if (!active) begin
        if (start) begin
          active      <= 1'b1;
          latency_cnt <= 6'd0;
          bid_latched <= bid_orders;
          ask_latched <= ask_orders;
          bid_start   <= 1'b1;
          ask_start   <= 1'b1;
        end
      end else begin
        latency_cnt <= latency_cnt + 6'd1;

        if (latency_cnt == 6'd19) begin
          done          <= 1'b1;
          active        <= 1'b0;
          latency_error <= (latency_cnt != 6'd19);

          if (best_bid >= best_ask) begin
            match_valid   <= 1'b1;
            matched_price <= best_ask;
          end else begin
            match_valid   <= 1'b0;
            matched_price <= {PRICE_WIDTH{1'b0}};
          end
        end
      end
    end
  end

endmodule
