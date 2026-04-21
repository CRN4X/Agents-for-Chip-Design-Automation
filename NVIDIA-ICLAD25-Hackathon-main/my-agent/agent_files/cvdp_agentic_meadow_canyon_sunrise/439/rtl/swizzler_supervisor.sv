`timescale 1ns/1ps

module swizzler_supervisor #(
  parameter integer NUM_LANES             = 4,
  parameter integer DATA_WIDTH            = 8,
  parameter integer REGISTER_OUTPUT       = 1,
  parameter integer ENABLE_PARITY_CHECK   = 1,
  parameter integer OP_MODE_WIDTH         = 2,
  parameter integer SWIZZLE_MAP_WIDTH     = $clog2(NUM_LANES)+1,
  parameter [DATA_WIDTH-1:0] EXPECTED_CHECKSUM = 8'hA5
)(
  input  wire                                clk,
  input  wire                                rst_n,
  input  wire                                bypass,
  input  wire [NUM_LANES*DATA_WIDTH-1:0]     data_in,
  input  wire [NUM_LANES*SWIZZLE_MAP_WIDTH-1:0] swizzle_map_flat,
  input  wire [OP_MODE_WIDTH-1:0]            operation_mode,
  output reg  [NUM_LANES*DATA_WIDTH-1:0]     final_data_out,
  output reg                                 top_error
);

  wire [NUM_LANES*DATA_WIDTH-1:0] swizzled_data;
  wire parity_error_int;
  wire invalid_mapping_error_int;

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
    .data_out(swizzled_data),
    .parity_error(parity_error_int),
    .invalid_mapping_error(invalid_mapping_error_int)
  );

  localparam [DATA_WIDTH-1:0] LSB_MASK = {{(DATA_WIDTH-1){1'b0}}, 1'b1};

  reg [NUM_LANES*DATA_WIDTH-1:0] final_data_comb;
  reg [DATA_WIDTH-1:0] checksum_comb;
  reg top_error_comb;
  integer lane_idx;

  always @* begin
    for (lane_idx = 0; lane_idx < NUM_LANES; lane_idx = lane_idx + 1) begin
      final_data_comb[lane_idx*DATA_WIDTH +: DATA_WIDTH] =
        swizzled_data[lane_idx*DATA_WIDTH +: DATA_WIDTH] ^ LSB_MASK;
    end

    checksum_comb = {DATA_WIDTH{1'b0}};
    for (lane_idx = 0; lane_idx < NUM_LANES; lane_idx = lane_idx + 1) begin
      checksum_comb = checksum_comb ^ final_data_comb[lane_idx*DATA_WIDTH +: DATA_WIDTH];
    end

    top_error_comb = parity_error_int |
                     invalid_mapping_error_int |
                     (checksum_comb != EXPECTED_CHECKSUM);
  end

  generate
    if (REGISTER_OUTPUT) begin : GEN_REGISTERED_OUT
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          final_data_out <= {NUM_LANES*DATA_WIDTH{1'b0}};
          top_error <= 1'b0;
        end else begin
          final_data_out <= final_data_comb;
          top_error <= top_error_comb;
        end
      end
    end else begin : GEN_COMB_OUT
      always @* begin
        final_data_out = final_data_comb;
        top_error = top_error_comb;
      end
    end
  endgenerate

endmodule
