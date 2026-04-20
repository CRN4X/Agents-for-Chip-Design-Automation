module cache_controller (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] address,
    input  wire        read,
    input  wire        write,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data,
    output reg         hit,
    output reg  [31:0] mem_address,
    output reg         mem_write,
    output reg         mem_read,
    output reg  [31:0] mem_write_data,
    input  wire [31:0] mem_read_data,
    input  wire        mem_ready
);

  reg [31:0] cache_data [0:31];
  reg [4:0]  cache_tag  [0:31];
  reg        cache_valid[0:31];

  reg        pending_read;
  reg [4:0]  pending_index;
  reg [4:0]  pending_tag;
  reg [31:0] pending_address;

  integer i;
  reg [4:0] index;
  reg [4:0] tag;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1) begin
        cache_data[i]  <= 32'b0;
        cache_tag[i]   <= 5'b0;
        cache_valid[i] <= 1'b0;
      end
      read_data      <= 32'b0;
      hit            <= 1'b0;
      mem_address    <= 32'b0;
      mem_write      <= 1'b0;
      mem_read       <= 1'b0;
      mem_write_data <= 32'b0;
      pending_read   <= 1'b0;
      pending_index  <= 5'b0;
      pending_tag    <= 5'b0;
      pending_address<= 32'b0;
    end else begin
      mem_write <= 1'b0;
      mem_read  <= 1'b0;

      index = address[4:0];
      tag   = address[9:5];

      if (pending_read) begin
        mem_address <= pending_address;
        mem_read    <= 1'b1;
        if (mem_ready) begin
          cache_data[pending_index]  <= mem_read_data;
          cache_tag[pending_index]   <= pending_tag;
          cache_valid[pending_index] <= 1'b1;
          read_data                  <= mem_read_data;
          hit                        <= 1'b0;
          pending_read               <= 1'b0;
          mem_read                   <= 1'b0;
        end
      end

      if (write) begin
        mem_address    <= address;
        mem_write_data <= write_data;
        mem_write      <= 1'b1;

        if (cache_valid[index] && (cache_tag[index] == tag)) begin
          cache_data[index] <= write_data;
          hit               <= 1'b1;
        end else begin
          hit               <= 1'b0;
        end
      end else if (read && !pending_read) begin
        mem_address <= address;
        if (cache_valid[index] && (cache_tag[index] == tag)) begin
          read_data <= cache_data[index];
          hit       <= 1'b1;
        end else begin
          hit <= 1'b0;
          if (mem_ready) begin
            cache_data[index]  <= mem_read_data;
            cache_tag[index]   <= tag;
            cache_valid[index] <= 1'b1;
            read_data          <= mem_read_data;
          end else begin
            pending_read    <= 1'b1;
            pending_index   <= index;
            pending_tag     <= tag;
            pending_address <= address;
            mem_read        <= 1'b1;
          end
        end
      end
    end
  end

endmodule
