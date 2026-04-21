`timescale 1ns/1ps

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

  localparam ST_IDLE       = 2'd0;
  localparam ST_WAIT_SORT  = 2'd1;
  reg [1:0] state;
  reg [5:0] cycle_count;

  wire [8*PRICE_WIDTH-1:0] bid_sorted;
  wire [8*PRICE_WIDTH-1:0] ask_sorted;
  wire bid_done;
  wire ask_done;

  wire sort_start;
  assign sort_start = (state == ST_IDLE) && start;

  wire [PRICE_WIDTH-1:0] best_bid;
  wire [PRICE_WIDTH-1:0] best_ask;
  assign best_bid = bid_sorted[7*PRICE_WIDTH +: PRICE_WIDTH];
  assign best_ask = ask_sorted[0 +: PRICE_WIDTH];

  sorting_engine #(
      .WIDTH(PRICE_WIDTH)
  ) u_bid_sort (
      .clk(clk),
      .rst(rst),
      .start(sort_start),
      .in_data(bid_orders),
      .done(bid_done),
      .out_data(bid_sorted)
  );

  sorting_engine #(
      .WIDTH(PRICE_WIDTH)
  ) u_ask_sort (
      .clk(clk),
      .rst(rst),
      .start(sort_start),
      .in_data(ask_orders),
      .done(ask_done),
      .out_data(ask_sorted)
  );

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state         <= ST_IDLE;
      cycle_count   <= 6'd0;
      match_valid   <= 1'b0;
      matched_price <= {PRICE_WIDTH{1'b0}};
      done          <= 1'b0;
      latency_error <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        ST_IDLE: begin
          cycle_count   <= 6'd0;
              match_valid   <= 1'b0;
          matched_price <= {PRICE_WIDTH{1'b0}};
          latency_error <= 1'b0;

          if (start) begin
            state <= ST_WAIT_SORT;
          end
        end

        ST_WAIT_SORT: begin
          cycle_count <= cycle_count + 6'd1;

          if (bid_done && ask_done) begin
            if (best_bid >= best_ask) begin
              match_valid   <= 1'b1;
              matched_price <= best_ask;
            end else begin
              match_valid   <= 1'b0;
              matched_price <= {PRICE_WIDTH{1'b0}};
            end
            done          <= 1'b1;
            latency_error <= 1'b0;
            state         <= ST_IDLE;
          end
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
