module monte_carlo_dsp_monitor_top_tb;

  parameter DATA_WIDTH = 16;
  parameter CLK_A_PERIOD = 7;
  parameter CLK_B_PERIOD = 13;
  parameter EXPECTED_MIN_OUTPUTS = 100;

  logic clk_a, clk_b, rst_n;
  logic [DATA_WIDTH-1:0] data_in_a;
  logic valid_in_a;
  wire [DATA_WIDTH-1:0] data_out_b;
  wire valid_out_b;
  wire [31:0] cross_domain_transfer_count;

  bit passed_static  = 0;
  bit passed_random  = 0;
  bit passed_toggle  = 0;
  bit any_fail       = 0;

  monte_carlo_dsp_monitor_top #(.DATA_WIDTH(DATA_WIDTH)) dut (
    .clk_a(clk_a),
    .clk_b(clk_b),
    .rst_n(rst_n),
    .data_in_a(data_in_a),
    .valid_in_a(valid_in_a),
    .data_out_b(data_out_b),
    .valid_out_b(valid_out_b),
    .cross_domain_transfer_count(cross_domain_transfer_count)
  );

  initial clk_a = 0;
  always #(CLK_A_PERIOD / 2) clk_a = ~clk_a;

  initial clk_b = 0;
  always #(CLK_B_PERIOD / 2) clk_b = ~clk_b;

  int actual_output_count = 0;
  always @(posedge clk_b) begin
    if (rst_n && valid_out_b)
      actual_output_count++;
  end

  initial begin
    $display("=== Extended Monte Carlo DSP Monitor TB ===");

    rst_n = 0;
    data_in_a = 0;
    valid_in_a = 0;
    repeat (5) @(posedge clk_a);
    rst_n = 1;
    repeat (5) @(posedge clk_a);

    // === Static patterns ===
    send(16'h0000, "All Zeros");
    send(16'hFFFF, "All Ones");
    send(16'hAAAA, "Alternating 1010");
    send(16'h5555, "Alternating 0101");
    passed_static = 1;

    // === One-hot & inverse one-hot ===
    for (int i = 0; i < DATA_WIDTH; i++) send(1 << i, $sformatf("One-hot %0d", i));
    for (int i = 0; i < DATA_WIDTH; i++) send(~(1 << i), $sformatf("Inverse one-hot %0d", i));

    // === Numeric edge patterns ===
    send(16'h0001, "Min +1");
    send(16'h7FFF, "Mid max");
    send(16'h8000, "MSB only");
    send(16'hFFFE, "All but LSB");
    send(16'h00FF, "Low byte");
    send(16'hFF00, "High byte");

    // === Sequential counter ===
    for (int i = 0; i < 10; i++) send(i, $sformatf("Counter %0d", i));

    // === Wraparound ===
    for (int i = 65530; i < 65536; i++) send(i[15:0], $sformatf("Wraparound %0d", i));

    // === Random burst ===
    repeat (40) begin
      @(posedge clk_a);
      data_in_a = $urandom();
      valid_in_a = 1;
      $display("[RANDOM BURST] Data=0x%04X at %0t", data_in_a, $time);
      @(posedge clk_a);
      valid_in_a = 0;
    end

    // === Random w/ gaps ===
    for (int i = 0; i < 20; i++) begin
      repeat ($urandom_range(1, 4)) @(posedge clk_a);
      data_in_a = $urandom();
      valid_in_a = 1;
      $display("[GAPPED RANDOM] Data=0x%04X at %0t", data_in_a, $time);
      @(posedge clk_a);
      valid_in_a = 0;
    end
    passed_random = 1;

    // === Delayed valid toggle ===
    for (int i = 0; i < 10; i++) begin
      @(posedge clk_a);
      data_in_a = $urandom();
      valid_in_a = 0;
      @(posedge clk_a);
      valid_in_a = 1;
      @(posedge clk_a);
      valid_in_a = 0;
    end

    // === Toggle valid ===
    for (int i = 0; i < 20; i++) begin
      @(posedge clk_a);
      data_in_a = $urandom();
      valid_in_a = (i % 2 == 0);
      $display("[TOGGLE VALID] Valid=%0d Data=0x%04X", valid_in_a, data_in_a);
    end
    passed_toggle = 1;

    // === Repeated pattern ===
    for (int i = 0; i < 10; i++) send(16'h1234, "Repeated 0x1234");

    // === Noise injection ===
    for (int i = 0; i < 10; i++) begin
      @(posedge clk_a);
      data_in_a = $urandom() ^ 16'h00F0;
      valid_in_a = 1;
      $display("[NOISE MASKED] Data=0x%04X", data_in_a);
      @(posedge clk_a);
      valid_in_a = 0;
    end

    // === Slow ramp-up ===
    for (int i = 0; i < 5; i++) begin
      repeat (i + 1) @(posedge clk_a);
      data_in_a = i * 1000;
      valid_in_a = 1;
      $display("[RAMP-UP] Step %0d Data=0x%04X", i, data_in_a);
      @(posedge clk_a);
      valid_in_a = 0;
    end

    // === Completion ===
    valid_in_a = 0;
    data_in_a = 0;
    repeat (200) @(posedge clk_b);

    $display("\nActual valid outputs       : %0d", actual_output_count);
    $display("DUT cross-domain transfers : %0d", cross_domain_transfer_count);

    // === Summary Table ===
    $display("\n=== TEST SUMMARY TABLE ===");
    $display("| %-25s | %-6s |", "Test Section", "Status");
    $display("|---------------------------|--------|");

    if (!passed_static) begin
      $error("| %-25s | %-6s |", "Static Patterns", "FAIL"); any_fail = 1;
    end else $display("| %-25s | %-6s |", "Static Patterns", "PASS");

    if (!passed_random) begin
      $error("| %-25s | %-6s |", "Random Sequences", "FAIL"); any_fail = 1;
    end else $display("| %-25s | %-6s |", "Random Sequences", "PASS");

    if (!passed_toggle) begin
      $error("| %-25s | %-6s |", "Toggle Valid", "FAIL"); any_fail = 1;
    end else $display("| %-25s | %-6s |", "Toggle Valid", "PASS");

    if (actual_output_count != cross_domain_transfer_count) begin
      $error("| %-25s | %-6s |", "Output Count Match", "FAIL");
      $error("Mismatch: Output count (%0d) != DUT counter (%0d)",
        actual_output_count, cross_domain_transfer_count);
      any_fail = 1;
    end else $display("| %-25s | %-6s |", "Output Count Match", "PASS");

    if (actual_output_count < EXPECTED_MIN_OUTPUTS) begin
      $error("| %-25s | %-6s |", "Minimum Output Check", "FAIL");
      $error("Too few outputs: Got %0d, expected at least %0d",
        actual_output_count, EXPECTED_MIN_OUTPUTS);
      any_fail = 1;
    end else $display("| %-25s | %-6s |", "Minimum Output Check", "PASS");

    if (!any_fail)
      $display("TEST CASE PASSED: Captured %0d valid outputs.", actual_output_count);

    $finish;
  end

  task send(input [DATA_WIDTH-1:0] val, input string label);
    @(posedge clk_a);
    data_in_a = val;
    valid_in_a = 1;
    $display("[STIM] %-20s | Data=0x%04X at %0t", label, val, $time);
    @(posedge clk_a);
    valid_in_a = 0;
  endtask

endmodule