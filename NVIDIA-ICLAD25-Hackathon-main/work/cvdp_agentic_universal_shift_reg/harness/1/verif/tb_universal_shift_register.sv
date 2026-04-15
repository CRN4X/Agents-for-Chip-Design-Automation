`timescale 1ns / 1ps

module universal_shift_register_tb;

    parameter N = 8;  // Define register size
    reg clk, rst, shift_dir, serial_in;
    reg [1:0] mode_sel;
    reg [N-1:0] parallel_in;
    wire [N-1:0] q;
    wire serial_out;
    
    reg [N-1:0] expected_q;
    reg expected_serial_out;

    // Instantiate the Universal Shift Register
    universal_shift_register #(.N(N)) USR (
        .clk(clk),
        .rst(rst),
        .mode_sel(mode_sel),
        .shift_dir(shift_dir),
        .serial_in(serial_in),
        .parallel_in(parallel_in),
        .q(q),
        .serial_out(serial_out)
    );

    // Clock Generator (10ns period)
    always #5 clk = ~clk;

    // Reset before each test
    task reset_register();
        begin
            rst = 1;
            @(posedge clk);
            rst = 0;
            @(posedge clk);
            expected_q = 0;
            expected_serial_out = 0;
            $display("Reset completed.");
        end
    endtask

    // Task for PIPO (Parallel In - Parallel Out) - Only checks q
    task test_pipo();
        begin
            reset_register();
            parallel_in = $random;
            mode_sel = 2'b11; // PIPO mode
            expected_q = parallel_in;
            @(posedge clk);
            
            if (q !== expected_q)
                $display("**ERROR**: PIPO - Expected q=%b but got q=%b", expected_q, q);
            else
                $display("PIPO - PASSED | Input: %b | Expected q=%b | Got q=%b", parallel_in, expected_q, q);
        end
    endtask

 // Task for PISO (Parallel In - Serial Out) - Only checks serial_out
task test_piso();
reg serial_out_value;
    begin
        reset_register();
        parallel_in = $random;  // Load known data
        mode_sel = 2'b11; // Load parallel data
        @(posedge clk); // Ensure parallel data is loaded

        expected_q = parallel_in; // Initialize expected register state

        mode_sel = 2'b01; shift_dir = 0; // Shift Right mode
        repeat (N) begin
            serial_out_value = serial_out;
            @(posedge clk); // Wait for shift to happen
            expected_serial_out = expected_q[0]; // Capture expected serial output before shift
            expected_q = {1'b0, expected_q[N-1:1]}; // Perform shift

            if (serial_out_value !== expected_serial_out)
                $display("**ERROR**: PISO Shift Right - Expected serial_out=%b but got serial_out=%b", expected_serial_out, serial_out_value);
            else
                $display("PISO - PASSED | Input: %b | Expected serial_out=%b | Got serial_out=%b", parallel_in, expected_serial_out, serial_out_value);
        end
    end
endtask

    // Task for SISO (Serial In - Serial Out) - Only checks serial_out
    task test_siso();
    reg serial_out_value;
        begin
            reset_register();
            mode_sel = 2'b01; shift_dir = 0; serial_in = $random;
            expected_q = 0;
            repeat (N*2) begin
                serial_out_value  = serial_out;
                expected_serial_out = expected_q[0]; // LSB to serial_out
                expected_q = {serial_in, expected_q[N-1:1]};
                @(posedge clk);
                
                if (serial_out_value !== expected_serial_out)
                    $display("**ERROR**: SISO Shift Right - Expected serial_out=%b but got serial_out=%b", expected_serial_out, serial_out_value);
                else
                    $display("SISO - PASSED | Input: %b | Expected serial_out=%b | Got serial_out=%b", serial_in, expected_serial_out, serial_out_value);
            end
        end
    endtask

    // Task for SIPO (Serial In - Parallel Out) - Only checks q
    task test_sipo();
    reg [N-1:0] q_out;
        begin
            reset_register();
            mode_sel = 2'b01; shift_dir = 0;
            expected_q = 0;
            serial_in = $random;
            repeat (N) begin
                q_out = q;
                @(negedge clk);
                expected_q = {serial_in, expected_q[N-1:1]};
                @(posedge clk);
                
                if (q_out !== expected_q)
                    $display("**ERROR**: SIPO Shift Right - Expected q=%b but got q=%b", expected_q, q_out);
                else
                    $display("SIPO - PASSED | Serial Input: %b | Expected q=%b | Got q=%b", serial_in, expected_q, q_out);
            end
        end
    endtask

    // Task for Rotate Right - Only checks q
    task test_rotate_right();
        begin
            reset_register();
            parallel_in = $random;
            mode_sel = 2'b11; // Load parallel data
            expected_q = parallel_in;
            @(posedge clk);

            mode_sel = 2'b10; shift_dir = 0;
            repeat (N) begin
                @(negedge clk);
                expected_q = {expected_q[0], expected_q[N-1:1]}; // Rotate Right
                @(posedge clk);
                
                if (q !== expected_q)
                    $display("**ERROR**: Rotate Right - Expected q=%b but got q=%b", expected_q, q);
                else
                    $display("Rotate Right - PASSED | Input: %b | Expected q=%b | Got q=%b", parallel_in, expected_q, q);
            end
        end
    endtask

    // Task for Rotate Left - Only checks q
    task test_rotate_left();
        begin
            reset_register();
            parallel_in = $urandom;
            mode_sel = 2'b11; // Load parallel data
            expected_q = parallel_in;
            @(posedge clk);

            mode_sel = 2'b10; shift_dir = 1;
            repeat (N) begin
                @(negedge clk);
                expected_q = {expected_q[N-2:0], expected_q[N-1]}; // Rotate Left
                @(posedge clk);
                
                if (q !== expected_q)
                    $display("**ERROR**: Rotate Left - Expected q=%b but got q=%b", expected_q, q);
                else
                    $display("Rotate Left - PASSED | Input: %b | Expected q=%b | Got q=%b", parallel_in, expected_q, q);
            end
        end
    endtask

    // Task for Hold State - Only checks q
    task test_hold();
        begin
            reset_register();
            parallel_in = $urandom;
            mode_sel = 2'b11; // Load parallel data
            expected_q = parallel_in;
            @(posedge clk);

            mode_sel = 2'b00;
            @(posedge clk);

            if (q !== expected_q)
                $display("**ERROR**: Hold Mode - Expected q=%b but got q=%b", expected_q, q);
            else
                $display("Hold - PASSED | Input: %b | Expected q=%b | Got q=%b", parallel_in, expected_q, q);
        end
    endtask

    // Main Testbench Execution
    initial begin
        clk = 0;
        serial_in = 0;
        parallel_in = 0;
        @(posedge  clk)
        $display("\n=== Universal Shift Register Testbench ===\n");

        // Run each test
        test_pipo();
        test_piso();
        test_siso();
        test_sipo();
        test_rotate_right();
        test_rotate_left();
        test_hold();

        $display("\n=== Test Complete ===\n");
        #10;
        $finish;
    end

    // VCD Waveform Dump
    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0, universal_shift_register_tb);
    end
endmodule