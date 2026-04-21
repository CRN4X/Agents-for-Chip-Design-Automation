`timescale 1ns/1ns

module cache_controller (
    input  wire        clk,
    input  wire        reset,
    input  wire [4:0]  address,
    input  wire [31:0] write_data,
    input  wire        read,
    input  wire        write,
    output reg  [31:0] read_data,
    output reg         hit,
    output reg         miss,
    output reg         mem_write,
    output reg  [31:0] mem_address,
    output reg  [31:0] mem_write_data,
    input  wire [31:0] mem_read_data,
    input  wire        mem_ready
);

  reg [31:0] cache_data [0:31];
  reg [4:0]  cache_tag  [0:31];
  reg        cache_valid[0:31];

  wire [4:0] index;
  wire [4:0] tag;
  wire       line_hit;

  integer i;

  assign index = address;
  assign tag = address;
  assign line_hit = cache_valid[index] && (cache_tag[index] == tag);

  always @(posedge clk) begin
    if (reset) begin
      read_data <= 32'd0;
      hit <= 1'b0;
      miss <= 1'b0;
      mem_write <= 1'b0;
      mem_address <= 32'd0;
      mem_write_data <= 32'd0;
      for (i = 0; i < 32; i = i + 1) begin
        cache_data[i] <= 32'd0;
        cache_tag[i] <= 5'd0;
        cache_valid[i] <= 1'b0;
      end
    end else begin
      mem_write <= 1'b0;
      mem_address <= {27'd0, address};
      mem_write_data <= write_data;

      if (read) begin
        if (line_hit) begin
          hit <= 1'b1;
          read_data <= cache_data[index];
        end else begin
          miss <= 1'b1;
          if (mem_ready) begin
            cache_data[index] <= mem_read_data;
            cache_tag[index] <= tag;
            cache_valid[index] <= 1'b1;
            read_data <= mem_read_data;
          end
        end
      end

      if (write) begin
        mem_write <= 1'b1;
        mem_address <= {27'd0, address};
        mem_write_data <= write_data;

        if (line_hit) begin
          hit <= 1'b1;
          cache_data[index] <= write_data;
          read_data <= write_data;
        end else begin
          miss <= 1'b1;
        end
      end
    end
  end

endmodule
