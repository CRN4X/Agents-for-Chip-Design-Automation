module dual_port_memory_tb;

    // Parameters
    localparam DATA_WIDTH = 4;
    localparam ECC_WIDTH = 3;
    localparam ADDR_WIDTH = 5;
    localparam MEM_DEPTH = 1 << ADDR_WIDTH;

    // Signals
    reg clk;
    reg rst_n;
    reg we;
    reg [ADDR_WIDTH-1:0] addr_a;
    reg [ADDR_WIDTH-1:0] addr_b;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire ecc_error;

    // DUT instance
    dual_port_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ECC_WIDTH(ECC_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .data_in(data_in),
        .data_out(data_out),
        .ecc_error(ecc_error)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns clock period

    // Test procedure
    initial begin
        $display("==== Starting Dual Port Memory ECC Testbench ====");
        // Init
        rst_n = 0;
        we = 0;
        addr_a = 0;
        addr_b = 0;
        data_in = 0;
        #20;
        rst_n = 1;
        $display("[%0t ns] Reset complete.", $time);

        // === Test 1: Write and Read back ===
        $display("\n=== Test 1: Write and Read back ===");
        addr_a = 5'd3;
        data_in = 4'b1010;
        we = 1;
        $display("[%0t ns] Writing data 0x%0h to addr_a = %0d", $time, data_in, addr_a);
        #10;
        we = 0;

        addr_b = 5'd3;
        $display("[%0t ns] Reading from addr_b = %0d", $time, addr_b);
        #20;
        $display("[%0t ns] Data out = 0x%0h, ECC error = %0b", $time, data_out, ecc_error);
        if (data_out !== 4'b1010 || ecc_error !== 1'b0) begin
            $display(" FAIL: Data mismatch or unexpected ECC error");
        end else begin
            $display(" PASS: Read data OK, ECC OK");
        end

        // === Test 2: Inject ECC error ===
        $display("\n=== Test 2: Inject ECC error manually ===");
        dut.ram_data[3] = 4'b1011;  // Flip one bit in stored data
        $display("[%0t ns] Manually corrupted RAM at address 3: expected 0xA, now = 0x%0h", $time, dut.ram_data[3]);

        #10;
        addr_b = 5'd3;
        $display("[%0t ns] Reading from corrupted addr_b = %0d", $time, addr_b);
        #20;
        $display("[%0t ns] Data out = 0x%0h, ECC error = %0b", $time, data_out, ecc_error);
        if (ecc_error !== 1'b1) begin
            $display(" FAIL: ECC error not detected on corrupted data");
        end else begin
            $display(" PASS: ECC error correctly detected");
        end

        $display("\n==== All tests completed ====");
        $finish;
    end

endmodule