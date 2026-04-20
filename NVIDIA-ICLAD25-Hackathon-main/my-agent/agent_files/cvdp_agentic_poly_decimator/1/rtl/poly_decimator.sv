`timescale 1ns/1ps

module poly_decimator #(
  parameter int M           = 4,
  parameter int TAPS        = 8,
  parameter int COEFF_WIDTH = 16,
  parameter int DATA_WIDTH  = 16,
  localparam int ACC_WIDTH  = DATA_WIDTH + COEFF_WIDTH + $clog2(TAPS),
  localparam int TOTAL_TAPS = M * TAPS
) (
  input  logic                                clk,
  input  logic                                arst_n,
  input  logic [DATA_WIDTH-1:0]               in_sample,
  input  logic                                in_valid,
  output logic                                in_ready,
  output logic [ACC_WIDTH+$clog2(M)-1:0]      out_sample,
  output logic                                out_valid
);

  localparam int SAMPLE_CNT_W = (M > 1) ? $clog2(M) : 1;

  logic [DATA_WIDTH-1:0] shift_window [0:TOTAL_TAPS-1];
  logic                  shift_data_val;

  logic [SAMPLE_CNT_W-1:0] sample_cnt;
  logic                    decim_pending;
  logic                    branch_start;
  logic                    in_accept;

  logic [ACC_WIDTH-1:0] branch_out   [0:M-1];
  logic                 branch_valid [0:M-1];
  logic                 branches_all_valid;

  logic [ACC_WIDTH+$clog2(M)-1:0] tree_sum;
  logic                           tree_valid;

  assign in_ready  = arst_n;
  assign in_accept = in_valid && in_ready;

  shift_register #(
    .TAPS(TOTAL_TAPS),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_shift_reg_decim (
    .clk         (clk),
    .arst_n      (arst_n),
    .load        (in_accept),
    .new_sample  (in_sample),
    .data_out    (shift_window),
    .data_out_val(shift_data_val)
  );

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      sample_cnt     <= '0;
      decim_pending  <= 1'b0;
      branch_start   <= 1'b0;
    end else begin
      branch_start <= decim_pending;

      if (in_accept) begin
        if (sample_cnt == M-1) begin
          sample_cnt    <= '0;
          decim_pending <= 1'b1;
        end else begin
          sample_cnt    <= sample_cnt + 1'b1;
          decim_pending <= 1'b0;
        end
      end else begin
        decim_pending <= 1'b0;
      end
    end
  end

  generate
    for (genvar p = 0; p < M; p = p + 1) begin : poly_branches
      logic [DATA_WIDTH-1:0] branch_samples [0:TAPS-1];

      for (genvar t = 0; t < TAPS; t = t + 1) begin : map_samples
        assign branch_samples[t] = shift_window[p + (t * M)];
      end

      poly_filter #(
        .M          (M),
        .TAPS       (TAPS),
        .COEFF_WIDTH(COEFF_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
      ) u_poly_filter (
        .clk         (clk),
        .arst_n      (arst_n),
        .sample_buffer(branch_samples),
        .valid_in    (branch_start),
        .phase       (p[$clog2(M)-1:0]),
        .filter_out  (branch_out[p]),
        .valid       (branch_valid[p])
      );
    end
  endgenerate

  always_comb begin
    branches_all_valid = 1'b1;
    for (int i = 0; i < M; i = i + 1) begin
      branches_all_valid &= branch_valid[i];
    end
  end

  adder_tree #(
    .NUM_INPUTS(M),
    .DATA_WIDTH(ACC_WIDTH)
  ) u_adder_tree_decim (
    .clk      (clk),
    .arst_n   (arst_n),
    .valid_in (branches_all_valid),
    .data_in  (branch_out),
    .sum_out  (tree_sum),
    .valid_out(tree_valid)
  );

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      out_sample <= '0;
      out_valid  <= 1'b0;
    end else begin
      out_sample <= tree_sum;
      out_valid  <= tree_valid;
    end
  end

endmodule
