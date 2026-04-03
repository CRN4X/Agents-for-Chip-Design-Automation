`timescale 1ns/1ps

module tb_signed_comparator;

reg clk;
reg rst_n;
reg enable;
reg bypass;
reg signed [15:0] a;
reg signed [15:0] b;
wire gt, lt, eq;

localparam DATA_WIDTH       = 16;
localparam REGISTER_OUTPUT  = 1;
localparam ENABLE_TOLERANCE = 1;
localparam TOLERANCE        = 2;
localparam SHIFT_LEFT       = 1;

signed_comparator #(
  .DATA_WIDTH(DATA_WIDTH),
  .REGISTER_OUTPUT(REGISTER_OUTPUT),
  .ENABLE_TOLERANCE(ENABLE_TOLERANCE),
  .TOLERANCE(TOLERANCE),
  .SHIFT_LEFT(SHIFT_LEFT)
) dut (
  .clk(clk),
  .rst_n(rst_n),
  .enable(enable),
  .bypass(bypass),
  .a(a),
  .b(b),
  .gt(gt),
  .lt(lt),
  .eq(eq)
);

always #5 clk = ~clk;

initial begin
  clk = 0;
  rst_n = 0;
  enable = 0;
  bypass = 0;
  a = 0;
  b = 0;
  repeat(2) @(posedge clk);
  rst_n = 1;
  repeat(2) @(posedge clk);

  test_case( 100,  100, 0, 1);
  test_case(  10,  -10, 0, 1);
  test_case(  -5,    5, 0, 1);
  test_case(  50,   52, 0, 1);  // near difference -> tolerance
  test_case(  51,   52, 0, 1);  // difference 1 -> eq due to TOLERANCE=2
  test_case(  53,   50, 0, 1);  // difference 3 -> not within tolerance
  test_case( 123, -123, 1, 1);  // bypass => eq=1
  test_case( 500, -500, 0, 0);  // enable=0 => eq=0,gt=0,lt=0
  repeat(2) @(posedge clk);

  integer i;
  for (i = 0; i < 5; i = i + 1) begin
    test_case($random, $random, $random%2, $random%2);
  end

  $finish;
end

task test_case;
  input signed [15:0] a_val;
  input signed [15:0] b_val;
  input bypass_val;
  input enable_val;
begin
  a = a_val;
  b = b_val;
  bypass = bypass_val;
  enable = enable_val;
  @(posedge clk);
  @(posedge clk);

  check_output(a_val, b_val, bypass_val, enable_val);
end
endtask

task check_output;
  input signed [15:0] a_val;
  input signed [15:0] b_val;
  input bypass_val;
  input enable_val;
  reg signed [DATA_WIDTH-1:0] a_shift, b_shift;
  reg signed [DATA_WIDTH:0] diff_abs;
  reg exp_gt, exp_lt, exp_eq;
begin
  a_shift = a_val <<< SHIFT_LEFT;
  b_shift = b_val <<< SHIFT_LEFT;
  diff_abs = (a_shift - b_shift);
  if (diff_abs < 0) diff_abs = -diff_abs;

  if (bypass_val) begin
    exp_gt = 0; exp_lt = 0; exp_eq = 1;
  end else if (!enable_val) begin
    exp_gt = 0; exp_lt = 0; exp_eq = 0;
  end else begin
    if (ENABLE_TOLERANCE && (diff_abs <= TOLERANCE)) begin
      exp_gt = 0; exp_lt = 0; exp_eq = 1;
    end else if (a_shift > b_shift) begin
      exp_gt = 1; exp_lt = 0; exp_eq = 0;
    end else if (a_shift < b_shift) begin
      exp_gt = 0; exp_lt = 1; exp_eq = 0;
    end else begin
      exp_gt = 0; exp_lt = 0; exp_eq = 1;
    end
  end

  if (gt !== exp_gt || lt !== exp_lt || eq !== exp_eq) begin
    $display("Time=%0t FAIL: a=%d b=%d bypass=%b en=%b SHIFT_LEFT=%0d TOL=%0d => gt=%b lt=%b eq=%b (exp: %b %b %b)",
      $time, a_val, b_val, bypass_val, enable_val, SHIFT_LEFT, TOLERANCE,
      gt, lt, eq, exp_gt, exp_lt, exp_eq);
  end else begin
    $display("Time=%0t PASS: a=%d b=%d bypass=%b en=%b SHIFT_LEFT=%0d TOL=%0d => gt=%b lt=%b eq=%b",
      $time, a_val, b_val, bypass_val, enable_val, SHIFT_LEFT, TOLERANCE, gt, lt, eq);
  end
end
endtask

endmodule