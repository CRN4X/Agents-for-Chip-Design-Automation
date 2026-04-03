`timescale 1ns/1ps

module tb_swizzler;
  parameter NUM_LANES = 4;
  parameter DATA_WIDTH = 8;
  parameter REGISTER_OUTPUT = 1;
  parameter ENABLE_PARITY_CHECK = 0;
  parameter OP_MODE_WIDTH = 2;
  parameter SWIZZLE_MAP_WIDTH = 3;

  reg clk;
  reg rst_n;
  reg bypass;
  reg [NUM_LANES*DATA_WIDTH-1:0] data_in;
  reg [NUM_LANES*SWIZZLE_MAP_WIDTH-1:0] swizzle_map_flat;
  reg [OP_MODE_WIDTH-1:0] operation_mode;
  wire [NUM_LANES*DATA_WIDTH-1:0] data_out;
  wire parity_error;
  wire invalid_mapping_error;

  swizzler #(
    .NUM_LANES(NUM_LANES),
    .DATA_WIDTH(DATA_WIDTH),
    .REGISTER_OUTPUT(REGISTER_OUTPUT),
    .ENABLE_PARITY_CHECK(ENABLE_PARITY_CHECK),
    .OP_MODE_WIDTH(OP_MODE_WIDTH),
    .SWIZZLE_MAP_WIDTH(SWIZZLE_MAP_WIDTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .bypass(bypass),
    .data_in(data_in),
    .swizzle_map_flat(swizzle_map_flat),
    .operation_mode(operation_mode),
    .data_out(data_out),
    .parity_error(parity_error),
    .invalid_mapping_error(invalid_mapping_error)
  );

  reg [DATA_WIDTH-1:0] expected [0:NUM_LANES-1];
  reg [DATA_WIDTH-1:0] out_lane [0:NUM_LANES-1];
  integer i;

  function [DATA_WIDTH-1:0] bit_reverse;
    input [DATA_WIDTH-1:0] in;
    integer j;
    reg [DATA_WIDTH-1:0] out;
    begin
      out = 0;
      for(j = 0; j < DATA_WIDTH; j = j + 1)
        out[j] = in[DATA_WIDTH-1-j];
      bit_reverse = out;
    end
  endfunction

  function [DATA_WIDTH-1:0] get_lane;
    input integer index;
    begin
      get_lane = data_out[DATA_WIDTH*(index+1)-1 -: DATA_WIDTH];
    end
  endfunction

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    bypass = 0;
    data_in = 0;
    swizzle_map_flat = 0;
    operation_mode = 0;
    #12;
    rst_n = 1;
    repeat (5) @(posedge clk);
    // TEST 1: Bypass disabled, identity mapping with bit reversal.
    data_in = {8'h04, 8'h03, 8'h02, 8'h01};
    swizzle_map_flat = {3'b011, 3'b010, 3'b001, 3'b000};
    bypass = 0;
    operation_mode = 0;
    repeat (5) @(posedge clk);
    for(i = 0; i < NUM_LANES; i = i + 1)
      out_lane[i] = get_lane(i);
    expected[0] = bit_reverse(8'h01);
    expected[1] = bit_reverse(8'h02);
    expected[2] = bit_reverse(8'h03);
    expected[3] = bit_reverse(8'h04);
    if(out_lane[0]==expected[0] && out_lane[1]==expected[1] &&
       out_lane[2]==expected[2] && out_lane[3]==expected[3])
      $display("TEST 1 PASS");
    else
      $display("TEST 1 FAIL: Expected %h %h %h %h, Got %h %h %h %h",
               expected[0], expected[1], expected[2], expected[3],
               out_lane[0], out_lane[1], out_lane[2], out_lane[3]);
    if(invalid_mapping_error==0)
      $display("TEST 1 INVALID MAPPING PASS");
    else
      $display("TEST 1 INVALID MAPPING FAIL");

    // TEST 2: Reverse mapping.
    data_in = {8'hAA, 8'hBB, 8'hCC, 8'hDD};
    swizzle_map_flat = {3'b000, 3'b001, 3'b010, 3'b011};
    bypass = 0;
    operation_mode = 0;
    repeat (5) @(posedge clk);
    for(i = 0; i < NUM_LANES; i = i + 1)
      out_lane[i] = get_lane(i);
    // Expected output is reversed compared to input lane order.
    expected[0] = bit_reverse(8'hAA);
    expected[1] = bit_reverse(8'hBB);
    expected[2] = bit_reverse(8'hCC);
    expected[3] = bit_reverse(8'hDD);
    if(out_lane[0]==expected[0] && out_lane[1]==expected[1] &&
       out_lane[2]==expected[2] && out_lane[3]==expected[3])
      $display("TEST 2 PASS");
    else
      $display("TEST 2 FAIL: Expected %h %h %h %h, Got %h %h %h %h",
               expected[0], expected[1], expected[2], expected[3],
               out_lane[0], out_lane[1], out_lane[2], out_lane[3]);

    // TEST 3: Bypass mode active.
    data_in = {8'h11, 8'h22, 8'h33, 8'h44};
    swizzle_map_flat = {3'b001, 3'b000, 3'b011, 3'b010};
    bypass = 1;
    operation_mode = 0;
    repeat (5) @(posedge clk);
    for(i = 0; i < NUM_LANES; i = i + 1)
      out_lane[i] = get_lane(i);
    expected[0] = bit_reverse(8'h44);
    expected[1] = bit_reverse(8'h33);
    expected[2] = bit_reverse(8'h22);
    expected[3] = bit_reverse(8'h11);
    if(out_lane[0]==expected[0] && out_lane[1]==expected[1] &&
       out_lane[2]==expected[2] && out_lane[3]==expected[3])
      $display("TEST 3 PASS");
    else
      $display("TEST 3 FAIL: Expected %h %h %h %h, Got %h %h %h %h",
               expected[0], expected[1], expected[2], expected[3],
               out_lane[0], out_lane[1], out_lane[2], out_lane[3]);

    // TEST 4: Invalid mapping detection.
    data_in = {8'h55, 8'h66, 8'h77, 8'h88};
    swizzle_map_flat = {3'b011, 3'b010, 3'b001, 3'b100};
    bypass = 0;
    operation_mode = 0;
    repeat (5) @(posedge clk);
    if(invalid_mapping_error==1)
      $display("TEST 4 PASS: Invalid mapping detected");
    else
      $display("TEST 4 FAIL: Invalid mapping not detected");
    $finish;
  end

endmodule