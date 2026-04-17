module poly_interpolator #(
  parameter  N           = 4,   // Interpolation factor
  parameter  TAPS        = 8,   // Taps per phase
  parameter  COEFF_WIDTH = 16,  // Coefficient bit width
  parameter  DATA_WIDTH  = 16,  // Input data bit width
  localparam ACC_WIDTH   = DATA_WIDTH + COEFF_WIDTH + $clog2(TAPS)
)
(
  input  logic                  clk,
  input  logic                  arst_n,
  input  logic [DATA_WIDTH-1:0] in_sample,
  input  logic                  in_valid,
  output logic                  in_ready,
  output logic [ACC_WIDTH-1:0]  out_sample,
  output logic                  out_valid
);
  logic [ACC_WIDTH-1:0]   result_buffer [0:N-1];
  logic [$clog2(N+1)-1:0] output_index;
  logic [ACC_WIDTH-1:0]   filter_result;
  logic [DATA_WIDTH-1:0]  shift_data [0:TAPS-1];
  logic                   shift_data_val;
  logic                   valid_filter;

  typedef enum logic [1:0] {
    WAIT_INPUT,
    PROCESS_PHASES,
    OUTPUT_STATE
  } state_t;
  state_t state, next_state;

  // Phase counter
  logic [$clog2(N)-1:0] phase_counter;
  // Signal to drive poly_filter's valid input.
  logic filter_val_in;
  
  // --- Instantiate Shift Register ---
  shift_register #(
    .TAPS       (TAPS),
    .DATA_WIDTH (DATA_WIDTH)
  ) u_shift_reg (
    .clk         (clk),
    .arst_n      (arst_n),
    .load        (in_valid & in_ready),
    .new_sample  (in_sample),
    .data_out    (shift_data),
    .data_out_val(shift_data_val)
  );

  // --- FSM for Polyphase Control ---
  always_ff @(posedge clk or negedge arst_n)
  begin
    if (!arst_n)
    begin
      state         <= WAIT_INPUT;
      phase_counter <= '0;
      filter_val_in <= 1'b0;
      output_index  <= 0;
      in_ready      <= 1'b1;
    end
    else
    begin
      state <= next_state;
      case (state)
        WAIT_INPUT:
        begin
          if (in_valid & in_ready)
          begin
            phase_counter <= '0;
            output_index  <= 0;
          end
        end
        PROCESS_PHASES:
        begin
          in_ready <= 1'b0;
          if (valid_filter)
          begin
            result_buffer[phase_counter] <= filter_result;
            if (phase_counter == N-1)
            begin
              filter_val_in <= 1'b0;
            end
            else
            begin
              phase_counter <= phase_counter + 1;
              filter_val_in <= 1'b1;
            end
          end
          else
          begin
            filter_val_in <= shift_data_val;
          end
        end
        OUTPUT_STATE:
        begin
            output_index <= output_index + 1;
            if (output_index == N)
              in_ready <= 1'b1;
        end
        default: filter_val_in <= 1'b0;
      endcase
    end
  end

  // --- Next State Logic ---
  always_comb
  begin
    case (state)
      WAIT_INPUT:
      begin
        if (in_valid)
          next_state = PROCESS_PHASES;
        else
          next_state = WAIT_INPUT;
      end
      PROCESS_PHASES:
      begin
        if (valid_filter && (phase_counter == N-1))
          next_state = OUTPUT_STATE;
        else
          next_state = PROCESS_PHASES;
      end
      OUTPUT_STATE :
      begin
        if (output_index == N)
          next_state = WAIT_INPUT;
        else
          next_state = OUTPUT_STATE;
      end
      default: next_state = WAIT_INPUT;
    endcase
  end

  // --- Instantiate Polyphase Filter ---

  poly_filter #(
    .N           (N),
    .TAPS        (TAPS),
    .COEFF_WIDTH (COEFF_WIDTH),
    .DATA_WIDTH  (DATA_WIDTH)
  ) u_poly_filter (
    .clk           (clk),
    .arst_n        (arst_n),
    .sample_buffer (shift_data),
    .valid_in      (filter_val_in),
    .phase         (phase_counter),
    .filter_out    (filter_result),
    .valid         (valid_filter)
  );

  // --- Output Assignment ---
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n)
    begin
      out_sample <= '0;
      out_valid  <= 1'b0;
    end
    else
    begin
      if (state == OUTPUT_STATE && output_index < N)
      begin
        out_sample <= result_buffer[output_index];
        out_valid  <= 1'b1;
      end
      else
      begin
        out_valid  <= 1'b0;
      end
    end
  end

endmodule