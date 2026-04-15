`timescale 1ns/1ps

module tb_pseudoRandGenerator_ca;

  
  logic         clock;
  logic         reset;
  logic [15:0]  CA_seed;
  logic [1:0]   rule_sel;  
  logic [15:0]  CA_out;
  
  pseudoRandGenerator_ca dut (
    .clock(clock),
    .reset(reset),
    .CA_seed(CA_seed),
    .rule_sel(rule_sel),
    .CA_out(CA_out)
  );
    
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    reset    = 1;
    CA_seed  = 16'h1;    
    rule_sel = 2'b10;    
    #12;                
    reset = 0;
  end
  
  int cycle_count;
  int first_seen[0:65535];

  initial begin
    int j;
    for (j = 0; j < 65536; j++) begin
      first_seen[j] = -1;
    end
  end

  initial begin
    int i;
    @(negedge reset);
    @(posedge clock);
    cycle_count = 0;
    for (i = 0; i < 65536; i++) begin
      @(posedge clock);
      cycle_count++;
      if (first_seen[CA_out] == -1) begin
        first_seen[CA_out] = cycle_count;
      end else begin
        $display("Cycle %0d: Value %h repeated; first seen at cycle %0d", 
                 cycle_count, CA_out, first_seen[CA_out]);
      end
    end
    $display("Completed 65,536 cycles. Simulation finished.");
    $finish;
    
  end

endmodule