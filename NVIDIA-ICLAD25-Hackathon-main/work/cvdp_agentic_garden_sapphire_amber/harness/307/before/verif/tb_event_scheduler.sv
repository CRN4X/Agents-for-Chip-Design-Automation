`timescale 1ns/1ps

module tb_event_scheduler;

  
  reg clk;
  reg reset;
  reg add_event;
  reg cancel_event;
  reg [3:0] event_id;
  reg [15:0] timestamp;
  reg [3:0] priority_in;
  reg modify_event;
  reg [15:0] new_timestamp;
  reg [3:0] new_priority;
  reg recurring_event;
  reg [15:0] recurring_interval;
  wire event_triggered;
  wire [3:0] triggered_event_id;
  wire error;
  wire [15:0] current_time;
  wire [15:0] log_event_time;
  wire [3:0] log_event_id;

  
  event_scheduler dut (
    .clk(clk),
    .reset(reset),
    .add_event(add_event),
    .cancel_event(cancel_event),
    .event_id(event_id),
    .timestamp(timestamp),
    .priority_in(priority_in),
    .modify_event(modify_event),
    .new_timestamp(new_timestamp),
    .new_priority(new_priority),
    .recurring_event(recurring_event),
    .recurring_interval(recurring_interval),
    .event_triggered(event_triggered),
    .triggered_event_id(triggered_event_id),
    .error(error),
    .current_time(current_time),
    .log_event_time(log_event_time),
    .log_event_id(log_event_id)
  );

  
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  
  task clear_signals;
    begin
      add_event         = 0;
      cancel_event      = 0;
      modify_event      = 0;
      event_id          = 4'b0;
      timestamp         = 16'b0;
      priority_in       = 4'b0;
      new_timestamp     = 16'b0;
      new_priority      = 4'b0;
      recurring_event   = 0;
      recurring_interval= 16'b0;
    end
  endtask

  
  task do_reset;
    begin
      clear_signals;
      reset = 1;
      #12;  
      reset = 0;
      #10;  
    end
  endtask

  
  task wait_for_trigger;
    begin
      wait (event_triggered == 1);
      #1; 
    end
  endtask

  
  initial begin
    $display("Starting Modified Testbench with Correct Sampling...");

    
    do_reset();
    $display("\nTC1: Adding event ID=1 with timestamp=30, priority=2");
    clear_signals;
    event_id    = 4'd1;
    timestamp   = 16'd30;
    priority_in = 4'd2;
    add_event   = 1;
    #10;
    clear_signals;
    wait_for_trigger();
    $display("TC1 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC2: Adding event ID=2 then canceling it");
    clear_signals;
    event_id    = 4'd2;
    timestamp   = 16'd50;
    priority_in = 4'd3;
    add_event   = 1;
    #10;
    clear_signals;
    event_id    = 4'd2;
    cancel_event= 1;
    #10;
    clear_signals;
    repeat (5) #10;
    $display("TC2 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC3: Adding event ID=3 then modifying its timestamp and priority");
    clear_signals;
    event_id    = 4'd3;
    timestamp   = 16'd70;
    priority_in = 4'd1;
    add_event   = 1;
    #10;
    clear_signals;
    event_id       = 4'd3;
    new_timestamp  = 16'd90;
    new_priority   = 4'd4;
    modify_event   = 1;
    #10;
    clear_signals;
    wait_for_trigger();
    $display("TC3 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC4: Adding event ID=4 twice to generate error");
    clear_signals;
    event_id    = 4'd4;
    timestamp   = 16'd40;
    priority_in = 4'd2;
    add_event   = 1;
    #10;
    clear_signals;
    event_id    = 4'd4;
    timestamp   = 16'd60;
    priority_in = 4'd3;
    add_event   = 1;
    #10;
    clear_signals;
    repeat (3) #10;
    $display("TC4 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC5: Attempting to modify non-existent event ID=5 to generate error");
    clear_signals;
    event_id      = 4'd5;
    new_timestamp = 16'd100;
    new_priority  = 4'd5;
    modify_event  = 1;
    #10;
    clear_signals;
    repeat (2) #10;
    $display("TC5 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC6: Attempting to cancel non-existent event ID=6 to generate error");
    clear_signals;
    event_id    = 4'd6;
    cancel_event= 1;
    #10;
    clear_signals;
    repeat (2) #10;
    $display("TC6 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC7: Adding recurring event ID=7 with interval=20");
    clear_signals;
    event_id          = 4'd7;
    timestamp         = 16'd20; 
    priority_in       = 4'd3;
    recurring_event   = 1;
    recurring_interval= 16'd20;
    add_event         = 1;
    #10;
    clear_signals;
    wait_for_trigger(); 
    $display("TC7 (First Trigger) Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);
    repeat (2) #10;
    if (event_triggered == 1) begin
      $display("TC7 (Additional Trigger) Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
               event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);
    end

    
    do_reset();
    $display("\nTC8: Adding event ID=8 and checking log outputs");
    clear_signals;
    event_id    = 4'd8;
    timestamp   = current_time + 10;
    priority_in = 4'd2;
    add_event   = 1;
    #10;
    clear_signals;
    wait_for_trigger();
    $display("TC8 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC9: Adding event ID=9, then modifying and finally canceling it");
    clear_signals;
    event_id    = 4'd9;
    timestamp   = 16'd150;
    priority_in = 4'd2;
    add_event   = 1;
    #10;
    clear_signals;
    event_id       = 4'd9;
    new_timestamp  = 16'd170;
    new_priority   = 4'd4;
    modify_event   = 1;
    #10;
    clear_signals;
    event_id    = 4'd9;
    cancel_event= 1;
    #10;
    clear_signals;
    repeat (3) #10;
    $display("TC9 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);

    
    do_reset();
    $display("\nTC10: Adding events ID=10 and ID=11 concurrently with same timestamp but different priorities");
    clear_signals;
    event_id    = 4'd10;
    timestamp   = current_time + 20;
    priority_in = 4'd2;
    add_event   = 1;
    #1;  
    event_id    = 4'd11;
    timestamp   = current_time + 20;
    priority_in = 4'd5;
    add_event   = 1;
    #10;  
    clear_signals;
    wait_for_trigger();
    $display("TC10 Outputs: event_triggered=%0d, triggered_event_id=%0d, error=%0d, current_time=%0d, log_event_time=%0d, log_event_id=%0d",
             event_triggered, triggered_event_id, error, current_time, log_event_time, log_event_id);


    $display("\nModified Testbench finished.");
    $finish;
  end

endmodule