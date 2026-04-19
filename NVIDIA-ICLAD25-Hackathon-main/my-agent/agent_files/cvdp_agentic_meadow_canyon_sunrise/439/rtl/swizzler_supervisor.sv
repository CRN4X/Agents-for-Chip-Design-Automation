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
  wire swizzler_parity_error;
  wire swizzler_invalid_mapping_error;

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
    .parity_error(swizzler_parity_error),
    .invalid_mapping_error(swizzler_invalid_mapping_error)
  );

  reg [DATA_WIDTH-1:0] checksum;
  integer i;
  always @* begin
    checksum = {DATA_WIDTH{1'b0}};
    for (i = 0; i < NUM_LANES; i = i + 1) begin
      checksum = checksum ^ swizzler_data_out[i*DATA_WIDTH +: DATA_WIDTH];
    end
  end

  wire checksum_mismatch = (checksum != EXPECTED_CHECKSUM);

  wire [NUM_LANES*DATA_WIDTH-1:0] lsb_inverted_data;
  genvar gi;
  generate
    for (gi = 0; gi < NUM_LANES; gi = gi + 1) begin : GEN_LSB_INVERT
      assign lsb_inverted_data[gi*DATA_WIDTH +: DATA_WIDTH] =
          swizzler_data_out[gi*DATA_WIDTH +: DATA_WIDTH] ^ {{(DATA_WIDTH-1){1'b0}}, 1'b1};
    end
  endgenerate

  wire top_error_next = swizzler_parity_error | swizzler_invalid_mapping_error | checksum_mismatch;

  generate
    if (REGISTER_OUTPUT) begin : GEN_REG_OUT
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          final_data_out <= {NUM_LANES*DATA_WIDTH{1'b0}};
          top_error <= 1'b0;
        end else begin
          final_data_out <= lsb_inverted_data;
          top_error <= top_error_next;
        end
      end
    end else begin : GEN_COMB_OUT
      always @* begin
        final_data_out = lsb_inverted_data;
        top_error = top_error_next;
      end
    end
  endgenerate

endmodule
