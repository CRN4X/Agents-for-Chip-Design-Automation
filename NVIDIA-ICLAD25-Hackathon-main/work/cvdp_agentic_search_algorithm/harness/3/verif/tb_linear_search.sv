module tb_linear_search ();

  // ---------------------------------------------------
  // Parameters
  // ---------------------------------------------------
  parameter DATA_WIDTH  = 8;
  parameter ADDR_WIDTH  = 4;
  parameter MEM_DEPTH   = 1 << ADDR_WIDTH;
  parameter MAX_MATCHES = MEM_DEPTH/2;

  // ---------------------------------------------------
  // DUT I/O Signals
  // ---------------------------------------------------
  logic                                clk = 0;
  logic                                srst;
  logic                                start; 
  logic                                pause;
  logic [   DATA_WIDTH-1:0]            key;
  logic                                mem_write_en;
  logic [   ADDR_WIDTH-1:0]            mem_write_addr;
  logic [   DATA_WIDTH-1:0]            mem_write_data;
  logic                                done;
  logic [   $clog2(MAX_MATCHES+1)-1:0] match_count;
  logic [(MAX_MATCHES*ADDR_WIDTH)-1:0] match_indices ;
  logic                                match_overflow;

  // ---------------------------------------------------
  // Input Registers (Registered interface)
  // ---------------------------------------------------
  logic                             start_reg; 
  logic                             pause_reg;
  logic [DATA_WIDTH-1:0]            key_reg;
  logic                             mem_write_en_reg;
  logic [ADDR_WIDTH-1:0]            mem_write_addr_reg;
  logic [DATA_WIDTH-1:0]            mem_write_data_reg;
  int                               num_matches;

  // Registering Inputs to DUT
  always_ff @(posedge clk or posedge srst)
    if (srst)
      begin
        start_reg          <= '0;
        pause_reg          <= '0;
        key_reg            <= '0;
        mem_write_en_reg   <= '0;
        mem_write_addr_reg <= '0;
        mem_write_data_reg <= '0;
      end
    else
      begin
        start_reg          <= start;
        pause_reg          <= pause;
        key_reg            <= key;
        mem_write_en_reg   <= mem_write_en;
        mem_write_addr_reg <= mem_write_addr;
        mem_write_data_reg <= mem_write_data;
      end

  // ---------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------
  linear_search_top #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .MEM_DEPTH  (MEM_DEPTH),
    .MAX_MATCHES(MAX_MATCHES)
  ) linear_search_top_inst (
    .clk            (clk),
    .srst           (srst),
    .start          (start_reg),
    .pause          (pause_reg),
    .key            (key_reg),
    .mem_write_en   (mem_write_en_reg),
    .mem_write_addr (mem_write_addr_reg),
    .mem_write_data (mem_write_data_reg),
    .done           (done),
    .match_count    (match_count),
    .match_indices  (match_indices),
    .match_overflow (match_overflow)
  );

  // ---------------------------------------------------
  // Clock Generation
  // ---------------------------------------------------
  always #5 clk = ~clk;

  // ---------------------------------------------------
  // Reset Task
  // ---------------------------------------------------
  task apply_reset();
    $display("\nApplying Reset");
    srst = 1;
    start = '0;
    pause = '0;
    key = '0;
    mem_write_en = '0;
    mem_write_addr = '0;
    mem_write_data = '0;
    repeat(10) @(posedge clk);
    srst = 0;
    repeat(10) @(posedge clk);
    $display("Reset Completed");
  endtask

  // ---------------------------------------------------
  // Memory Initialization Task
  // ---------------------------------------------------
  task automatic write_memory(input int match_spacing);
    int count = 0;
    mem_write_en = 1;
    $display("INFO! Writing to memory with spacing = %0d", match_spacing);
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_addr = i;
      if (i % match_spacing == 0 && count < MAX_MATCHES) begin
        mem_write_data = key;
        count++;
      end else begin
        mem_write_data = i;
      end
    end
    #10;
    mem_write_en = 0;
    $display("INFO! Memory Write Completed\n");
  endtask

  // ---------------------------------------------------
  // Search Start Task (with optional pause)
  // ---------------------------------------------------
  task automatic start_search_with_pause(input bit do_pause);
    #10; start = 1;
    #10; start = 0;
    #10;
    if (do_pause) begin
      for (int i = 0; i < 3; i++) @(negedge clk);
      pause = 1;
      #10; #10;
      pause = 0;
    end
    wait(done);
  endtask

  // ---------------------------------------------------
  // Test Sequence (Pre-filled Tests 1-11)
  // ---------------------------------------------------
  initial begin
    srst = 0;
    #20;
    apply_reset();
    $display("Applying Stimulus . . .",);

    // Test 1: Normal match pattern
    $display("\n========== TEST 1: Normal match pattern ==========");
    key = 8'hAA;
    write_memory(4);  // Match at 0, 4, 8, 12
    start_search_with_pause(0);

    // Test 2: 1 match
    $display("\n========== TEST 2: 1 match ==========");
    key = 8'hFF;
    write_memory(99);  // No matches
    start_search_with_pause(0);

    // Test 3: All matches without pause and with overflow 
    $display("\n========== TEST 3: All matches without pause and with overflow ==========");
    key = 8'hBB;
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      mem_write_data = key;
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause(0);

    // Test 4: All matches with pause and with overflow 
    $display("\n========== TEST 4: All matches with pause and with overflow ==========");
    key = 8'hDD;
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      mem_write_data = key;
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause(1);

    // Test 5: Just enough to reach MAX MATCHES
    $display("\n========== TEST 5: MAX MATCHES TEST ==========");
    key = 8'hCC;
    write_memory(1);  // Insert key at every location
    start_search_with_pause(0);

    // Test 6: Match only at the last address
    $display("\n========== TEST 6: Match only at LAST address ==========");
    key = 8'hAB;
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      if (i == MEM_DEPTH - 1) begin
        mem_write_data = key;
      end else begin
        mem_write_data = i;
      end
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause(0);

    // Test 7: Match only at the first address
    $display("\n========== TEST 7: Match only at FIRST address ==========");
    key = 8'hAD;
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      if (i == 0) begin
        mem_write_data = key;
      end else begin
        mem_write_data = i;
      end
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause(0);

    // Test 8: Match only at middle address
    $display("\n========== TEST 8: Match only at MIDDLE address ==========");
    key = 8'hAF;
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      if (i == MEM_DEPTH / 2) begin
        mem_write_data = key;
      end else begin
        mem_write_data = i;
      end
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause(0);

    // Test 9: Buffer exactly full (no overflow)
    $display("\n========== TEST 9: Match BUFFER FULL (no overflow) ==========");
    key = 8'hDE;
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MAX_MATCHES; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      mem_write_data = key;
    end
    for (int i = MAX_MATCHES; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_addr = i;
      mem_write_data = i;
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause(0);

    // Test 10: Back-to-back searches with different keys
    $display("\n========== TEST 10: BACK-TO-BACK searches ==========");
    key = 8'h11;
    write_memory(3);
    $display("Expecting matches every 3 addresses for key 0x11");
    start_search_with_pause(0);

    key = 8'h22;
    write_memory(5);
    $display("Expecting matches every 5 addresses for key 0x22");
    start_search_with_pause(0);

    // Test 11: Randomized memory and key
    $display("\n========== TEST 11: RANDOMIZED memory + key ==========");
    key = $urandom_range(0, 255);
    $display("Random key = 0x%0h", key);
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      mem_write_data = $urandom_range(0, 255);
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause($urandom % 2);

    // Test 12: Random matches location
    $display("\n========== TEST 12: RANDOMIZED memory addr ==========");
    for (int i = 0; i < 10000; i++) begin
      key = $urandom_range(0, 255);
      num_matches = $urandom_range(0,MAX_MATCHES-1);
      for (int j = 0; j < num_matches; j++) begin
        #10;
        mem_write_en = 1;
        mem_write_addr = $urandom_range(0, MEM_DEPTH-1);
        mem_write_data = key;
      end
      #10; mem_write_en = 0;
      start_search_with_pause($urandom % 2);
    end

    key = 8'hBB;
    $display("INFO! Writing to memory\n");
    for (int i = 0; i < MEM_DEPTH; i++) begin
      #10;
      mem_write_en = 1;
      mem_write_addr = i;
      mem_write_data = key;
    end
    $display("INFO! Memory Write Completed\n");
    #10; mem_write_en = 0;
    start_search_with_pause(0);

    $display("Stimulus has been Applied!");
    $finish;
  end

endmodule