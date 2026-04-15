`timescale 1ns / 1ps

module tb_low_power_channel;

  // -------------------------------------------------------------------
  // DUT Interface Signals
  // -------------------------------------------------------------------
  logic         clk;
  logic         reset;

  // DUT inputs
  logic         if_wakeup_i;
  logic         wr_valid_i;
  logic [7:0]   wr_payload_i;
  logic         wr_done_i;
  logic         rd_valid_i;
  logic         qreqn_i;

  // DUT outputs
  wire          wr_flush_o;
  wire [7:0]    rd_payload_o;
  wire          qacceptn_o;
  wire          qactive_o;

  // -------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------
  low_power_channel dut (
    .clk          (clk),
    .reset        (reset),
    .if_wakeup_i  (if_wakeup_i),
    .wr_valid_i   (wr_valid_i),
    .wr_payload_i (wr_payload_i),
    .wr_flush_o   (wr_flush_o),
    .wr_done_i    (wr_done_i),
    .rd_valid_i   (rd_valid_i),
    .rd_payload_o (rd_payload_o),
    .qreqn_i      (qreqn_i),
    .qacceptn_o   (qacceptn_o),
    .qactive_o    (qactive_o)
  );

  // -------------------------------------------------------------------
  // Clock Generation
  // -------------------------------------------------------------------
  always #5 clk = ~clk;

  // -------------------------------------------------------------------
  // Scoreboard / Tracking
  // -------------------------------------------------------------------
  // We will store written data in a queue and compare with read data
  // to ensure correctness.
  typedef bit [7:0] data_t;
  data_t write_queue[$];
  data_t read_data;

  // Track errors
  integer error_count = 0;

  // Simple mechanism to log errors
  task report_error(string msg);
    begin
      error_count++;
      $display("[ERROR] %s at time %0t", msg, $time);
    end
  endtask

  // -------------------------------------------------------------------
  // Initialization & Reset
  // -------------------------------------------------------------------
  initial begin
    clk          = 0;
    reset        = 0;
    if_wakeup_i  = 0;
    wr_valid_i   = 0;
    wr_payload_i = 0;
    wr_done_i    = 0;
    rd_valid_i   = 0;
    qreqn_i      = 1; // Start in ST_Q_RUN

    // Apply reset
    apply_reset;
    // Run test scenarios
    scenario1_reset_behavior;
    scenario2_write_read;
    scenario3_fifo_overflow_attempt;
    scenario4_fifo_underflow_attempt;
    scenario5_qreq_flush_handshake;
    scenario6_wakeup_signal_test;

    // Optional random/stress test
    scenario7_random_stress;

    // Final summary
    if (error_count == 0) begin
      $display("\nAll tests PASSED!");
    end else begin
      $display("\nTest FAILED with %0d errors!", error_count);
    end

    $finish;
  end

  // -------------------------------------------------------------------
  // Reset Task
  // -------------------------------------------------------------------
  task apply_reset;
    begin
      reset = 1;
      repeat (2) @(posedge clk); // hold reset for a couple of cycles
      reset = 0;
      repeat (2) @(posedge clk);
    end
  endtask

  // -------------------------------------------------------------------
  // Scenario #1: Reset Behavior
  //   Pass/Fail Criteria:
  //   - After reset, qacceptn_o == 1, qactive_o == 0, wr_flush_o == 0
  // -------------------------------------------------------------------
  task scenario1_reset_behavior;
    begin
      $display("\n--- SCENARIO 1: Reset Behavior ---");
      // Right after apply_reset, check signals
      @(negedge clk);
      if (qacceptn_o !== 1'b1)
        report_error("qacceptn_o should be 1 after reset");
      if (qactive_o !== 1'b0)
        report_error("qactive_o should be 0 after reset");
      if (wr_flush_o !== 1'b0)
        report_error("wr_flush_o should be 0 after reset");

      $display("Scenario 1 completed.");
    end
  endtask

  // -------------------------------------------------------------------
  // Scenario #2: Simple Write/Read
  //   Pass/Fail Criteria:
  //   - Data read = Data written (in order).
  //   - No unexpected assertions of wr_flush_o.
  // -------------------------------------------------------------------
  task scenario2_write_read;
    begin
      $display("\n--- SCENARIO 2: Simple Write/Read ---");
      // Write a few data items
      write_data(8'hAA);
      write_data(8'hBB);
      write_data(8'hCC);

      // Now read them back
      read_data_item; // expects 8'hAA
      read_data_item; // expects 8'hBB
      read_data_item; // expects 8'hCC

      // Check no extra flush was triggered
      if (wr_flush_o !== 1'b0)
        report_error("wr_flush_o should not have asserted in normal write/read scenario");

      $display("Scenario 2 completed.");
    end
  endtask

  // Write a data item into the DUT
  task write_data(input [7:0] data_in);
    begin
      @(posedge clk);
      wr_valid_i   = 1'b1;
      wr_payload_i = data_in;
      write_queue.push_back(data_in);
      @(posedge clk);
      wr_valid_i   = 1'b0;
      wr_payload_i = 8'h00; // idle
      @(posedge clk);
    end
  endtask

  // Read a data item from the DUT and check scoreboard
  task read_data_item;
    begin
      // Only attempt read if scoreboard says we have data
      if (write_queue.size() == 0) begin
        report_error("Read requested but scoreboard is empty");
        return;
      end

      // Drive read
      @(posedge clk);
      rd_valid_i = 1'b1;
      @(posedge clk);
      rd_valid_i = 1'b0;

      // The read data will appear combinationally at rd_payload_o
      // We'll sample at the next clock for stable checking
      read_data = rd_payload_o;
      // Compare with scoreboard front
      if (read_data !== write_queue[0]) begin
        report_error($sformatf("Read data mismatch. Expected %h, got %h",
                               write_queue[0], read_data));
      end
      // Pop from scoreboard
      write_queue.pop_front();
      @(posedge clk);
    end
  endtask

  // -------------------------------------------------------------------
  // Scenario #3: FIFO Overflow Attempt
  //   Pass/Fail Criteria:
  //   - Confirm design’s defined behavior. Possibly losing data or ignoring push
  //     if the FIFO is full. Make sure no unexpected lock-ups.
  // -------------------------------------------------------------------
  task scenario3_fifo_overflow_attempt;
    integer i;
    begin
      $display("\n--- SCENARIO 3: FIFO Overflow Attempt ---");
      // FIFO has DEPTH=6 in the DUT. Let's write more than 6 without reads.
      for (i = 0; i < 8; i++) begin
        write_data(i[7:0]);
      end

      // Now read all we can. The scoreboard expects 8 items, but the
      // actual FIFO can only hold 6. If the design does not gate wr_valid,
      // you might see data lost or overwritten.
      // We read 8 times to see what comes out.
      for (i = 0; i < 8; i++) begin
        read_data_item;
      end

      // If the design is not gating writes, you may see mismatch errors.
      // We only confirm it doesn't wedge or produce X states unexpectedly.
      $display("Scenario 3 completed. Check for mismatch errors or stable behavior.");
    end
  endtask

  // -------------------------------------------------------------------
  // Scenario #4: FIFO Underflow Attempt
  //   Pass/Fail Criteria:
  //   - Attempt reading from empty FIFO. Check that no corruption or
  //     unexpected transitions occur.
  // -------------------------------------------------------------------
  task scenario4_fifo_underflow_attempt;
    integer i;
    begin
      $display("\n--- SCENARIO 4: FIFO Underflow Attempt ---");
      // Ensure FIFO is empty: no writes
      // Attempt multiple reads
      for (i = 0; i < 3; i++) begin
        @(posedge clk);
        rd_valid_i = 1'b1;
        @(posedge clk);
        rd_valid_i = 1'b0;
        // Check read data (may remain at a previous or undefined value)
        $display("Read data = %h (expected empty FIFO)", rd_payload_o);
      end

      // As long as the design does not hang or produce spurious flush,
      // we consider this scenario pass if no errors have been reported.
      $display("Scenario 4 completed.");
    end
  endtask

  // -------------------------------------------------------------------
  // Scenario #5: QREQ Handshake and Flush
  //   Pass/Fail Criteria:
  //   - wr_flush_o must assert when qreqn_i goes low (ST_Q_REQUEST)
  //     and remain asserted until wr_done_i is high and FIFO empties.
  //   - qacceptn_o must go low once flush completes in ST_Q_STOPPED.
  // -------------------------------------------------------------------
  task scenario5_qreq_flush_handshake;
    begin
      $display("\n--- SCENARIO 5: QREQ Handshake and Flush ---");
      // 1) Put some data in FIFO, do not read them
      write_data(8'hA0);
      write_data(8'hB1);

      // 2) Deassert wr_done_i, so the flush cannot complete
      wr_done_i = 0;

      // 3) Pull qreqn_i low => request Q-channel
      @(posedge clk);
      qreqn_i = 0;

      // Expect the state machine to move from ST_Q_RUN -> ST_Q_REQUEST
      // Check if wr_flush_o = 1
      // We'll wait a few cycles and check
      repeat (2) @(posedge clk);
      if (wr_flush_o !== 1'b1) begin
        report_error("wr_flush_o should be asserted in ST_Q_REQUEST");
      end

      // 4) Now let the upstream complete: wr_done_i=1 => flush completes
      //    Wait for FIFO to empty as well. Let's do a quick read:
      read_data_item; // read 8'hA0
      read_data_item; // read 8'hB1

      // The FIFO is now empty but we also must keep wr_done_i = 1
      @(posedge clk);
      wr_done_i = 1'b1;

      // Wait a bit to let state machine transition
      repeat (2) @(posedge clk);

      // Now, we expect wr_flush_o = 0 (since flush completed) and
      // qacceptn_o to drive low (since ST_Q_STOPPED).
      if (wr_flush_o !== 1'b0)
        report_error("wr_flush_o should be deasserted after flush completes");
      
      // Because we are in ST_Q_STOPPED, qacceptn_o should be 1'b0
      // (the design sets qacceptn_o = ~qaccept, so if we accept=1 => qacceptn=0)
      if (qacceptn_o !== 1'b0)
        report_error("qacceptn_o should be 0 in ST_Q_STOPPED");

      // 5) Re-assert qreqn_i => ST_Q_EXIT => eventually qacceptn_o = 1,
      @(posedge clk);
      qreqn_i = 1'b1;
      repeat (2) @(posedge clk);
      repeat(2) @(posedge clk);  // <---- ADD at least 2 cycles of wait
      if (qacceptn_o !== 1'b1)
        report_error("qacceptn_o should go back to 1 in ST_Q_RUN eventually");

      // Return signals to idle
      wr_done_i = 0;
      $display("Scenario 5 completed.");
    end
  endtask

  // -------------------------------------------------------------------
  // Scenario #6: Wakeup Signal Check
  //   Pass/Fail Criteria:
  //   - If if_wakeup_i=1 with an empty FIFO, qactive_o should still assert.
  //   - When if_wakeup_i=0, qactive_o should deassert if no FIFO activity.
  // -------------------------------------------------------------------
  task scenario6_wakeup_signal_test;
    begin
      $display("\n--- SCENARIO 6: Wakeup Signal Check ---");
      // Ensure FIFO is empty from previous scenario
      // No writes or reads
      if_wakeup_i = 1'b1;
      @(posedge clk);
      if (qactive_o !== 1'b1)
        report_error("qactive_o should be high due to wakeup");

      // Now deassert wakeup
      if_wakeup_i = 1'b0;
      repeat (2) @(posedge clk);
      if (qactive_o !== 1'b0)
        report_error("qactive_o should return low when wakeup is cleared and FIFO idle");

      $display("Scenario 6 completed.");
    end
  endtask

  // -------------------------------------------------------------------
  // Scenario #7: Optional Random/Stress (example skeleton)
  //   Pass/Fail Criteria:
  //   - No data mismatches or illegal state machine transitions.
  //   - Potential to uncover corner cases more systematically.
  // -------------------------------------------------------------------
  
  task scenario7_random_stress;
    integer i;
    begin
      $display("\n--- SCENARIO 7: Random/Stress Test ---");
      for (i = 0; i < 100; i++) begin
        // Random writes
        wr_valid_i   = $urandom_range(0,1);
        wr_payload_i = $urandom_range(0,255);
        if (wr_valid_i) write_queue.push_back(wr_payload_i);

        // Random reads
        rd_valid_i   = $urandom_range(0,1);
        if (rd_valid_i && write_queue.size() > 0) begin
          // scoreboard check after the cycle
        end

        // Random QREQ toggles
        if ($urandom_range(0,50) == 0) qreqn_i = ~qreqn_i;

        // Random wakeup
        if_wakeup_i = $urandom_range(0,1);

        // Random wr_done_i
        wr_done_i  = $urandom_range(0,1);

        @(posedge clk);
      end

      // Turn off writes, reads, wait some cycles
      wr_valid_i   = 0;
      rd_valid_i   = 0;
      if_wakeup_i  = 0;
      wr_done_i    = 1;
      repeat (10) @(posedge clk);

      $display("Scenario 7 completed (Random/Stress).");
    end
  endtask
  

endmodule