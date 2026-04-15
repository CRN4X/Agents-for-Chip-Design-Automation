module tb_custom_byte_enable_ram;
  
  parameter XLEN  = 32;
  parameter LINES = 8192;
  localparam ADDR_WIDTH = $clog2(LINES);

  
  logic                     clk;
  logic [ADDR_WIDTH-1:0]    addr_a, addr_b;
  logic                     en_a, en_b;
  logic [XLEN/8-1:0]        be_a, be_b;
  logic [XLEN-1:0]          data_in_a, data_in_b;
  logic [XLEN-1:0]          data_out_a, data_out_b;

  
  custom_byte_enable_ram #(
    .XLEN(XLEN),
    .LINES(LINES)
  ) dut (
    .clk(clk),
    .addr_a(addr_a),
    .en_a(en_a),
    .be_a(be_a),
    .data_in_a(data_in_a),
    .data_out_a(data_out_a),
    .addr_b(addr_b),
    .en_b(en_b),
    .be_b(be_b),
    .data_in_b(data_in_b),
    .data_out_b(data_out_b)
  );

  
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  
  initial begin
    addr_a   = 0;
    addr_b   = 0;
    en_a     = 0;
    en_b     = 0;
    be_a     = 4'b0000;
    be_b     = 4'b0000;
    data_in_a = 32'h0;
    data_in_b = 32'h0;
    
    
    #10;
    addr_a    = 0;
    en_a      = 1;
    be_a      = 4'b1111;
    data_in_a = 32'hDEADBEEF;
    #10;  
    en_a      = 0;
    #30;  
    
    $display("Test 1: Port A read at addr 0 = %h (Expected: DEADBEEF)", data_out_a);

    
    addr_b    = 1;
    en_b      = 1;
    be_b      = 4'b1100;  
    data_in_b = 32'hCAFEBABE;
    #10;
    en_b      = 0;
    #30;
    $display("Test 2: Port B read at addr 1 = %h (Expected: CAFE0000)", data_out_b); //8403959588

    
    addr_a    = 2;
    addr_b    = 2;
    en_a      = 1;
    en_b      = 1;
    be_a      = 4'b0011;  
    data_in_a = 32'h00001234;  
    be_b      = 4'b1100;  
    data_in_b = 32'hABCD0000;  
    #10;
    en_a      = 0;
    en_b      = 0;
    #30;
    $display("Test 3: Port A read at addr 2 = %h (Expected: ABCD1234)", data_out_a);
    $display("Test 3: Port B read at addr 2 = %h (Expected: ABCD1234)", data_out_b);
    
    
    addr_a    = 3;
    en_a      = 1;
    be_a      = 4'b0011;  
    data_in_a = 32'h00001234; 
    #10;
    en_a      = 0;
    #30;
    addr_a    = 3;
    en_a      = 1;
    be_a      = 4'b1100;  
    data_in_a = 32'hABCD0000; 
    #10;
    en_a      = 0;
    #30;
    $display("Test 4: Port A read at addr 3 = %h (Expected: ABCD1234)", data_out_a);

    
    addr_a   = 5;
    en_a     = 1;
    be_a     = 4'b1111;
    data_in_a = 32'hAAAAAAAA;
    addr_b   = 6;
    en_b     = 1;
    be_b     = 4'b1111;
    data_in_b = 32'h55555555;
    #10;
    en_a     = 0;
    en_b     = 0;
    #30;
    $display("Test 5: Port A read at addr 5 = %h (Expected: AAAAAAAA)", data_out_a);
    $display("Test 5: Port B read at addr 6 = %h (Expected: 55555555)", data_out_b);

    #50;
    $finish;
  end
endmodule