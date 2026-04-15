`timescale 1ns / 1ps

module async_filo_tb ();

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam DEPTH = 8;

  // Testbench Signals
  reg w_clk;
  reg r_clk;
  reg w_rst;
  reg r_rst;
  reg push;
  reg pop;
  reg [DATA_WIDTH-1:0] w_data;
  wire [DATA_WIDTH-1:0] r_data;
  wire r_empty;
  wire w_full;

  // Local Flags and Counter
  integer counter;
  logic empty, full;
  reg [DATA_WIDTH-1:0] pushed_data[0:DEPTH-1];
  reg [DATA_WIDTH-1:0] rd_data;

  // Instantiate the DUT (Device Under Test)
  async_filo #(
      .DATA_WIDTH(DATA_WIDTH),
      .DEPTH(DEPTH)
  ) async_filo_inst (
      .w_clk(w_clk),
      .w_rst(w_rst),
      .push(push),
      .r_rst(r_rst),
      .r_clk(r_clk),
      .pop(pop),
      .w_data(w_data),
      .r_data(r_data),
      .r_empty(r_empty),
      .w_full(w_full)
  );

  initial begin
    w_clk = 0;
    forever #5 w_clk = ~w_clk;
  end

  initial begin
    r_clk = 0;
    forever #7 r_clk = ~r_clk;
  end

  initial begin

    counter = 0;
    empty = 1;
    full = 0;

    w_rst = 1;
    r_rst = 1;
    push = 0;
    pop = 0;
    w_data = 0;


    $display("Applying Reset...");
    #20;
    w_rst = 0;
    r_rst = 0;
    $display("Reset Complete");
    $display("Depth = 8");
    $display("Empty Status: %0d | Full Status: %0d", empty, full);

    simulate_filo_behavior();

    $display("-------------------------------");
    $display("Performing 3 Push Operations...");
    push_data($urandom_range(0, (1 << DATA_WIDTH) - 1));
    push_data($urandom_range(0, (1 << DATA_WIDTH) - 1));
    push_data($urandom_range(0, (1 << DATA_WIDTH) - 1));

    $display("Performing 3 Pop Operations...");
    pop_data();
    pop_data();
    pop_data();

    // End Simulation
    $display("Test Completed.");
    #100;
    $finish;
  end

  task simulate_filo_behavior;
    begin
      $display("Simulating FILO Behavior - Push Operations...");
      for (int i = 0; i < DEPTH; i++) begin
        if (!full) begin
          push_data($urandom_range(0, (1 << DATA_WIDTH) - 1));
        end
      end

      $display("Simulating FILO Behavior - Pop Operations...");
      for (int i = 0; i < DEPTH; i++) begin
        if (!empty) begin
          pop_data();
        end
      end
    end
  endtask

  task push_data(input [DATA_WIDTH-1:0] data_in);
    begin
      if (!full) begin
        push = 1;
        w_data = data_in;
        pushed_data[counter] = data_in;
        @(posedge w_clk);
        push    = 0;
        counter = counter + 1;
        full    = (counter == DEPTH);
        empty   = 0;

        $display("Pushed Data: %h | Counter: %0d | Full: %0d | Empty: %0d ", data_in, counter,
                 full, empty);
      end else begin
        $display("Cannot Push, FILO is Full.");
      end
    end
  endtask

  task pop_data;
    reg [DATA_WIDTH-1:0] expected_data;
    begin
      if (!empty) begin
        rd_data = pushed_data[counter-1];
        pop = 1;
        full    = 0;
        @(posedge r_clk);
        pop = 0;

        $display("Popped Data: %h | Counter: %0d | Full: %0d | Empty: %0d", rd_data, counter - 1,
                 full, (counter == 1));

        counter = counter - 1;

      end else begin
        $display("Cannot Pop, FILO is Empty.");
      end
    end
  endtask

endmodule