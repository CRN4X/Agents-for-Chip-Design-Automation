`timescale 1ns/1ps

module poly_decimator #(
  parameter M           = 4,
  parameter TAPS        = 8,
  parameter COEFF_WIDTH = 16,
  parameter DATA_WIDTH  = 16,
  localparam ACC_WIDTH  = DATA_WIDTH + COEFF_WIDTH + $clog2(TAPS),
  localparam TOTAL_TAPS = M * TAPS,
  localparam OUT_WIDTH  = ACC_WIDTH + $clog2(M),
  localparam CNT_WIDTH  = (M <= 1) ? 1 : $clog2(M)
) (
  input  logic                 clk,
  input  logic                 arst_n,
  input  logic [DATA_WIDTH-1:0] in_sample,
  input  logic                 in_valid,
  output logic                 in_ready,
  output logic [OUT_WIDTH-1:0] out_sample,
  output logic                 out_valid
);

  logic [DATA_WIDTH-1:0] shift_data [0:TOTAL_TAPS-1];
  logic shift_data_val;

  logic [CNT_WIDTH-1:0] sample_count;
  logic launch_pending;
  logic launch_filters;
  logic accept_sample;

  assign in_ready = 1'b1;
  assign accept_sample = in_valid & in_ready;

  shift_register #(
    .TAPS(TOTAL_TAPS),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_shift_reg_decim (
    .clk(clk),
    .arst_n(arst_n),
    .load(accept_sample),
    .new_sample(in_sample),
    .data_out(shift_data),
    .data_out_val(shift_data_val)
  );

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      sample_count   <= '0;
      launch_pending <= 1'b0;
      launch_filters <= 1'b0;
    end else begin
      launch_filters <= launch_pending;
      launch_pending <= 1'b0;

      if (accept_sample) begin
        if (sample_count == M-1) begin
          sample_count   <= '0;
          launch_pending <= 1'b1;
        end else begin
          sample_count <= sample_count + 1'b1;
        end
      end
    end
  end

  logic [ACC_WIDTH-1:0] branch_out   [0:M-1];
  logic                 branch_valid [0:M-1];

  generate
    genvar p, t;
    for (p = 0; p < M; p = p + 1) begin : poly_branches
      logic [DATA_WIDTH-1:0] branch_samples [0:TAPS-1];

      for (t = 0; t < TAPS; t = t + 1) begin : sample_map
        assign branch_samples[t] = shift_data[p + t*M];
      end

      poly_filter #(
        .M(M),
        .TAPS(TAPS),
        .COEFF_WIDTH(COEFF_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
      ) u_poly_filter (
        .clk(clk),
        .arst_n(arst_n),
        .sample_buffer(branch_samples),
        .valid_in(launch_filters),
        .phase(p[$clog2(M)-1:0]),
        .filter_out(branch_out[p]),
        .valid(branch_valid[p])
      );
    end
  endgenerate

  logic all_branches_valid;
  logic [OUT_WIDTH-1:0] adder_sum;
  logic adder_valid;

  always_comb begin
    all_branches_valid = 1'b1;
    for (int k = 0; k < M; k = k + 1) begin
      all_branches_valid = all_branches_valid & branch_valid[k];
    end
  end

  adder_tree #(
    .NUM_INPUTS(M),
    .DATA_WIDTH(ACC_WIDTH)
  ) u_adder_tree_decim (
    .clk(clk),
    .arst_n(arst_n),
    .valid_in(all_branches_valid),
    .data_in(branch_out),
    .sum_out(adder_sum),
    .valid_out(adder_valid)
  );

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      out_sample <= '0;
      out_valid  <= 1'b0;
    end else begin
      out_sample <= adder_sum;
      out_valid  <= adder_valid;
    end
  end

endmodule
