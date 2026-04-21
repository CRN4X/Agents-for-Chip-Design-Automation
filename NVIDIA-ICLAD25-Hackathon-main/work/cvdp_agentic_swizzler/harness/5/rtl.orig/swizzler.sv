`timescale 1ns/1ps

module swizzler #(
  parameter integer NUM_LANES           = 4,
  parameter integer DATA_WIDTH          = 8,
  parameter integer REGISTER_OUTPUT     = 0,
  parameter integer ENABLE_PARITY_CHECK = 0,
  parameter integer OP_MODE_WIDTH       = 2,
  parameter integer SWIZZLE_MAP_WIDTH   = $clog2(NUM_LANES)+1
)(
  input  wire                           clk,
  input  wire                           rst_n,
  input  wire                           bypass,
  input  wire [NUM_LANES*DATA_WIDTH-1:0]  data_in,
  input  wire [NUM_LANES*SWIZZLE_MAP_WIDTH-1:0] swizzle_map_flat,
  input  wire [OP_MODE_WIDTH-1:0]         operation_mode,
  output reg  [NUM_LANES*DATA_WIDTH-1:0]  data_out,
  output reg                            parity_error,
  output reg                            invalid_mapping_error
);

  // Unpack data_in into lanes
  wire [DATA_WIDTH-1:0] lane_in [0:NUM_LANES-1];
  genvar gi;
  generate
    for (gi = 0; gi < NUM_LANES; gi = gi + 1) begin : UNPACK_INPUT
      assign lane_in[gi] = data_in[DATA_WIDTH*(gi+1)-1 : DATA_WIDTH*gi];
    end
  endgenerate

  // Unpack swizzle_map_flat into swizzle_map array
  wire [SWIZZLE_MAP_WIDTH-1:0] swizzle_map [0:NUM_LANES-1];
  generate
    for (gi = 0; gi < NUM_LANES; gi = gi + 1) begin : UNPACK_SWIZZLE
      assign swizzle_map[gi] = swizzle_map_flat[SWIZZLE_MAP_WIDTH*(gi+1)-1 : SWIZZLE_MAP_WIDTH*gi];
    end
  endgenerate

  // Invalid mapping detection
  wire [NUM_LANES-1:0] invalid_map_flag;
  generate
    for (gi = 0; gi < NUM_LANES; gi = gi + 1) begin : INVALID_CHECK
      assign invalid_map_flag[gi] = (swizzle_map[gi] >= NUM_LANES) ? 1'b1 : 1'b0;
    end
  endgenerate
  wire invalid_mapping_detected = |invalid_map_flag;

  // Remap lanes according to swizzle_map or bypass
  wire [DATA_WIDTH-1:0] swizzled [0:NUM_LANES-1];
  generate
    for (gi = 0; gi < NUM_LANES; gi = gi + 1) begin : REMAP
      // Use lower bits of swizzle_map to index valid lanes.
      assign swizzled[gi] = bypass ? lane_in[gi] : lane_in[ swizzle_map[gi][$clog2(NUM_LANES)-1:0] ];
    end
  endgenerate

  // Pipeline Stage 1: Capture swizzled lanes
  reg [DATA_WIDTH-1:0] swizzle_reg [0:NUM_LANES-1];
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      for (i = 0; i < NUM_LANES; i = i + 1)
        swizzle_reg[i] <= {DATA_WIDTH{1'b0}};
    else
      for (i = 0; i < NUM_LANES; i = i + 1)
        swizzle_reg[i] <= swizzled[i];
  end

  // Pipeline Stage 2: Capture operation mode and invalid mapping status
  reg [OP_MODE_WIDTH-1:0] op_reg;
  reg op_invalid_reg;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      op_reg <= {OP_MODE_WIDTH{1'b0}};
      op_invalid_reg <= 1'b0;
    end else begin
      op_reg <= operation_mode;
      op_invalid_reg <= invalid_mapping_detected;
    end
  end

  // Bit reversal function
  function automatic [DATA_WIDTH-1:0] bit_reverse;
    input [DATA_WIDTH-1:0] in;
    integer k;
    begin
      bit_reverse = {DATA_WIDTH{1'b0}};
      for (k = 0; k < DATA_WIDTH; k = k + 1)
        bit_reverse[k] = in[DATA_WIDTH-1-k];
    end
  endfunction

  // Pipeline Stage 3: Final output stage with bit reversal
  reg [DATA_WIDTH-1:0] final_reg [0:NUM_LANES-1];
  integer m;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      for (m = 0; m < NUM_LANES; m = m + 1)
        final_reg[m] <= {DATA_WIDTH{1'b0}};
    else
      for (m = 0; m < NUM_LANES; m = m + 1)
        final_reg[m] <= bit_reverse(swizzle_reg[m]);
  end

  // Pack final_reg into a flat output vector
  wire [NUM_LANES*DATA_WIDTH-1:0] final_packed;
  genvar q;
  generate
    for (q = 0; q < NUM_LANES; q = q + 1) begin : PACK_FINAL
      assign final_packed[DATA_WIDTH*(q+1)-1 : DATA_WIDTH*q] = final_reg[q];
    end
  endgenerate

  generate
    if (REGISTER_OUTPUT) begin : REG_FINAL
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
          data_out <= {NUM_LANES*DATA_WIDTH{1'b0}};
        else
          data_out <= final_packed;
      end
    end else begin : COMB_FINAL
      always @* begin
        data_out = final_packed;
      end
    end
  endgenerate

  // Updated parity error calculation using a generate block
  generate
    if (ENABLE_PARITY_CHECK) begin : GEN_PARITY
      // Calculate parity from final_reg if parity check is enabled.
      wire [NUM_LANES-1:0] final_parity;
      genvar p;
      for (p = 0; p < NUM_LANES; p = p + 1) begin : PARITY_CALC
        assign final_parity[p] = ^final_reg[p];
      end
      wire computed_parity = |final_parity;
      always @* begin
        parity_error = computed_parity;
      end
    end else begin : NO_PARITY
      // Drive parity_error to 0 when parity check is disabled.
      always @* begin
        parity_error = 1'b0;
      end
    end
  endgenerate

  // Pass the invalid mapping flag
  always @* begin
    invalid_mapping_error = op_invalid_reg;
  end

endmodule