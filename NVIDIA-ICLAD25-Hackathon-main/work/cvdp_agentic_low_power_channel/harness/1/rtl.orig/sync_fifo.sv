module sync_fifo #(
  parameter DEPTH   = 8,  // Must be power-of-two for ring-pointer indexing
  parameter DATA_W  = 8
)(
  input  wire              clk,
  input  wire              reset,

  input  wire              push_i,
  input  wire [DATA_W-1:0] push_data_i,

  input  wire              pop_i,
  output wire [DATA_W-1:0] pop_data_o,

  output wire              full_o,
  output wire              empty_o
);

  localparam PTR_W = $clog2(DEPTH);

  logic [PTR_W:0] rd_ptr_q, nxt_rd_ptr;
  logic [PTR_W:0] wr_ptr_q, nxt_wr_ptr;

  // Memory array of size DEPTH=8
  logic [DATA_W-1:0] fifo_mem [0:DEPTH-1];
  logic [DATA_W-1:0] fifo_pop_data;

  assign pop_data_o = fifo_pop_data;

  // Pointer flops
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      rd_ptr_q <= '0;
      wr_ptr_q <= '0;
    end else begin
      rd_ptr_q <= nxt_rd_ptr;
      wr_ptr_q <= nxt_wr_ptr;
    end
  end

  // Next-state logic for pointers
  always_comb begin
    // Default no movement
    nxt_rd_ptr    = rd_ptr_q;
    nxt_wr_ptr    = wr_ptr_q;
    fifo_pop_data = fifo_mem[rd_ptr_q[PTR_W-1:0]];

    case ({pop_i, push_i})
      2'b01: // PUSH
        nxt_wr_ptr = wr_ptr_q + 1;
      2'b10: // POP
        nxt_rd_ptr = rd_ptr_q + 1;
      2'b11: // PUSH + POP
        begin
          nxt_wr_ptr = wr_ptr_q + 1;
          nxt_rd_ptr = rd_ptr_q + 1;
        end
      default: /* 2'b00 */ ;
    endcase
  end

  // Write memory
  always_ff @(posedge clk) begin
    if (push_i) begin
      fifo_mem[wr_ptr_q[PTR_W-1:0]] <= push_data_i;
    end
  end

  // Empty/Full checks
  assign empty_o = (wr_ptr_q == rd_ptr_q);
  assign full_o  = (wr_ptr_q[PTR_W]  != rd_ptr_q[PTR_W]) &&
                   (wr_ptr_q[PTR_W-1:0] == rd_ptr_q[PTR_W-1:0]);

endmodule