module linear_search_ctrl (
  input  logic clk        ,  // Clock
  input  logic srst       ,  // Active High Synchronous reset
  input  logic start      ,  // Start signal to begin search
  input  logic pause      ,  // Pause signal to temporarily halt search
  input  logic search_done,  // Indicates the datapath has completed the search
  output logic enable     ,  // Enables datapath to perform search
  output logic done          // High when search is completed
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE,     // Waiting for start signal
    SEARCH,   // Actively searching
    DONE,     // Search completed
    PAUSED    // Search paused
  } fsm_state_t;

  fsm_state_t state, next_state;

  // State transition on clock or synchronous reset
  always_ff @(posedge clk or posedge srst) begin
    if (srst)
      state <= IDLE;        // Reset to IDLE
    else
      state <= next_state;  // Move to computed next state
  end

  // Next-state logic and output control
  always_comb begin
    // Default values
    next_state = state;
    enable     = 0;
    done       = 0;

    case (state)
      IDLE : begin
        if (start)
          next_state = SEARCH;  // Start search when start is asserted
      end

      SEARCH : begin
        enable = 1;             // Activate datapath
        if (pause)
          next_state = PAUSED;  // Pause requested
        else if (search_done)
          next_state = DONE;    // Done when datapath completes
      end

      PAUSED : begin
        if (!pause)
          next_state = SEARCH;  // Resume search when pause is deasserted
      end

      DONE : begin
        done = 1;               // Indicate completion
        next_state = IDLE;    // Go back to IDLE once start is deasserted
      end
    endcase
  end

endmodule
