module poly_filter #(
  parameter  M           = 4,    // decimation factor
  parameter  TAPS        = 8,    // Taps per phase
  parameter  COEFF_WIDTH = 16,   // Coefficient bit width
  parameter  DATA_WIDTH  = 16,   // Sample data bit width
  localparam ACC_WIDTH   = DATA_WIDTH + COEFF_WIDTH + $clog2(TAPS)
)
(
  input  logic                         clk,
  input  logic                         arst_n,
  input  logic [DATA_WIDTH-1:0]        sample_buffer [0:TAPS-1],
  input  logic                         valid_in,
  // The branch's phase number
  input  logic [$clog2(M)-1:0]         phase,
  output logic [ACC_WIDTH-1:0]         filter_out,
  output logic                         valid
);

  // ---- Stage 0: Register the input sample vector and phase. ----
  logic [DATA_WIDTH-1:0] sample_reg [0:TAPS-1];
  logic [$clog2(M)-1:0]  phase_reg;
  logic                  valid_stage0;
  integer i;
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      for (i = 0; i < TAPS; i = i + 1)
        sample_reg[i] <= '0;
      phase_reg    <= '0;
      valid_stage0 <= 1'b0;
    end
    else begin
      if (valid_in) begin
        for (i = 0; i < TAPS; i = i + 1)
          sample_reg[i] <= sample_buffer[i];
        phase_reg    <= phase;
        valid_stage0 <= 1'b1;
      end
      else begin
        valid_stage0 <= 1'b0;
      end
    end
  end

  // ---- Stage 1: Coefficient Fetch ----
  logic [COEFF_WIDTH-1:0] coeff [0:TAPS-1];
  genvar j;
  generate
    for (j = 0; j < TAPS; j = j + 1) begin : coeff_fetch
      logic [$clog2(M*TAPS)-1:0] addr;
      assign addr = phase_reg * TAPS + j;
      coeff_ram #(
        .NUM_COEFFS(M*TAPS),
        .DATA_WIDTH(COEFF_WIDTH)
      ) u_coeff_ram (
        .clk     (clk),
        .addr    (addr),
        .data_out(coeff[j])
      );
    end
  endgenerate

  logic valid_stage1;
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n)
      valid_stage1 <= 1'b0;
    else
      valid_stage1 <= valid_stage0;
  end

  // ---- Stage 2: Multiply the registered samples with coefficients ----
  logic [DATA_WIDTH+COEFF_WIDTH-1:0] products [0:TAPS-1];
  integer k;
  always_comb begin
    for (k = 0; k < TAPS; k = k + 1)
      products[k] = sample_reg[k] * coeff[k];
  end

  // ---- Stage 3: Sum the products using the adder_tree ----
  logic [ACC_WIDTH-1:0] sum_result;
  logic                 valid_adder;
  adder_tree #(
    .NUM_INPUTS(TAPS),
    .DATA_WIDTH(DATA_WIDTH+COEFF_WIDTH)
  ) u_adder_tree_filter (
    .clk      (clk),
    .arst_n   (arst_n),
    .valid_in (valid_stage1),
    .data_in  (products),
    .sum_out  (sum_result),
    .valid_out(valid_adder)
  );

  // ---- Stage 4: Output Registration ----
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      filter_out <= '0;
      valid      <= 1'b0;
    end
    else begin
      filter_out <= sum_result;
      valid      <= valid_adder;
    end
  end

endmodule