`timescale 1ns/1ps
module coffee_machine_testbench;

  //-------------------------------------------------------------------------
  // Parameter definitions (should match the DUT)
  //-------------------------------------------------------------------------
  parameter NBW_DLY   = 5;
  parameter NBW_BEANS = 2;
  parameter NS_BEANS  = 4;
  parameter NS_OP     = 3;
  parameter NS_SENSOR = 4;

  //-------------------------------------------------------------------------
  // DUT I/O declarations
  //-------------------------------------------------------------------------
  logic                   clk;
  logic                   rst_async_n;
  logic [NBW_DLY-1:0]     i_grind_delay;
  logic [NBW_DLY-1:0]     i_heat_delay;
  logic [NBW_DLY-1:0]     i_pour_delay;
  logic [NBW_BEANS-1:0]   i_bean_sel;
  logic [NS_OP-1:0]       i_operation_sel;
  logic                   i_start;
  logic [NS_SENSOR-1:0]   i_sensor;

  logic [NS_BEANS-1:0]    o_bean_sel;
  logic                   o_grind_beans;
  logic                   o_use_powder;
  logic                   o_heat_water;
  logic                   o_pour_coffee;
  logic                   o_error;

  //-------------------------------------------------------------------------
  // Instantiate the DUT
  //-------------------------------------------------------------------------
  coffee_machine #(
    .NBW_DLY   (NBW_DLY),
    .NBW_BEANS (NBW_BEANS),
    .NS_BEANS  (NS_BEANS),
    .NS_OP     (NS_OP),
    .NS_SENSOR (NS_SENSOR)
  ) dut (
    .clk            (clk),
    .rst_async_n    (rst_async_n),
    .i_grind_delay  (i_grind_delay),
    .i_heat_delay   (i_heat_delay),
    .i_pour_delay   (i_pour_delay),
    .i_bean_sel     (i_bean_sel),
    .i_operation_sel(i_operation_sel),
    .i_start        (i_start),
    .i_sensor       (i_sensor),
    .o_bean_sel     (o_bean_sel),
    .o_grind_beans  (o_grind_beans),
    .o_use_powder   (o_use_powder),
    .o_heat_water   (o_heat_water),
    .o_pour_coffee  (o_pour_coffee),
    .o_error        (o_error)
  );

  //-------------------------------------------------------------------------
  // Clock Generation
  //-------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10ns period
  end

  //-------------------------------------------------------------------------
  // Reset Generation (asynchronous active low)
  //-------------------------------------------------------------------------
  initial begin
    rst_async_n = 1;
    #20;
    rst_async_n = 0;
    #20;
    rst_async_n = 1;
  end

  //-------------------------------------------------------------------------
  // Task: wait_operation_complete
  // Waits until the operation is complete (all control outputs return to 0)
  //-------------------------------------------------------------------------
  task wait_operation_complete();
  begin
    wait( (o_grind_beans == 1'b0) && (o_use_powder == 1'b0) &&
          (o_heat_water  == 1'b0) && (o_pour_coffee == 1'b0)  &&
          (|o_bean_sel == 1'b0));
    @(posedge clk);
  end
  endtask

   initial begin
      $dumpfile("test.vcd");
      $dumpvars(0, dut);
   end

  //-------------------------------------------------------------------------
  // Unified Task: execute_operation
  // This task applies the test stimulus and can optionally inject an interrupt.
  // Parameters:
  //   test_name       : A string to identify the test case.
  //   op_sel          : Operation selection code.
  //   bean_sel        : Bean select value.
  //   grind_delay     : Delay for grind.
  //   heat_delay      : Delay for heat.
  //   pour_delay      : Delay for pour.
  //   sensor_val      : Sensor condition (default 0).
  //   inject_interrupt: If set to 1, injects sensor[3] interrupt mid-operation.
  //-------------------------------------------------------------------------
  task execute_operation(
    input string test_name,
    input logic [2:0] op_sel,
    input logic [NBW_BEANS-1:0] bean_sel,
    input logic [NBW_DLY-1:0] grind_delay,
    input logic [NBW_DLY-1:0] heat_delay,
    input logic [NBW_DLY-1:0] pour_delay,
    input logic [NS_SENSOR-1:0] sensor_val = 4'b0,
    input bit inject_interrupt = 0
  );
  begin
    $display("\n===== Starting %s =====", test_name);

    // Apply test inputs
    i_operation_sel <= 0;
    i_grind_delay   <= 0;
    i_heat_delay    <= 0;
    i_pour_delay    <= 0;
    i_bean_sel      <= 0;
    i_sensor        <= 0;

    @(posedge clk);
    @(posedge clk);
    // Trigger operation start
    i_start         <= 1'b1;
    // Apply test inputs
    i_operation_sel <= op_sel;
    i_grind_delay   <= grind_delay;
    i_heat_delay    <= heat_delay;
    i_pour_delay    <= pour_delay;
    i_bean_sel      <= bean_sel;
    i_sensor        <= sensor_val;
    @(posedge clk);
    i_start         <= 1'b0;

    // Optionally inject an interrupt via sensor[3]
    if(inject_interrupt) begin
      i_operation_sel <= 3'b0;
      wait(dut.state_ff==3'b110);
      i_sensor[3]     <= 1'b1;
      $display("Injected interrupt via sensor[3]");
      @(posedge clk);
      i_sensor[3]     <= 1'b0;

      wait(dut.state_ff==3'b000);
      @(posedge clk);
      i_start         <= 1'b1;
      i_operation_sel <= 3'b010;
      @(posedge clk);
      i_start         <= 1'b0;
      wait(dut.state_ff==3'b001);
      @(posedge clk);
      i_sensor[3]     <= 1'b1;
      $display("Injected interrupt via sensor[3]");
      @(posedge clk);
      i_sensor[3]     <= 1'b0;

      wait(dut.state_ff==3'b000);
      @(posedge clk);
      i_start         <= 1'b1;
      i_operation_sel <= 3'b010;
      @(posedge clk);
      i_start         <= 1'b0;
      wait(dut.state_ff==3'b111);
      @(posedge clk);
      i_sensor[3]     <= 1'b1;
      $display("Injected interrupt via sensor[3]");
      @(posedge clk);
      i_sensor[3]     <= 1'b0;

      wait(dut.state_ff==3'b000);
      i_operation_sel <= 3'b101;
      @(posedge clk);
      i_start         <= 1'b1;
      @(posedge clk);
      i_start         <= 1'b0;
      wait(dut.state_ff==3'b100);
      @(posedge clk);
      i_sensor[3]     <= 1'b1;
      $display("Injected interrupt via sensor[3]");
      @(posedge clk);
      i_sensor[3]     <= 1'b0;

      wait(dut.state_ff==3'b000);
      i_operation_sel <= 3'b010;
      @(posedge clk);
      i_start         <= 1'b1;
      @(posedge clk);
      i_start         <= 1'b0;
      wait(dut.state_ff==3'b011);
      @(posedge clk);
      i_sensor[3]     <= 1'b1;
      $display("Injected interrupt via sensor[3]");
      @(posedge clk);
      i_sensor[3]     <= 1'b0;
    end

    $display("%s Completed with o_error = %d", test_name, o_error);
    #20;
  end
  endtask

  //-------------------------------------------------------------------------
  // Main Stimulus
  //-------------------------------------------------------------------------
  initial begin
    // Initialize inputs to known values
    i_grind_delay    <= 5'd10;
    i_heat_delay     <= 5'd8;
    i_pour_delay     <= 5'd6;
    i_bean_sel       <= 2'd0;
    i_operation_sel  <= 3'b000;
    i_sensor         <= 4'b0;
    i_start          <= 1'b0;

    // Wait for reset deassertion and stabilization
    @(posedge rst_async_n);
    @(posedge clk);
    @(posedge clk);
    wait_operation_complete();

    //-------------------------------------------------------------------------
    // Directed Test Cases using the unified task
    //-------------------------------------------------------------------------
    execute_operation("OP 3'b000: HEAT then POUR"                          , 3'b000, 2'd0, 5'd10, 5'd10, 5'd02);
    wait_operation_complete();
    execute_operation("OP 3'b001: HEAT, POWDER, then POUR"                 , 3'b001, 2'd0, 5'd31, 5'd31, 5'd01);
    wait_operation_complete();
    execute_operation("OP 3'b010: BEAN_SEL, GRIND, HEAT, POWDER, then POUR", 3'b010, 2'd2, 5'd01, 5'd01, 5'd10);
    wait_operation_complete();
    execute_operation("OP 3'b011: BEAN_SEL, GRIND, POWDER, then POUR"      , 3'b011, 2'd1, 5'd02, 5'd02, 5'd31);
    wait_operation_complete();
    execute_operation("OP 3'b100: POWDER then POUR"                        , 3'b100, 2'd0, 5'd10, 5'd8, 5'd6);
    wait_operation_complete();
    execute_operation("OP 3'b101: POUR only"                               , 3'b101, 2'd0, 5'd10, 5'd8, 5'd6);
    wait_operation_complete();
    // Illegal operation tests (expecting error)
    execute_operation("OP 3'b110: Illegal operation"                       , 3'b110, 2'd0, 5'd10, 5'd8, 5'd6);
    wait_operation_complete();
    execute_operation("OP 3'b111: Illegal operation"                       , 3'b111, 2'd0, 5'd10, 5'd8, 5'd6);
    wait_operation_complete();
    // Sensor error tests
    execute_operation("Sensor Error: No water available"                   , 3'b000, 2'd0, 5'd10, 5'd8, 5'd6, 4'b0001);
    wait_operation_complete();
    execute_operation("Sensor Error: No beans available"                   , 3'b010, 2'd0, 5'd10, 5'd8, 5'd6, 4'b0010);
    wait_operation_complete();
    execute_operation("Sensor Error: No powder available"                  , 3'b001, 2'd0, 5'd10, 5'd8, 5'd6, 4'b0100);
    wait_operation_complete();
    execute_operation("Sensor Error: Generic error"                        , 3'b001, 2'd0, 5'd10, 5'd8, 5'd6, 4'b1000);
    wait_operation_complete();
    // Interrupt test: inject sensor[3] mid-operation
    execute_operation("Interrupt: Generic error during operation"          , 3'b000, 2'd1, 5'd10, 5'd8, 5'd6, 4'b0000, 1);
    wait_operation_complete();

    //-------------------------------------------------------------------------
    // Stress Test: Randomly generated valid operations
    //-------------------------------------------------------------------------
    stress_test(50);

    $display("All tests completed successfully.");
    $finish;
  end

  //-------------------------------------------------------------------------
  // Task: stress_test
  // Randomly generates valid operations and applies them over a number of iterations.
  //-------------------------------------------------------------------------
  task stress_test(input int num_tests);
    int i;
    logic [2:0] rand_op;
    logic [NBW_DLY-1:0] rand_grind;
    logic [NBW_DLY-1:0] rand_heat;
    logic [NBW_DLY-1:0] rand_pour;
    logic [NBW_BEANS-1:0] rand_bean;
  begin
    @(posedge clk);
    $display("\n===== Starting Stress Test: %0d iterations =====", num_tests);
    for (i = 0; i < num_tests; i++) begin
      case($urandom_range(0,5))
        0: rand_op = 3'b000;
        1: rand_op = 3'b001;
        2: rand_op = 3'b010;
        3: rand_op = 3'b011;
        4: rand_op = 3'b100;
        5: rand_op = 3'b101;
        default: rand_op = 3'b000;
      endcase

      rand_grind = $urandom_range(3, 15);
      rand_heat  = $urandom_range(3, 15);
      rand_pour  = $urandom_range(3, 15);
      rand_bean  = $urandom_range(0, (2**NBW_BEANS)-1);

      $display("Stress Iteration %0d: op=%b, bean=%0d, grind=%0d, heat=%0d, pour=%0d",
               i, rand_op, rand_bean, rand_grind, rand_heat, rand_pour);

      // Use the unified task for each iteration
      execute_operation($sformatf("Stress Iteration %0d", i), rand_op, rand_bean,
                        rand_grind, rand_heat, rand_pour);
      wait_operation_complete();
      $display("Stress Iteration %0d: completed with o_error = %d", i, o_error);
      @(posedge clk);
    end
    $display("===== Stress Test Completed =====\n");
  end
  endtask

endmodule