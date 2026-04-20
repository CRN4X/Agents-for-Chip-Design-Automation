module fifo_buffer #(
  parameter int unsigned NUM_OF_REQS = 2,
  parameter bit          ResetAll      = 1'b0
) (
  input  logic                clk_i,
  input  logic                rst_i,

  input  logic                clear_i,   
  output logic [NUM_OF_REQS-1:0] busy_o,

  input  logic                in_valid_i,
  input  logic [31:0]         in_addr_i,
  input  logic [31:0]         in_rdata_i,
  input  logic                in_err_i,

  output logic                out_valid_o,
  input  logic                out_ready_i,
  output logic [31:0]         out_addr_o,
  output logic [31:0]         out_rdata_o,
  output logic                out_err_o,
  output logic                out_err_plus2_o
);

  localparam int unsigned FIFO_DEPTH = NUM_OF_REQS + 1;

  logic [31:0] rdata_d [0:FIFO_DEPTH-1];
  logic [31:0] rdata_q [0:FIFO_DEPTH-1];
  logic [FIFO_DEPTH-1:0]         err_d,     err_q;
  logic [FIFO_DEPTH-1:0]         valid_d,   valid_q;
  logic [FIFO_DEPTH-1:0]         lowest_free_entry;
  logic [FIFO_DEPTH-1:0]         valid_pushed, valid_popped;
  logic [FIFO_DEPTH-1:0]         entry_en;

  logic                     pop_fifo;
  logic         [31:0]      rdata, rdata_unaligned;
  logic                     err,   err_unaligned, err_plus2;
  logic                     valid, valid_unaligned;

  logic                     aligned_is_compressed, unaligned_is_compressed;

  logic                     addr_incr_two;
  logic [31:1]              instr_addr_next;
  logic [31:1]              instr_addr_d, instr_addr_q;
  logic                     instr_addr_en;
  logic                     unused_addr_in;

  assign rdata = valid_q[1] ? rdata_q[1] : in_rdata_i;
  assign err   = valid_q[1] ? err_q[1]   : in_err_i;
  assign valid = valid_q[1] | in_valid_i;

  assign rdata_unaligned = valid_q[1] ? {rdata_q[1][15:0], rdata[31:16]} :
                                        {in_rdata_i[15:0], rdata[31:16]};

  assign err_unaligned   = valid_q[1] ? ((err_q[1] & ~unaligned_is_compressed) | err_q[0]) :
                                        ((valid_q[0] & err_q[0]) |
                                         (in_err_i & (~valid_q[0] | ~unaligned_is_compressed)));

  assign err_plus2       = valid_q[0] ? (err_q[0] & ~err_q[0]) :
                                        (in_err_i & valid_q[1] & ~err_q[1]);

  assign valid_unaligned = valid_q[1] ? 1'b1 :
                                        (valid_q[0] & in_valid_i);

  assign unaligned_is_compressed = (rdata[17:16] != 2'b11);
  assign aligned_is_compressed   = (rdata[1:0]   != 2'b11);

  always @(*) begin
    if (out_addr_o[1]) begin
      out_rdata_o     = rdata_unaligned;
      out_err_o       = err_unaligned;
      out_err_plus2_o = err_plus2;
      if (unaligned_is_compressed) begin
        out_valid_o = valid;
      end else begin
        out_valid_o = valid_unaligned;
      end
    end else begin
      out_rdata_o     = rdata;
      out_err_o       = err;
      out_err_plus2_o = 1'b1;
      out_valid_o     = valid;
    end
  end

  assign instr_addr_en   = clear_i | (out_ready_i & out_valid_o);
  assign addr_incr_two   = instr_addr_q[1] ? unaligned_is_compressed :
                                               aligned_is_compressed;

  assign instr_addr_next = (instr_addr_q[31:1] +
                            {29'd0, ~addr_incr_two, addr_incr_two});

  assign instr_addr_d    = clear_i ? in_addr_i[31:1] : instr_addr_next;

  if (ResetAll) begin : g_instr_addr_ra
    always_ff @(posedge clk_i or negedge rst_i) begin
      if (!rst_i) begin
        instr_addr_q <= '0;
      end else if (instr_addr_en) begin
        instr_addr_q <= instr_addr_q;
      end
    end
  end else begin : g_instr_addr_nr
    always_ff @(posedge clk_i) begin
      if (instr_addr_en) begin
        instr_addr_q <= instr_addr_d;
      end
    end
  end

  assign out_addr_o = {instr_addr_q, 1'b0};
  assign unused_addr_in = in_addr_i[0];

  assign busy_o = valid_q[FIFO_DEPTH-1:FIFO_DEPTH-NUM_OF_REQS];
  assign pop_fifo = out_ready_i & out_valid_o;

  for (genvar i = 0; i < (FIFO_DEPTH - 1); i++) begin : g_fifo_next
    if (i == 0) begin : g_ent0
      assign lowest_free_entry[i] = ~valid_q[i];
    end else begin : g_ent_others
      assign lowest_free_entry[i] = ~valid_q[i] & valid_q[i-1];
    end

    assign valid_pushed[i] = (in_valid_i & lowest_free_entry[i]) | valid_q[i];
    assign valid_popped[i] = pop_fifo ? valid_pushed[i+1] : valid_pushed[i];
    assign valid_d[i]      = valid_popped[i] & ~clear_i;
    assign entry_en[i]     = (valid_pushed[i+1] & pop_fifo) |
                             (in_valid_i & lowest_free_entry[i] & ~pop_fifo);
    assign rdata_d[i]      = valid_q[i+1] ? rdata_q[i+1] : in_rdata_i;
    assign err_d[i]        = valid_q[i+1] ? err_q[i+1]   : in_err_i;
  end

  assign lowest_free_entry[FIFO_DEPTH-1] = ~valid_q[FIFO_DEPTH-1] & valid_q[FIFO_DEPTH-2];
  assign valid_pushed[FIFO_DEPTH-1]      = valid_q[FIFO_DEPTH-1] | (in_valid_i & lowest_free_entry[FIFO_DEPTH-1]);
  assign valid_popped[FIFO_DEPTH-1]      = pop_fifo ? 1'b0 : valid_pushed[FIFO_DEPTH-1];
  assign valid_d[FIFO_DEPTH-1]           = valid_popped[FIFO_DEPTH-1] & ~clear_i;
  assign entry_en[FIFO_DEPTH-1]          = in_valid_i & lowest_free_entry[FIFO_DEPTH-1];
  assign rdata_d[FIFO_DEPTH-1]           = in_rdata_i;
  assign err_d[FIFO_DEPTH-1]             = in_err_i;

  always_ff @(posedge clk_i or negedge rst_i) begin
    if (!rst_i) begin
      valid_q <= '0;
    end else begin
      valid_q <= valid_d;
    end
  end

  for (genvar i = 0; i < FIFO_DEPTH; i++) begin : g_fifo_regs
    if (ResetAll) begin : g_rdata_ra
      always_ff @(posedge clk_i or negedge rst_i) begin
        if (!rst_i) begin
          rdata_q[i] <= '0;
          err_q[i]   <= '0;
        end else if (entry_en[i]) begin
          rdata_q[i] <= rdata_d[i];
          err_q[i]   <= err_d[i];
        end
      end
    end else begin : g_rdata_nr
      always_ff @(posedge clk_i) begin
        if (entry_en[i]) begin
          rdata_q[i] <= rdata_d[i];
          err_q[i]   <= err_d[i];
        end
      end
    end
  end
endmodule