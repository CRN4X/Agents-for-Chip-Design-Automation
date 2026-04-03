module clock_estimator (
    input  logic         clk_sys,        // Reference clock
    input  logic         clk_test,       // Clock to be estimated
    input  logic         rst_n,          // Active low reset signal
    input  logic         enable,         // Enable pulse
    input  logic [31:0]  count_ref,      // Static count reference value
    output logic [31:0]  o_clock_est,    // Number of edges counted
    output logic         o_irq           // Interrupt signal
);

    // Counters and control signals
    logic [31:0] ref_counter;   // Counter for reference clock cycles
    logic [31:0] edge_counter;  // Counter for detected test clock edges
    logic        counting;      // Indicates counting operation is in progress
    // Removed unused signal "clk_in_prev"
    logic [2:0]  clk_test_cdc;   // Clock domain crossing synchronizer register
    logic        tst_posedge;    // Detected rising edge after synchronization

    // Synchronize test clock into the reference clock domain
    always_ff @(posedge clk_sys or negedge rst_n) begin
      if (!rst_n)
        clk_test_cdc <= 3'b0;  // Use a 3-bit zero value
      else
        clk_test_cdc <= { clk_test_cdc[1:0], clk_test };
    end

    // Start counting when enable is asserted and stop when ref_counter reaches count_ref - 1
    always_ff @(posedge clk_sys or negedge rst_n) begin
      if (!rst_n)
        counting <= 1'b0;
      else if (enable && !counting)
        counting <= 1'b1;
      else if (ref_counter >= (count_ref - 1))
        counting <= 1'b0;
    end

    // Generate a pulse when a rising edge is detected in the synchronized test clock
    always_ff @(posedge clk_sys or negedge rst_n) begin
      if (!rst_n)
        tst_posedge <= 1'b0;
      else
        tst_posedge <= (clk_test_cdc[2:1] == 2'b01);
    end

    // Reference counter: count clock cycles while counting is active
    always_ff @(posedge clk_sys or negedge rst_n) begin
      if (!rst_n)
        ref_counter <= 32'b0;
      else if (counting)
        ref_counter <= ref_counter + 1;
      else
        ref_counter <= 32'b0;    
    end

    // Edge counter: count rising edges detected on the test clock
    always_ff @(posedge clk_sys or negedge rst_n) begin
      if (!rst_n)
        edge_counter <= 32'b0;
      else if (counting && tst_posedge)
        edge_counter <= edge_counter + 1;
      else if (!counting)
        edge_counter <= 32'b0;
    end

    // Output logic: when counting completes, latch the edge count and raise the interrupt.
    always_ff @(posedge clk_sys or negedge rst_n) begin
      if (!rst_n) begin      
        o_clock_est <= 32'b0;
        o_irq       <= 1'b0;
      end
      else if (enable && !counting) begin
        // When not counting, ensure outputs are reset.
        o_clock_est <= 32'b0;
        o_irq       <= 1'b0;
      end
      else if (counting && (ref_counter >= count_ref - 1)) begin
        // Counting complete: latch the edge counter value and assert interrupt.
        o_clock_est <= edge_counter;
        o_irq       <= 1'b1;
      end
      else begin
        // Default case: deassert interrupt.
        o_irq       <= 1'b0;
      end
    end

endmodule