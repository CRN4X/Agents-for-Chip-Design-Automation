`timescale 1ns/1ps
module event_scheduler_tb;

    
    reg clk;
    reg reset;
    reg add_event;
    reg cancel_event;
    reg [3:0] event_id;
    reg [15:0] timestamp;
    reg [3:0] priority_in;
    reg [3:0] trig_id;
    reg [15:0] trig_time;
    reg [15:0] future_time;
    wire event_triggered;
    wire [3:0] triggered_event_id;
    wire error;
    wire [15:0] current_time;
    
    
    event_scheduler dut (
        .clk(clk),
        .reset(reset),
        .add_event(add_event),
        .cancel_event(cancel_event),
        .event_id(event_id),
        .timestamp(timestamp),
        .priority_in(priority_in),
        .event_triggered(event_triggered),
        .triggered_event_id(triggered_event_id),
        .error(error),
        .current_time(current_time)
    );

    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    
    task wait_clock;
        @(posedge clk);
    endtask

    
    task wait_for_trigger(output [3:0] trig_id, output [15:0] trig_time);
        begin
            
            while (event_triggered !== 1) begin
                wait_clock;
            end
            trig_id = triggered_event_id;
            trig_time = current_time;
            
            wait_clock;
        end
    endtask

    initial begin
        
        reset = 1;
        add_event = 0;
        cancel_event = 0;
        event_id = 0;
        timestamp = 0;
        priority_in = 0;

        
        repeat (2) wait_clock;
        reset = 0;
        
        wait_clock;
        add_event = 1;
        event_id = 4;
        timestamp = 16'd20;
        priority_in = 4'd2;
        wait_clock; 
        add_event = 0;
        
        wait_for_trigger(trig_id, trig_time);
        if (trig_id == 4)
            $display("Test Case 1 Passed: Event 4 triggered at time %0d ns", trig_time);
        else
            $display("Test Case 1 Failed: Expected event 4 trigger, got %0d at time %0d ns", trig_id, trig_time);

        
        wait_clock;
        future_time = current_time + 40;
                
        add_event = 1;
        event_id = 5;
        timestamp = future_time;
        priority_in = 4'd3;
        wait_clock;
        add_event = 0;
        
        
        wait_clock;
        add_event = 1;
        event_id = 6;
        timestamp = future_time;
        priority_in = 4'd1;
        wait_clock;
        add_event = 0;
        
        
        while (current_time < future_time)
            wait_clock;
        wait_for_trigger(trig_id, trig_time);
        if (trig_id == 5)
            $display("Test Case 2 Passed: Event 5 (priority 3) triggered over Event 6 at time %0d ns", trig_time);
        else
            $display("Test Case 2 Failed: Incorrect event triggered (got %0d) at time %0d ns", trig_id, trig_time);
            
        
        wait_clock;
        add_event = 1;
        event_id = 7;
        timestamp = current_time + 20;
        priority_in = 4'd2;
        wait_clock;
        add_event = 0;
                
        wait_clock;
        cancel_event = 1;
        event_id = 7;
        wait_clock;
        cancel_event = 0;
        
        repeat (4) wait_clock;
        if (event_triggered && (triggered_event_id == 7))
            $display("Test Case 3 Failed: Event 7 triggered despite cancellation at time %0d ns", current_time);
        else
            $display("Test Case 3 Passed: Event 7 cancelled successfully (no trigger) at time %0d ns", current_time);
            
        #50;
        $finish;
    end

    initial begin
        $dumpfile("event_scheduler.vcd");
        $dumpvars(0, event_scheduler_tb);
    end

endmodule