`timescale 1ns/1ns

module low_power_channel (
  input  logic       clk,
  input  logic       reset,
  input  logic       if_wakeup_i,
  input  logic       wr_valid_i,
  input  logic [7:0] wr_payload_i,
  output logic       wr_flush_o,
  input  logic       wr_done_i,
  input  logic       rd_valid_i,
  output logic [7:0] rd_payload_o,
  input  logic       qreqn_i,
  output logic       qacceptn_o,
  output logic       qactive_o
);

  logic wr_fifo_push;
  logic wr_fifo_pop;
  logic wr_fifo_full;
  logic wr_fifo_empty;

  low_power_ctrl u_low_power_ctrl (
    .clk          (clk),
    .reset        (reset),
    .if_wakeup_i  (if_wakeup_i),
    .wr_fifo_full (wr_fifo_full),
    .wr_fifo_empty(wr_fifo_empty),
    .wr_valid_i   (wr_valid_i),
    .rd_valid_i   (rd_valid_i),
    .wr_done_i    (wr_done_i),
    .wr_flush_o   (wr_flush_o),
    .qreqn_i      (qreqn_i),
    .qacceptn_o   (qacceptn_o),
    .qactive_o    (qactive_o),
    .wr_fifo_push (wr_fifo_push),
    .wr_fifo_pop  (wr_fifo_pop)
  );

  sync_fifo #(
    .DEPTH  (8),
    .DATA_W (8)
  ) u_sync_fifo (
    .clk        (clk),
    .reset      (reset),
    .push_i     (wr_fifo_push),
    .push_data_i(wr_payload_i),
    .pop_i      (wr_fifo_pop),
    .pop_data_o (rd_payload_o),
    .full_o     (wr_fifo_full),
    .empty_o    (wr_fifo_empty)
  );

endmodule
