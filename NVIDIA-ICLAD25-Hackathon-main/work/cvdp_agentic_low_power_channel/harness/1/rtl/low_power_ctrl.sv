module low_power_ctrl (
  // Clock/Reset
  input  logic        clk,
  input  logic        reset,

  // Wakeup input
  input  logic        if_wakeup_i,

  // FIFO statuses
  input  logic        wr_fifo_full,
  input  logic        wr_fifo_empty,

  // Write/Read requests
  input  logic        wr_valid_i,
  input  logic        rd_valid_i,

  // Upstream flush interface
  input  logic        wr_done_i,
  output logic        wr_flush_o,

  // Q-channel interface
  input  logic        qreqn_i,
  output logic        qacceptn_o,
  output logic        qactive_o,

  // FIFO push/pop controls
  output logic        wr_fifo_push,
  output logic        wr_fifo_pop
);

  // --------------------------------------------------------
  // Internal signals
  // --------------------------------------------------------
  typedef enum logic [1:0] {
    ST_Q_RUN      = 2'b00,
    ST_Q_REQUEST  = 2'b01,
    ST_Q_STOPPED  = 2'b10,
    ST_Q_EXIT     = 2'b11
  } state_t;

  state_t state_q, nxt_state;

  logic   nxt_qactive;
  logic   qactive_q;

  logic   nxt_qaccept;
  logic   nxt_qacceptn;
  logic   qacceptn_en;
  logic   qacceptn_q;

  // --------------------------------------------------------
  // Gate writes/reads based on FIFO full/empty
  // --------------------------------------------------------
  // The same lines from your original code, but now in the control module:
  assign wr_fifo_push = wr_valid_i & ~wr_fifo_full;
  assign wr_fifo_pop  = rd_valid_i & ~wr_fifo_empty;

  // --------------------------------------------------------
  // QACTIVE signal (same logic as original)
  // --------------------------------------------------------
  // Next-cycle active if the FIFO has data, or a new valid read/write
  assign nxt_qactive = (~wr_fifo_empty) | wr_valid_i | rd_valid_i;

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      qactive_q <= 1'b0;
    else
      qactive_q <= nxt_qactive;
  end

  assign qactive_o = qactive_q | if_wakeup_i;

  // --------------------------------------------------------
  // State Machine
  // --------------------------------------------------------
  always_comb begin
    nxt_state = state_q;
    case (state_q)
      ST_Q_RUN:
        if (~qreqn_i)
          nxt_state = ST_Q_REQUEST;

      ST_Q_REQUEST:
        // The design goes to ST_Q_STOPPED once we accept => qacceptn=0
        if (~qacceptn_q)
          nxt_state = ST_Q_STOPPED;

      ST_Q_STOPPED:
        // The design goes to ST_Q_EXIT once qreqn_i=1 again
        if (qreqn_i)
          nxt_state = ST_Q_EXIT;

      ST_Q_EXIT:
        // Return to ST_Q_RUN when qacceptn=1
        if (qacceptn_q)
          nxt_state = ST_Q_RUN;
    endcase
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      state_q <= ST_Q_RUN;
    else
      state_q <= nxt_state;
  end

  // --------------------------------------------------------
  // Flush Control (combinational)
  // --------------------------------------------------------
  // The original requirement: wr_flush_o=1 in ST_Q_REQUEST if wr_done_i=0,
  // then remain high until wr_done_i=1.
  assign wr_flush_o = (state_q == ST_Q_REQUEST) & (~wr_done_i);

  // --------------------------------------------------------
  // QACCEPTn logic
  // --------------------------------------------------------
  // Accept once FIFO is empty + wr_done_i=1 + qreqn_i=0 => qaccept=1 => qacceptn=0
  // Then remain in ST_Q_STOPPED until qreqn_i reasserts => ST_Q_EXIT => eventually qacceptn=1 => ST_Q_RUN
  assign nxt_qaccept  = (wr_done_i & wr_fifo_empty & ~qreqn_i);
  assign nxt_qacceptn = ~nxt_qaccept;

  // Enable capturing qacceptn in ST_Q_REQUEST or ST_Q_EXIT
  assign qacceptn_en = (state_q == ST_Q_REQUEST) | (state_q == ST_Q_EXIT);

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      qacceptn_q <= 1'b1;
    else if (qacceptn_en)
      qacceptn_q <= nxt_qacceptn;
  end

  assign qacceptn_o = qacceptn_q;

endmodule