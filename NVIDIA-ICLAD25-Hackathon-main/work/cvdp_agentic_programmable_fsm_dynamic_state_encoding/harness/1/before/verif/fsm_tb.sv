`timescale 1ns/1ps
module fsm_tb;

  reg         clk;
  reg         reset;
  reg  [3:0]  input_signal;
  reg  [63:0] config_state_map_flat;
  reg  [127:0] config_transition_map_flat;
  wire [7:0]  encoded_state;
  wire [7:0]  dynamic_encoded_state;
  wire        error_flag;
  wire [7:0]  operation_result;
  
  
  fsm dut (
    .clk(clk),
    .reset(reset),
    .input_signal(input_signal),
    .config_state_map_flat(config_state_map_flat),
    .config_transition_map_flat(config_transition_map_flat),
    .encoded_state(encoded_state),
    .dynamic_encoded_state(dynamic_encoded_state),
    .error_flag(error_flag),
    .operation_result(operation_result)
  );
  
  
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  
  initial begin
    $dumpfile("fsm_tb.vcd");
    $dumpvars(0, fsm_tb);
    
    config_state_map_flat = {8'h80, 8'h70, 8'h60, 8'h50, 8'h40, 8'h30, 8'h20, 8'h10};
    
    config_transition_map_flat = { 
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h8,  
      8'h0,  
      8'h0,  
      8'h0,  
      8'h0   
    };
    
    
    reset = 1;
    input_signal = 4'b0;
    #12;
    reset = 0;
    #10;
    
    
    input_signal = 4'h1;
    #10;
    $display("Test 1: encoded_state = %0h, dynamic_encoded_state = %0h, error_flag = %b, operation_result = %0d", 
             encoded_state, dynamic_encoded_state, error_flag, operation_result);
    
    
    input_signal = 4'h2;
    #10;
    $display("Test 2: encoded_state = %0h, dynamic_encoded_state = %0h, error_flag = %b, operation_result = %0d", 
             encoded_state, dynamic_encoded_state, error_flag, operation_result);
    
    
    input_signal = 4'h3;
    #10;
    $display("Test 3: encoded_state = %0h, dynamic_encoded_state = %0h, error_flag = %b, operation_result = %0d", 
             encoded_state, dynamic_encoded_state, error_flag, operation_result);
    
    
    input_signal = 4'h4;
    #10;
    $display("Test 4 (error): encoded_state = %0h, dynamic_encoded_state = %0h, error_flag = %b, operation_result = %0d", 
             encoded_state, dynamic_encoded_state, error_flag, operation_result);
    
    
    input_signal = 4'h0;
    #10;
    $display("Test 5: encoded_state = %0h, dynamic_encoded_state = %0h, error_flag = %b, operation_result = %0d", 
             encoded_state, dynamic_encoded_state, error_flag, operation_result);
    
    $finish;
  end

endmodule