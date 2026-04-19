module signed_comparator #(
  parameter integer DATA_WIDTH = 16,
  parameter integer REGISTER_OUTPUT = 0,
  parameter integer ENABLE_TOLERANCE = 0,
  parameter integer TOLERANCE = 0,
  parameter integer SHIFT_LEFT = 0
) (
  input  wire                         clk,
  input  wire                         rst_n,
  input  wire                         enable,
  input  wire                         bypass,
  input  wire signed [DATA_WIDTH-1:0] a,
  input  wire signed [DATA_WIDTH-1:0] b,
  output reg                          gt,
  output reg                          lt,
  output reg                          eq
);

  localparam integer EXT_WIDTH = DATA_WIDTH + SHIFT_LEFT;

  wire signed [EXT_WIDTH-1:0] a_shifted;
  wire signed [EXT_WIDTH-1:0] b_shifted;
  wire signed [EXT_WIDTH:0] diff;
  wire [EXT_WIDTH:0] abs_diff;
  wire [EXT_WIDTH:0] tol_ext;
  wire eq_tolerance;

  reg gt_n;
  reg lt_n;
  reg eq_n;

  assign a_shifted = $signed(a) <<< SHIFT_LEFT;
  assign b_shifted = $signed(b) <<< SHIFT_LEFT;
  assign diff = $signed(a_shifted) - $signed(b_shifted);
  assign abs_diff = diff[EXT_WIDTH] ? $unsigned(-diff) : $unsigned(diff);
  assign tol_ext = TOLERANCE[EXT_WIDTH:0];
  assign eq_tolerance = ENABLE_TOLERANCE ? (abs_diff <= tol_ext) : (a_shifted == b_shifted);

  always @* begin
    gt_n = 1'b0;
    lt_n = 1'b0;
    eq_n = 1'b0;

    if (bypass) begin
      eq_n = 1'b1;
    end else if (enable) begin
      if (eq_tolerance) begin
        eq_n = 1'b1;
      end else if (a_shifted > b_shifted) begin
        gt_n = 1'b1;
      end else if (a_shifted < b_shifted) begin
        lt_n = 1'b1;
      end else begin
        eq_n = 1'b1;
      end
    end
  end

  generate
    if (REGISTER_OUTPUT != 0) begin : gen_reg_out
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          gt <= 1'b0;
          lt <= 1'b0;
          eq <= 1'b0;
        end else begin
          gt <= gt_n;
          lt <= lt_n;
          eq <= eq_n;
        end
      end
    end else begin : gen_comb_out
      always @* begin
        gt = gt_n;
        lt = lt_n;
        eq = eq_n;
      end
    end
  endgenerate

endmodule
