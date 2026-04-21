`timescale 1ns/1ns

module order_matching_engine #(
    parameter PRICE_WIDTH = 16
)(
    input                           clk,
    input                           rst,
    input                           start,
    input      [8*PRICE_WIDTH-1:0]  bid_orders,
    input      [8*PRICE_WIDTH-1:0]  ask_orders,
    output reg                      match_valid,
    output reg [PRICE_WIDTH-1:0]    matched_price,
    output reg                      done,
    output reg                      latency_error
);

  localparam integer TARGET_LATENCY = 20;

  reg        busy;
  reg [5:0]  cycle_count;

  wire [8*PRICE_WIDTH-1:0] bid_sorted;
  wire [8*PRICE_WIDTH-1:0] ask_sorted;
  wire                     bid_sort_done;
  wire                     ask_sort_done;
  wire                     sort_start;

  wire [PRICE_WIDTH-1:0] best_bid;
  wire [PRICE_WIDTH-1:0] best_ask;
  wire                   has_match;

  assign sort_start = start && !busy;
  assign best_bid   = bid_sorted[(8*PRICE_WIDTH)-1 -: PRICE_WIDTH];
  assign best_ask   = ask_sorted[PRICE_WIDTH-1:0];
  assign has_match  = (best_bid >= best_ask);

  sorting_engine #(
      .WIDTH(PRICE_WIDTH)
  ) u_bid_sort (
      .clk(clk),
      .rst(rst),
      .start(sort_start),
      .in_data(bid_orders),
      .done(bid_sort_done),
      .out_data(bid_sorted)
  );

  sorting_engine #(
      .WIDTH(PRICE_WIDTH)
  ) u_ask_sort (
      .clk(clk),
      .rst(rst),
      .start(sort_start),
      .in_data(ask_orders),
      .done(ask_sort_done),
      .out_data(ask_sorted)
  );

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      busy          <= 1'b0;
      cycle_count   <= 6'd0;
      match_valid   <= 1'b0;
      matched_price <= {PRICE_WIDTH{1'b0}};
      done          <= 1'b0;
      latency_error <= 1'b0;
    end else begin
      done <= 1'b0;

      if (!busy) begin
        if (sort_start) begin
          busy        <= 1'b1;
          cycle_count <= 6'd0;
        end
      end else begin
        if (cycle_count == TARGET_LATENCY-1) begin
          busy          <= 1'b0;
          done          <= 1'b1;
          match_valid   <= has_match;
          matched_price <= has_match ? best_ask : {PRICE_WIDTH{1'b0}};
          latency_error <= !(bid_sort_done && ask_sort_done);
        end else begin
          cycle_count <= cycle_count + 6'd1;
        end
      end
    end
  end

endmodule
