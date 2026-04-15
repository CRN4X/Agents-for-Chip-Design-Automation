`timescale 1ns / 1ps

module tb_swizzler;

parameter NUM_LANES = 4;
parameter DATA_WIDTH = 8;
parameter REGISTER_OUTPUT = 0;
parameter ENABLE_PARITY_CHECK = 1;

reg clk;
reg rst_n;
reg bypass;
reg [NUM_LANES*DATA_WIDTH-1:0] data_in;
reg [NUM_LANES*$clog2(NUM_LANES)-1:0] swizzle_map_flat;
wire [NUM_LANES*DATA_WIDTH-1:0] data_out;
wire parity_error;

swizzler #(
    .NUM_LANES(NUM_LANES),
    .DATA_WIDTH(DATA_WIDTH),
    .REGISTER_OUTPUT(REGISTER_OUTPUT),
    .ENABLE_PARITY_CHECK(ENABLE_PARITY_CHECK)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .bypass(bypass),
    .data_in(data_in),
    .swizzle_map_flat(swizzle_map_flat),
    .data_out(data_out),
    .parity_error(parity_error)
);

logic [DATA_WIDTH-1:0] input_lanes [NUM_LANES-1:0];
logic [DATA_WIDTH-1:0] expected_lanes [NUM_LANES-1:0];
logic [DATA_WIDTH-1:0] output_lanes [NUM_LANES-1:0];
logic [$clog2(NUM_LANES)-1:0] swizzle_map [NUM_LANES-1:0];

integer i;

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    bypass = 0;
    data_in = 0;
    swizzle_map_flat = 0;
    #15;
    rst_n = 1;

    test_bypass();
    test_identity();
    test_reverse();
    test_custom();

    $display("All tests completed.");
    $finish;
end

task test_bypass;
    $display("Test Case: Bypass Mode");
    bypass = 1;
    for (i = 0; i < NUM_LANES; i++) begin
        input_lanes[i] = i + 1;
    end
    flatten_input();
    @(posedge clk);
    @(posedge clk);
    unpack_output();
    for (i = 0; i < NUM_LANES; i++) begin
        expected_lanes[i] = input_lanes[i];
    end
    check_output("Bypass");
endtask

task test_identity;
    $display("Test Case: Identity Mapping");
    bypass = 0;
    for (i = 0; i < NUM_LANES; i++) begin
        swizzle_map[i] = i;
        input_lanes[i] = i + 10;
    end
    flatten_swizzle_map();
    flatten_input();
    @(posedge clk);
    @(posedge clk);
    unpack_output();
    for (i = 0; i < NUM_LANES; i++) begin
        expected_lanes[i] = input_lanes[i];
    end
    check_output("Identity");
endtask

task test_reverse;
    $display("Test Case: Reverse Mapping");
    bypass = 0;
    for (i = 0; i < NUM_LANES; i++) begin
        swizzle_map[i] = NUM_LANES - 1 - i;
        input_lanes[i] = i + 20;
    end
    flatten_swizzle_map();
    flatten_input();
    @(posedge clk);
    @(posedge clk);
    unpack_output();
    for (i = 0; i < NUM_LANES; i++) begin
        expected_lanes[i] = input_lanes[NUM_LANES - 1 - i];
    end
    check_output("Reverse");
endtask

task test_custom;
    $display("Test Case: Custom Mapping");
    bypass = 0;
    swizzle_map[0] = 2;
    swizzle_map[1] = 0;
    swizzle_map[2] = 3;
    swizzle_map[3] = 1;
    input_lanes[0] = 8'hAA;
    input_lanes[1] = 8'hBB;
    input_lanes[2] = 8'hCC;
    input_lanes[3] = 8'hDD;
    flatten_swizzle_map();
    flatten_input();
    @(posedge clk);
    @(posedge clk);
    unpack_output();
    expected_lanes[0] = input_lanes[2];
    expected_lanes[1] = input_lanes[0];
    expected_lanes[2] = input_lanes[3];
    expected_lanes[3] = input_lanes[1];
    check_output("Custom");
endtask

task flatten_input;
    for (i = 0; i < NUM_LANES; i++) begin
        data_in[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = input_lanes[i];
    end
endtask

task flatten_swizzle_map;
    for (i = 0; i < NUM_LANES; i++) begin
        swizzle_map_flat[(i+1)*$clog2(NUM_LANES)-1 -: $clog2(NUM_LANES)] = swizzle_map[i];
    end
endtask

task unpack_output;
    for (i = 0; i < NUM_LANES; i++) begin
        output_lanes[i] = data_out[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    end
endtask

task check_output(input string test_name);
    for (i = 0; i < NUM_LANES; i++) begin
        if (output_lanes[i] !== expected_lanes[i]) begin
            $display("[%s] ERROR: Lane %0d: Expected %h, Got %h", test_name, i, expected_lanes[i], output_lanes[i]);
        end else begin
            $display("[%s] PASS: Lane %0d = %h", test_name, i, output_lanes[i]);
        end
    end
    if (ENABLE_PARITY_CHECK) begin
        if (parity_error) begin
            $display("[%s] PARITY ERROR DETECTED", test_name);
        end else begin
            $display("[%s] Parity check passed", test_name);
        end
    end
endtask

endmodule