`timescale 1ns / 1ps

module universal_shift_register_tb;

    // -----------------------------------------------------
    // Parameter
    // -----------------------------------------------------
    parameter N = 8;

    // -----------------------------------------------------
    // Registers & Wires
    // -----------------------------------------------------
    // Inputs to the DUT
    reg              clk;
    reg              rst;
    reg              en;
    reg  [2:0]       op_sel;       // 3-bit operation select
    reg              shift_dir;    // 0=right, 1=left
    reg  [1:0]       bitwise_op;   // 00=AND, 01=OR, 10=XOR, 11=XNOR
    reg              serial_in;
    reg  [N-1:0]     parallel_in;

    // Outputs from the DUT
    wire [N-1:0]     q;
    wire             serial_out;
    wire             msb_out;
    wire             lsb_out;
    wire             overflow;
    wire             parity_out;
    wire             zero_flag;

    // Internal tracking for checking correctness
    reg  [N-1:0]     expected_q;
    reg              expected_overflow;
    reg              expected_msb_out;
    reg              expected_lsb_out;
    reg              expected_serial_out;
    reg              expected_parity;
    reg              expected_zero_flag;

    // -----------------------------------------------------
    // Device Under Test (DUT)
    // -----------------------------------------------------
    universal_shift_register #(.N(N)) DUT (
        .clk        (clk),
        .rst        (rst),
        .en         (en),
        .op_sel     (op_sel),
        .shift_dir  (shift_dir),
        .bitwise_op (bitwise_op),
        .serial_in  (serial_in),
        .parallel_in(parallel_in),
        .q          (q),
        .serial_out (serial_out),
        .msb_out    (msb_out),
        .lsb_out    (lsb_out),
        .overflow   (overflow),
        .parity_out (parity_out),
        .zero_flag  (zero_flag)
    );

    // -----------------------------------------------------
    // Clock Generation (period = 10 ns)
    // -----------------------------------------------------
    always #5 clk = ~clk;

    // -----------------------------------------------------
    // Common Tasks
    // -----------------------------------------------------

    // Task: Reset the DUT
    task reset_register();
        begin
            rst = 1;
            en  = 1;   // Keep enable high unless we want to test disabled behavior
            // Clear all expectations
            expected_q         = {N{1'b0}};
            expected_overflow  = 1'b0;
            expected_serial_out= 1'b0;
            expected_msb_out   = 1'b0;
            expected_lsb_out   = 1'b0;
            expected_parity    = 1'b0;
            expected_zero_flag = 1'b1;
            op_sel = 3'd0;
            shift_dir = 1'b0;    
            bitwise_op =2'd0;   
            serial_in = 1'b0;
            parallel_in = {N{1'b0}};
            @(posedge clk);
            rst = 0;
            @(posedge clk);
            $display("[RESET] DUT has been reset.");
        end
    endtask

    // Task: Compare DUT outputs to expected values
    task check_outputs(string testname);
        begin
            @(posedge clk);
            // Check Q
            if (q !== expected_q) begin
                $display("**%s ERROR**: q=%b, expected=%b at time %t", 
                         testname, q, expected_q, $time);
            end
            else  $display("**%s PASS**: q=%b, expected=%b at time %t", testname, q, expected_q, $time);

            // Check overflow
            if (overflow !== expected_overflow) begin
                $display("**%s ERROR**: overflow=%b, expected=%b at time %t", 
                         testname, overflow, expected_overflow, $time);
            end
            else $display("**%s PASS**: overflow=%b, expected=%b at time %t", testname, overflow, expected_overflow, $time);

            // Check serial_out
            if (serial_out !== expected_serial_out) begin
                $display("**%s ERROR**: serial_out=%b, expected=%b at time %t", 
                         testname, serial_out, expected_serial_out, $time);
            end
            else $display("**%s PASS**: serial_out=%b, expected=%b at time %t", testname, serial_out, expected_serial_out, $time);
            
            // Check MSB and LSB
            if (msb_out !== expected_msb_out) begin
                $display("**%s ERROR**: msb_out=%b, expected=%b at time %t", 
                         testname, msb_out, expected_msb_out, $time);
            end
            else $display("**%s PASS**: msb_out=%b, expected=%b at time %t", testname, msb_out, expected_msb_out, $time);

            if (lsb_out !== expected_lsb_out) begin
                $display("**%s ERROR**: lsb_out=%b, expected=%b at time %t", 
                         testname, lsb_out, expected_lsb_out, $time);
            end
            else $display("**%s PASS**: lsb_out=%b, expected=%b at time %t", testname, lsb_out, expected_lsb_out, $time);

            // Check Parity
            if (parity_out !== expected_parity) begin
                $display("**%s ERROR**: parity_out=%b, expected=%b at time %t", 
                         testname, parity_out, expected_parity, $time);
            end
            else $display("**%s PASS**: parity_out=%b, expected=%b at time %t", testname, parity_out, expected_parity, $time);

            // Check Zero Flag
            if (zero_flag !== expected_zero_flag) begin
                $display("**%s ERROR**: zero_flag=%b, expected=%b at time %t",
                         testname, zero_flag, expected_zero_flag, $time);
            end
            else $display("**%s PASS**: zero_flag=%b, expected=%b at time %t", testname, zero_flag, expected_zero_flag, $time);

        end
    endtask

    // Helper task to update the "expected" signals after Q changes
    task update_expected_signals();
        begin
            expected_msb_out   = expected_q[N-1];
            expected_lsb_out   = expected_q[0];
            expected_parity    = ^expected_q; 
            expected_zero_flag = (expected_q == {N{1'b0}});
        end
    endtask

    // -----------------------------------------------------
    // TEST #1: HOLD (op_sel = 000)
    // -----------------------------------------------------
    task test_hold();
        begin
            $display("\n--- TEST: HOLD (op_sel=000) ---");

            // Initialize
            reset_register();
            // Parallel load some random value
            parallel_in = $random;
            op_sel      = 3'b011;  // parallel load
            expected_q  = parallel_in;
            update_expected_signals(); 
            expected_overflow  = 1'b0;
            expected_serial_out= (shift_dir == 0)? expected_q[0] : expected_q[N-1];

            @(posedge clk);
            check_outputs("HOLD(Load)");

            // Now switch to HOLD mode
            @(posedge clk);
            op_sel = 3'b000;
            repeat (3) begin
                @(posedge clk);
                // Q should not change
                check_outputs("HOLD(NoChange)");
            end
        end
    endtask

    // -----------------------------------------------------
    // TEST #2: SHIFT (Logical) (op_sel = 001)
    // -----------------------------------------------------
    task test_shift_logical();
        integer i;
        begin
            $display("\n--- TEST: SHIFT (Logical) (op_sel=001) ---");
            @(posedge clk);
            // Initialize
            reset_register();

            // Load a known parallel data
            parallel_in = $random;
            serial_in = $random;
            op_sel      = 3'b011; // parallel load
            expected_q  = parallel_in; 
            expected_overflow   = 1'b0;
            expected_serial_out = expected_q[0]; // default shift_dir=0?
            update_expected_signals();
            
            @(posedge clk);
            // SHIFT RIGHT test
            shift_dir = 1'b0; // shift right
            op_sel    = 3'b001;
            for (i = 0; i < N; i = i + 1) begin
                // Sample "serial_out" before it changes
                expected_overflow   = expected_q[0];
                expected_q          = {serial_in, expected_q[N-1:1]};
                expected_serial_out = expected_q[0];
                update_expected_signals();
                check_outputs("SHIFT_RIGHT");
            end

            // SHIFT LEFT test
            reset_register();
            @(posedge clk);
            // Load a known parallel data
            parallel_in = $random;
            serial_in = $random;
            op_sel      = 3'b011; 
            expected_q  = parallel_in;
            update_expected_signals();
            expected_overflow   = 1'b0;

            @(posedge clk);
            shift_dir = 1'b1; // shift left
            op_sel    = 3'b001;
            for (i = 0; i < N; i = i + 1) begin
                expected_overflow   = expected_q[N-1];
                expected_q          = {expected_q[N-2:0], serial_in}; 
                expected_serial_out = expected_q[N-1];
                update_expected_signals();
                check_outputs("SHIFT_LEFT");
            end
        end
    endtask

    // -----------------------------------------------------
    // TEST #3: ROTATE (op_sel = 010)
    // -----------------------------------------------------
    task test_rotate();
        integer i;
        begin
            $display("\n--- TEST: ROTATE (op_sel=010) ---");
            reset_register();

            @(posedge clk);
            // Load some random data
            parallel_in = $random;
            op_sel = 3'b011; // parallel load
            expected_q = parallel_in;
            update_expected_signals();

            // Rotate Right
            @(posedge clk);
            shift_dir = 1'b0;
            op_sel    = 3'b010;
            for (i = 0; i < N; i = i + 1) begin
                // Overflow is the bit we "would lose," but in rotate,
                // we typically carry it around. Implementation might store it anyway.
                expected_overflow = expected_q[0];
                expected_q = {expected_q[0], expected_q[N-1:1]};
                expected_serial_out = expected_q[0]; // if you treat rotate like shift
                update_expected_signals();
                check_outputs("ROTATE_RIGHT");
            end

            // Rotate Left
            reset_register();
            @(posedge clk);
            parallel_in = $random;
            op_sel      = 3'b011; // load
            expected_q = parallel_in;
            update_expected_signals();
            @(posedge clk);
            shift_dir = 1'b1;
            op_sel    = 3'b010;
            for (i = 0; i < N; i = i + 1) begin
                expected_overflow = expected_q[N-1];
                expected_q = {expected_q[N-2:0], expected_q[N-1]};
                expected_serial_out = expected_q[N-1];
                update_expected_signals();
                check_outputs("ROTATE_LEFT");
            end
        end
    endtask

    // -----------------------------------------------------
    // TEST #4: PARALLEL LOAD (op_sel = 011)
    // -----------------------------------------------------
    task test_parallel_load();
        begin
            $display("\n--- TEST: PARALLEL LOAD (op_sel=011) ---");
            reset_register();
            @(posedge clk);
            // Try multiple loads
            parallel_in = 8'hA5;
            op_sel      = 3'b011;
            @(posedge clk);
            expected_q = parallel_in;
            update_expected_signals();
            expected_overflow   = 1'b0;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            @(posedge clk);
            check_outputs("PARALLEL_LOAD_1");

            parallel_in = 8'h3C;
            @(posedge clk);
            expected_q = parallel_in;
            update_expected_signals();
            expected_overflow   = 1'b0;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            @(posedge clk);
            check_outputs("PARALLEL_LOAD_2");
        end
    endtask

    // -----------------------------------------------------
    // TEST #5: ARITHMETIC SHIFT (op_sel = 100)
    // -----------------------------------------------------
    task test_arithmetic_shift();
        integer i;
        begin
            $display("\n--- TEST: ARITHMETIC SHIFT (op_sel=100) ---");
            reset_register();
            @(posedge clk);
            // For right shift, sign bit is replicated
            parallel_in = 8'b1101_0010; // MSB=1
            op_sel      = 3'b011; // load
            expected_q  = parallel_in;
            update_expected_signals();

            // SHIFT RIGHT (MSB is repeated)
            @(posedge clk);
            shift_dir   = 1'b0;
            op_sel      = 3'b100;
            for (i = 0; i < N; i = i + 1) begin
                expected_overflow   = expected_q[0];
                expected_q         = {expected_q[N-1], expected_q[N-1:1]};
                expected_serial_out = expected_q[0];
                update_expected_signals();
                check_outputs("ARITH_SHIFT_RIGHT");
            end

            // SHIFT LEFT (like logical shift left)
            reset_register();
            parallel_in = 8'b0101_0010; // MSB=0
            op_sel      = 3'b011; // load
            expected_q  = parallel_in;
            update_expected_signals();

            @(posedge clk);
            shift_dir   = 1'b1;
            op_sel      = 3'b100;
            for (i = 0; i < N; i = i + 1) begin
                expected_overflow   = expected_q[N-1];
                // Arithmetic shift left = logical shift left
                expected_q         = {expected_q[N-2:0], 1'b0};
                expected_serial_out = expected_q[N-1];
                update_expected_signals();
                check_outputs("ARITH_SHIFT_LEFT");
            end
        end
    endtask

    // -----------------------------------------------------
    // TEST #6: BITWISE OPS (op_sel = 101)
    // -----------------------------------------------------
    task test_bitwise_op();
        begin
            $display("\n--- TEST: BITWISE OPS (op_sel=101) ---");
            reset_register();
            @(posedge clk);

            // Load some base value into Q
            parallel_in = 8'hF0;
            op_sel      = 3'b011; // load
            expected_q = parallel_in;
            expected_overflow   = 1'b0;
            update_expected_signals();

            @(posedge clk);
            // 1) AND
            bitwise_op  = 2'b00;
            op_sel      = 3'b101;
            expected_q  = expected_q & 8'hF0;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            update_expected_signals();
            check_outputs("BITWISE_AND");
            
            @(posedge clk);
            reset_register();
            @(posedge clk);
            // Load some base value into Q
            parallel_in = 8'h55;
            op_sel      = 3'b011; // load
            expected_q = parallel_in;
            update_expected_signals();

            // 2) OR
            @(posedge clk);
            bitwise_op  = 2'b01;
            op_sel      = 3'b101;
            expected_q  = expected_q | 8'h55;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            update_expected_signals();
            check_outputs("BITWISE_OR");

            @(posedge clk);
            reset_register();
            @(posedge clk);
            // Load some base value into Q
            parallel_in = 8'hFF;
            op_sel      = 3'b011; // load
            expected_q = parallel_in;
            update_expected_signals();

            // 3) XOR
            @(posedge clk);
            parallel_in = 8'hFF; 
            expected_q = parallel_in;
            op_sel      = 3'b101;
            bitwise_op  = 2'b10;
            expected_q  = expected_q ^ 8'hFF;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            update_expected_signals();
            check_outputs("BITWISE_XOR");

            @(posedge clk);
            reset_register();
            @(posedge clk);
            // Load some base value into Q
            parallel_in = 8'h00;
            op_sel      = 3'b011; // load
            expected_q = parallel_in;
            update_expected_signals();

            // 4) XNOR
            @(posedge clk);
            parallel_in = 8'h00;
            expected_q = parallel_in;
            bitwise_op  = 2'b11;
            op_sel      = 3'b101;
            expected_q  = ~(expected_q ^ 8'h00);
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            update_expected_signals();
            check_outputs("BITWISE_XNOR");
        end
    endtask

    // -----------------------------------------------------
    // TEST #7: REVERSE BITS (op_sel = 110)
    // -----------------------------------------------------
    function [N-1:0] reverse_bits(input [N-1:0] val);
        integer j;
        begin
            for (j = 0; j < N; j = j + 1) begin
                reverse_bits[j] = val[N-1-j];
            end
        end
    endfunction

    task test_reverse();
        begin
            $display("\n--- TEST: REVERSE BITS (op_sel=110) ---");
            @(posedge clk);
            reset_register();
            @(posedge clk);
            parallel_in = 8'b1010_1100;
            op_sel      = 3'b011; // load
            expected_q  = parallel_in;
            update_expected_signals();
            check_outputs("BEFORE_REVERSE");


            @(posedge clk);
            op_sel      = 3'b110; // reverse
            expected_q  = reverse_bits(expected_q);
            expected_overflow   = 1'b0;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            update_expected_signals();
            check_outputs("AFTER_REVERSE");
        end
    endtask

    // -----------------------------------------------------
    // TEST #8: COMPLEMENT (op_sel = 111)
    // -----------------------------------------------------
    task test_complement();
        begin
            $display("\n--- TEST: COMPLEMENT (op_sel=111) ---");
            @(posedge clk);
            reset_register();
            @(posedge clk);
            parallel_in = 8'b1100_1100;
            op_sel      = 3'b011; // load
            expected_q  = parallel_in;
            update_expected_signals();


            @(posedge clk);
            op_sel = 3'b111; // complement
            expected_q  = ~expected_q;
            expected_overflow   = 1'b0;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            update_expected_signals();
            check_outputs("COMPLEMENT");
        end
    endtask

    // -----------------------------------------------------
    // TEST #9: ENABLE TEST (en=0)
    // -----------------------------------------------------
    task test_enable();
        begin
            $display("\n--- TEST: ENABLE (en=0) ---");
            @(posedge clk);
            reset_register();
            @(posedge clk);

            // Load some value
            parallel_in = 8'hAB;
            op_sel      = 3'b011; 
            expected_q = parallel_in;
            expected_serial_out = shift_dir ? expected_q[N-1] : expected_q[0];
            update_expected_signals();
            check_outputs("ENABLE_BEFORE");

            @(posedge clk);
            // Now disable (en=0) and try to SHIFT; Q should not change
            en       = 0;
            op_sel   = 3'b001;  // SHIFT
            shift_dir= 1'b0;
            serial_in= 1'b1;    // attempt to shift
            check_outputs("ENABLE_DISABLED");
            $display("Q should remain the same when en=0");
        end
    endtask

    // -----------------------------------------------------
    // Test Sequence
    // -----------------------------------------------------
    initial begin
        // Initialize
        clk        = 1'b0;
        rst        = 1'b0;
        en         = 1'b1;
        op_sel     = 3'b000;
        shift_dir  = 1'b0;
        bitwise_op = 2'b00;
        serial_in  = 1'b0;
        parallel_in= {N{1'b0}};

        // Allow time for everything to settle
        @(posedge clk);
        rst        = 1'b1;
        @(posedge clk);
        rst        = 1'b0;       
        $display("\n=========== Starting Expanded USR Testbench ===========\n");

        // Run a battery of tests
        test_hold();
        test_shift_logical();
        test_rotate();
        test_parallel_load();
        test_arithmetic_shift();
        test_bitwise_op();
        test_reverse();
        test_complement();
        test_enable();

        // All done
        $display("\n=========== ALL TESTS COMPLETED ===========\n");
        #10 $finish;
    end

    // Waveform Dump (optional in many simulators)
    initial begin
        $dumpfile("universal_shift_register_tb.vcd");
        $dumpvars(0, universal_shift_register_tb);
    end

endmodule