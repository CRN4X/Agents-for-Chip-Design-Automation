`timescale 1ns/1ns

module signed_comparator #(
  parameter integer DATA_WIDTH = 16,
  parameter integer REGISTER_OUTPUT = 0,
  parameter integer ENABLE_TOLERANCE = 0,
  parameter integer TOLERANCE = 0,
  parameter integer SHIFT_LEFT = 0
)(
  input  wire clk,
  input  wire rst_n,
  input  wire enable,
  input  wire bypass,
  input  wire signed [DATA_WIDTH-1:0] a,
  input  wire signed [DATA_WIDTH-1:0] b,
  output reg gt,
  output reg lt,
  output reg eq
);

  localparam integer SHIFTED_WIDTH = DATA_WIDTH + SHIFT_LEFT;

  wire signed [SHIFTED_WIDTH-1:0] a_shifted;
  wire signed [SHIFTED_WIDTH-1:0] b_shifted;
  wire signed [SHIFTED_WIDTH:0] diff;
  wire [SHIFTED_WIDTH:0] abs_diff;
  wire eq_tolerance;

  reg gt_next;
  reg lt_next;
  reg eq_next;

  assign a_shifted = $signed(a) <<< SHIFT_LEFT;
  assign b_shifted = $signed(b) <<< SHIFT_LEFT;
  assign diff = $signed({a_shifted[SHIFTED_WIDTH-1], a_shifted}) -
                $signed({b_shifted[SHIFTED_WIDTH-1], b_shifted});
  assign abs_diff = diff[SHIFTED_WIDTH] ? $unsigned(-diff) : $unsigned(diff);
  assign eq_tolerance = (ENABLE_TOLERANCE != 0) && (abs_diff <= TOLERANCE);

  always @(*) begin
    gt_next = 1'b0;
    lt_next = 1'b0;
    eq_next = 1'b0;

    if (bypass) begin
      eq_next = 1'b1;
    end else if (enable) begin
      if (eq_tolerance) begin
        eq_next = 1'b1;
      end else if (a_shifted > b_shifted) begin
        gt_next = 1'b1;
      end else if (a_shifted < b_shifted) begin
        lt_next = 1'b1;
      end else begin
        eq_next = 1'b1;
      end
    end
  end

  generate
    if (REGISTER_OUTPUT != 0) begin : g_registered_output
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          gt <= 1'b0;
          lt <= 1'b0;
          eq <= 1'b0;
        end else begin
          gt <= gt_next;
          lt <= lt_next;
          eq <= eq_next;
        end
      end
    end else begin : g_comb_output
      always @(*) begin
        gt = gt_next;
        lt = lt_next;
        eq = eq_next;
      end
    end
  endgenerate

endmodule
