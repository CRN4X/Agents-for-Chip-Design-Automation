`timescale 1ns/1ps
module tb_image_stego;
  parameter row = 2;
  parameter col = 2;
  parameter max_bpp = 8;
  parameter KEY_WIDTH = 8;
  parameter CNT_WIDTH = 5;
  reg clk;
  reg rst;
  reg start;
  reg [2:0] mode;
  reg [(row*col*8)-1:0] img_in;
  reg [(row*col*max_bpp)-1:0] data_in;
  reg [2:0] bpp;
  reg [KEY_WIDTH-1:0] key;
  wire [(row*col*8)-1:0] img_out;
  wire [(row*col*max_bpp)-1:0] data_out;
  wire busy;
  wire done;
  wire [CNT_WIDTH-1:0] cycle_count;
  image_stego #(
    .row(row),
    .col(col),
    .max_bpp(max_bpp),
    .KEY_WIDTH(KEY_WIDTH),
    .CNT_WIDTH(CNT_WIDTH)
  ) dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .mode(mode),
    .img_in(img_in),
    .data_in(data_in),
    .bpp(bpp),
    .key(key),
    .img_out(img_out),
    .data_out(data_out),
    .busy(busy),
    .done(done),
    .cycle_count(cycle_count)
  );
  always #5 clk = ~clk;
  task drive_inputs;
    input [2:0] m;
    input [(row*col*8)-1:0] i_in;
    input [(row*col*max_bpp)-1:0] d_in;
    input [2:0] b;
    input [KEY_WIDTH-1:0] k;
    begin
      mode = m;
      img_in = i_in;
      data_in = d_in;
      bpp = b;
      key = k;
      start = 1;
      $display("T=%0t START=1 MODE=%0d BPP=%0d KEY=%0h IMG_IN=%0h DATA_IN=%0h", $time, mode, bpp, key, img_in, data_in);
      @(posedge clk);
      while(!done) begin
        @(posedge clk);
      end
      start = 0;
      $display("T=%0t DONE=1 IMG_OUT=%0h DATA_OUT=%0h BUSY=%0b CYCLE_COUNT=%0d", $time, img_out, data_out, busy, cycle_count);
      @(posedge clk);
    end
  endtask
  task drive_inputs_reset;
    input [2:0] m;
    input [(row*col*8)-1:0] i_in;
    input [(row*col*max_bpp)-1:0] d_in;
    input [2:0] b;
    input [KEY_WIDTH-1:0] k;
    begin
      mode = m;
      img_in = i_in;
      data_in = d_in;
      bpp = b;
      key = k;
      start = 1;
      @(posedge clk);
      repeat(2) @(posedge clk);
      rst = 1;
      @(posedge clk);
      rst = 0;
      start = 0;
      @(posedge clk);
    end
  endtask
  task drive_inputs_hold;
    input [2:0] m;
    input [(row*col*8)-1:0] i_in;
    input [(row*col*max_bpp)-1:0] d_in;
    input [2:0] b;
    input [KEY_WIDTH-1:0] k;
    begin
      mode = m;
      img_in = i_in;
      data_in = d_in;
      bpp = b;
      key = k;
      start = 1;
      $display("HOLD TEST: T=%0t START=1 MODE=%0d BPP=%0d KEY=%0h IMG_IN=%0h DATA_IN=%0h", $time, mode, bpp, key, img_in, data_in);
      @(posedge clk);
      while(!done) begin
        @(posedge clk);
      end
      $display("HOLD TEST: T=%0t DONE=1, holding START high", $time);
      @(posedge clk);
      start = 0;
      $display("HOLD TEST: T=%0t START deasserted", $time);
      @(posedge clk);
    end
  endtask
  task idle_test;
    begin
      start = 0;
      $display("IDLE TEST: T=%0t, waiting in idle", $time);
      repeat(3) @(posedge clk);
      $display("IDLE TEST: T=%0t, idle cycle complete", $time);
    end
  endtask
  integer i;
  reg [2:0] rand_mode;
  reg [(row*col*8)-1:0] rand_img;
  reg [(row*col*max_bpp)-1:0] rand_data;
  reg [2:0] rand_bpp;
  reg [KEY_WIDTH-1:0] rand_key;
  initial begin
    clk = 0;
    rst = 1;
    start = 0;
    mode = 0;
    img_in = 0;
    data_in = 0;
    bpp = 0;
    key = 0;
    repeat(5) @(posedge clk);
    rst = 0;
    repeat(5) @(posedge clk);
    drive_inputs(3'd0, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, 3'd0, 8'h00);
    drive_inputs(3'd1, 64'h0000000000000000, 64'hFFFFFFFFFFFFFFFF, 3'd7, 8'hFF);
    drive_inputs(3'd2, 64'h0123456789ABCDEF, 64'h1111111122222222, 3'd3, 8'h55);
    drive_inputs(3'd3, 64'h89ABCDEF01234567, 64'hAAAAAAAABBBBBBBB, 3'd4, 8'hA5);
    drive_inputs(3'd4, 64'hF0F0F0F00F0F0F0F, 64'h123456789ABCDEF0, 3'd5, 8'h33);
    drive_inputs(3'd5, 64'hFFFFFFFF00000000, 64'h00FF00FF00FF00FF, 3'd6, 8'hC3);
    drive_inputs(3'd6, 64'h1122334455667788, 64'h8877665544332211, 3'd2, 8'h0F);
    drive_inputs(3'd7, 64'h55555555AAAAAAAA, 64'hAAAAAAAA55555555, 3'd1, 8'hF0);
    drive_inputs(3'd0, 64'h12345678ABCDEF01, 64'h0000000000000000, 3'd3, 8'h80);
    drive_inputs(3'd1, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, 3'd0, 8'h00);
    drive_inputs(3'd0, 64'hAAAAAAAAAAAAAAAA, 64'h5555555555555555, 3'd7, 8'h55);
    drive_inputs(3'd3, 64'h0123456789ABCDEF, 64'h0000000000000000, 3'd0, 8'hAA);
    drive_inputs(3'd0, 64'hCCCCCCCCCCCCCCCC, 64'h3333333333333333, 3'b001, 8'h11);
    drive_inputs(3'd1, 64'h1111111111111111, 64'h2222222222222222, 3'b001, 8'h22);
    drive_inputs(3'd1, 64'h3333333333333333, 64'h4444444444444444, 3'b011, 8'h33);
    drive_inputs(3'd1, 64'h5555555555555555, 64'h6666666666666666, 3'b110, 8'h44);
    drive_inputs(3'd0, 64'hA5A5A5A5A5A5A5A5, 64'h5A5A5A5A5A5A5A5A, 3'b100, 8'h00);
    drive_inputs(3'd0, 64'h3C3C3C3C3C3C3C3C, 64'hC3C3C3C3C3C3C3C3, 3'b110, 8'h00);
    drive_inputs(3'd1, 64'hF0F0F0F0F0F0F0F0, 64'h0000000000000000, 3'b010, 8'h00);
    drive_inputs(3'd1, 64'h0F0F0F0F0F0F0F0F, 64'h0000000000000000, 3'b100, 8'h00);
    for(i = 0; i < 60; i = i + 1) begin
      rand_mode = $urandom_range(0,7);
      rand_img = $urandom;
      rand_img = (rand_img << 32) | $urandom;
      rand_data = $urandom;
      rand_data = (rand_data << 32) | $urandom;
      rand_bpp = $urandom_range(0,7);
      rand_key = $urandom_range(0,255);
      drive_inputs(rand_mode, rand_img, rand_data, rand_bpp, rand_key);
    end
    drive_inputs_reset(3'd4, 64'hDEADBEEFDEADBEEF, 64'hCAFEBABECAFEBABE, 3'd3, 8'h5A);
    drive_inputs_hold(3'd5, 64'h0F0F0F0F0F0F0F0F, 64'h00FF00FF00FF00FF, 3'd2, 8'h3C);
    idle_test();
    $display("Forcing state to invalid value to cover default branch");
    force dut.state = 2'b11;
    @(posedge clk);
    release dut.state;
    @(posedge clk);
    repeat(3) @(posedge clk);
    $display("Idle state test: BUSY=%0b DONE=%0b CYCLE_COUNT=%0d", busy, done, cycle_count);
    @(posedge clk);
    $finish;
  end
endmodule