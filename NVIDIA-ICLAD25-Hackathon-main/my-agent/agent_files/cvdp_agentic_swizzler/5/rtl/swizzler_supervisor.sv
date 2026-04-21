`timescale 1ns/1ns

module swizzler_supervisor #(
  parameter integer NUM_LANES           = 4,
  parameter integer DATA_WIDTH          = 8,
  parameter integer REGISTER_OUTPUT     = 1,
  parameter integer ENABLE_PARITY_CHECK = 1,
  parameter integer OP_MODE_WIDTH       = 2,
  parameter integer SWIZZLE_MAP_WIDTH   = $clog2(NUM_LANES)+1,
  parameter [DATA_WIDTH-1:0] EXPECTED_CHECKSUM = 8'hA5
)(
  input  wire                             clk,
  input  wire                             rst_n,
  input  wire                             bypass,
  input  wire [NUM_LANES*DATA_WIDTH-1:0]  data_in,
  input  wire [NUM_LANES*SWIZZLE_MAP_WIDTH-1:0] swizzle_map_flat,
  input  wire [OP_MODE_WIDTH-1:0]         operation_mode,
  output reg  [NUM_LANES*DATA_WIDTH-1:0]  final_data_out,
  output reg                              top_error
);

  wire [NUM_LANES*DATA_WIDTH-1:0] swizzler_data_out;
  wire parity_error_unused;
  wire invalid_mapping_error;

  swizzler #(
    .NUM_LANES(NUM_LANES),
    .DATA_WIDTH(DATA_WIDTH),
    .REGISTER_OUTPUT(REGISTER_OUTPUT),
    .ENABLE_PARITY_CHECK(ENABLE_PARITY_CHECK),
    .OP_MODE_WIDTH(OP_MODE_WIDTH),
    .SWIZZLE_MAP_WIDTH(SWIZZLE_MAP_WIDTH)
  ) u_swizzler (
    .clk(clk),
    .rst_n(rst_n),
    .bypass(bypass),
    .data_in(data_in),
    .swizzle_map_flat(swizzle_map_flat),
    .operation_mode(operation_mode),
    .data_out(swizzler_data_out),
    .parity_error(parity_error_unused),
    .invalid_mapping_error(invalid_mapping_error)
  );

  reg [NUM_LANES*DATA_WIDTH-1:0] post_data;
  integer lane_idx;
  always @* begin
    post_data = swizzler_data_out;
    for (lane_idx = 0; lane_idx < NUM_LANES; lane_idx = lane_idx + 1) begin
      post_data[lane_idx*DATA_WIDTH] = ~swizzler_data_out[lane_idx*DATA_WIDTH];
    end
  end

  reg [DATA_WIDTH-1:0] checksum;
  integer chk_idx;
  always @* begin
    checksum = {DATA_WIDTH{1'b0}};
    for (chk_idx = 0; chk_idx < NUM_LANES; chk_idx = chk_idx + 1) begin
      checksum = checksum ^ post_data[DATA_WIDTH*(chk_idx+1)-1 -: DATA_WIDTH];
    end
  end

  wire checksum_mismatch = (checksum != EXPECTED_CHECKSUM);
  wire top_error_next = invalid_mapping_error | checksum_mismatch;

  generate
    if (REGISTER_OUTPUT) begin : GEN_REG_OUT
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          final_data_out <= {NUM_LANES*DATA_WIDTH{1'b0}};
          top_error <= 1'b0;
        end else begin
          final_data_out <= post_data;
          top_error <= top_error_next;
        end
      end
    end else begin : GEN_COMB_OUT
      always @* begin
        final_data_out = post_data;
        top_error = top_error_next;
      end
    end
  endgenerate

endmodule
