`timescale 1ns/1ps

module tb_fifo_buffer;

  
  parameter int unsigned NUM_OF_REQS = 2;
  parameter bit          ResetAll    = 1'b0; 

  
  logic                clk_i;
  logic                rst_i;
  logic                clear_i;
  logic [NUM_OF_REQS-1:0] busy_o;

  logic                in_valid_i;
  logic [31:0]         in_addr_i;
  logic [31:0]         in_rdata_i;
  logic                in_err_i;

  logic                out_valid_o;
  logic                out_ready_i;
  logic [31:0]         out_addr_o;
  logic [31:0]         out_rdata_o;
  logic                out_err_o;
  logic                out_err_plus2_o;

  
  fifo_buffer #(
    .NUM_OF_REQS(NUM_OF_REQS),
    .ResetAll(ResetAll)
  ) dut (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .clear_i(clear_i),
    .busy_o(busy_o),
    .in_valid_i(in_valid_i),
    .in_addr_i(in_addr_i),
    .in_rdata_i(in_rdata_i),
    .in_err_i(in_err_i),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .out_addr_o(out_addr_o),
    .out_rdata_o(out_rdata_o),
    .out_err_o(out_err_o),
    .out_err_plus2_o(out_err_plus2_o)
  );

  initial begin
    clk_i = 0;
    forever #5 clk_i = ~clk_i;
  end

  initial begin
    rst_i = 0;
    #20;
    rst_i = 1;
  end

  initial begin
    clear_i     = 0;
    in_valid_i  = 0;
    in_addr_i   = 32'h0000_0000;
    in_rdata_i  = 32'h0;
    in_err_i    = 0;
    out_ready_i = 0;
    
    @(posedge rst_i);
    #10;
    
    $display("\n*** Test 1: Clear FIFO (Aligned PC) ***");
    clear_i   = 1;
    in_addr_i = 32'h0000_0000;
    #10;
    clear_i = 0;
    #10;
    
    $display("\n*** Test 2: Single Instruction Fetch (Aligned) ***");
    in_valid_i = 1;
    in_rdata_i = 32'h8C218363;
    in_err_i   = 0;
    #10;
    in_valid_i = 0;
    #10;
    
    out_ready_i = 1;
    #10;
    out_ready_i = 0;
    #10;
    
    $display("\n*** Test 3: FIFO Depth Test ***");
    in_valid_i = 1;
    in_rdata_i = 32'h6C2183E3;
    in_err_i   = 0;
    #10;
    in_rdata_i = 32'h926CF16F;
    #10;
    in_valid_i = 0;
    #10;
    
    out_ready_i = 1;
    repeat (3) begin
      #10;
    end
    out_ready_i = 0;
    #10;
    
    $display("\n*** Test 4: Unaligned Instruction Fetch ***");
    clear_i   = 1;
    in_addr_i = 32'h0000_0002;
    #10;
    clear_i = 0;
    #10;
    
    in_valid_i = 1;
    in_rdata_i = 32'hF63101E7;
    in_err_i   = 0;
    #10;
    
    in_rdata_i = 32'h763101E7;
    #10;
    in_valid_i = 0;
    #10;
    
    out_ready_i = 1;
    repeat (3) begin
      #10;
    end
    out_ready_i = 0;
    #10;
    
    $display("\n*** Test 5: Error Handling ***");
    clear_i   = 1;
    in_addr_i = 32'h0000_0000;
    #10;
    clear_i = 0;
    #10;
    
    in_valid_i = 1;
    in_rdata_i = 32'h4840006F;
    in_err_i   = 1;
    #10;
    in_valid_i = 0;
    #10;
    
    out_ready_i = 1;
    #10;
    out_ready_i = 0;
    #10;
    
    $display("\n*** End of Simulation ***");
    $finish;
  end

  initial begin
    $display("Time\tclear in_valid in_addr    in_rdata      in_err | out_valid out_addr    out_rdata     out_err out_err_plus2 | busy");
    $monitor("%0t\t%b      %b      %h   %h    %b    | %b      %h  %h   %b    %b    | %h",
             $time, clear_i, in_valid_i, in_addr_i, in_rdata_i, in_err_i,
             out_valid_o, out_addr_o, out_rdata_o, out_err_o, out_err_plus2_o,
             busy_o);
  end

endmodule