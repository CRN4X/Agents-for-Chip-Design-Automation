`timescale 1ns/1ps

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
  wire                            parity_error;
  wire                            invalid_mapping_error;

  // Lightweight input conditioning hook; currently pass-through.
  wire [NUM_LANES*DATA_WIDTH-1:0] conditioned_data_in = data_in;

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
    .data_in(conditioned_data_in),
    .swizzle_map_flat(swizzle_map_flat),
    .operation_mode(operation_mode),
    .data_out(swizzler_data_out),
    .parity_error(parity_error),
    .invalid_mapping_error(invalid_mapping_error)
  );

  wire [NUM_LANES*DATA_WIDTH-1:0] lane_lsb_inverted;
  genvar lane;
  generate
    for (lane = 0; lane < NUM_LANES; lane = lane + 1) begin : GEN_OUT_ADJUST
      assign lane_lsb_inverted[DATA_WIDTH*(lane+1)-1:DATA_WIDTH*lane] =
        swizzler_data_out[DATA_WIDTH*(lane+1)-1:DATA_WIDTH*lane] ^ {{(DATA_WIDTH-1){1'b0}}, 1'b1};
    end
  endgenerate

  reg [DATA_WIDTH-1:0] checksum_r;
  integer i;
  always @* begin
    checksum_r = {DATA_WIDTH{1'b0}};
    for (i = 0; i < NUM_LANES; i = i + 1) begin
      checksum_r = checksum_r ^ lane_lsb_inverted[DATA_WIDTH*i +: DATA_WIDTH];
    end
  end

  wire checksum_mismatch = (checksum_r != EXPECTED_CHECKSUM);
  wire top_error_next    = invalid_mapping_error | checksum_mismatch;

  generate
    if (REGISTER_OUTPUT) begin : GEN_REG_OUT
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          final_data_out <= {NUM_LANES*DATA_WIDTH{1'b0}};
          top_error <= 1'b0;
        end else begin
          final_data_out <= lane_lsb_inverted;
          top_error <= top_error_next;
        end
      end
    end else begin : GEN_COMB_OUT
      always @* begin
        final_data_out = lane_lsb_inverted;
        top_error = top_error_next;
      end
    end
  endgenerate

endmodule
