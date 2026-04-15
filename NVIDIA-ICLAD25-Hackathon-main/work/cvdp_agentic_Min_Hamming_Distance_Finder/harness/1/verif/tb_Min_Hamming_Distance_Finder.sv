`timescale 1ns / 1ps

module tb_Min_Hamming_Distance_Finder;

    // Parameters for the testbench
    parameter BIT_WIDTH = 8;
    parameter REFERENCE_COUNT = 4;

    // Testbench signals
    reg  [BIT_WIDTH-1:0]                      input_query;
    reg  [REFERENCE_COUNT*BIT_WIDTH-1:0]      references;
    wire [$clog2(REFERENCE_COUNT)-1:0]        best_match_index;
    wire [$clog2(BIT_WIDTH+1)-1:0]            min_distance;

    // Instantiate the DUT
    Min_Hamming_Distance_Finder #(
        .BIT_WIDTH(BIT_WIDTH),
        .REFERENCE_COUNT(REFERENCE_COUNT)
    ) dut (
        .input_query(input_query),
        .references(references),
        .best_match_index(best_match_index),
        .min_distance(min_distance)
    );

    // Function to compute Hamming distance (popcount) between two vectors
    function [$clog2(BIT_WIDTH+1)-1:0] compute_expected_difference;
        input [BIT_WIDTH-1:0] data_A;
        input [BIT_WIDTH-1:0] data_B;
        integer i;
        reg [BIT_WIDTH-1:0] xor_result;
        reg [$clog2(BIT_WIDTH+1)-1:0] pop_count;
        begin
            xor_result = data_A ^ data_B;
            pop_count = 0;
            for (i = 0; i < BIT_WIDTH; i = i + 1) begin
                pop_count = pop_count + xor_result[i];
            end
            compute_expected_difference = pop_count;
        end
    endfunction

    // Task to compute expected best match index and minimum Hamming distance
    task compute_expected_results(
        input  [BIT_WIDTH-1:0] query,
        input  [REFERENCE_COUNT*BIT_WIDTH-1:0] refs,
        output integer expected_index,
        output integer expected_distance
    );
        integer i;
        integer curr_distance;
        reg [BIT_WIDTH-1:0] ref_vector;
        begin
            expected_distance = BIT_WIDTH + 1; // initialize with a max value
            expected_index = 0;
            for (i = 0; i < REFERENCE_COUNT; i = i + 1) begin
                // Extract the i-th reference vector using part-select
                ref_vector = refs[i*BIT_WIDTH +: BIT_WIDTH];
                curr_distance = compute_expected_difference(query, ref_vector);
                if (curr_distance < expected_distance) begin
                    expected_distance = curr_distance;
                    expected_index = i;
                end
            end
        end
    endtask

    // Coverage tracking
    integer total_tests = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;

    // Task to validate the output of the Min_Hamming_Distance_Finder
    task validate_output(
        input [BIT_WIDTH-1:0] test_query,
        input [REFERENCE_COUNT*BIT_WIDTH-1:0] test_references,
        input string testcase_name
    );
        integer exp_index, exp_distance;
        begin
            input_query = test_query;
            references  = test_references;
            #10; // Wait for combinational logic to settle

            total_tests += 1;
            compute_expected_results(test_query, test_references, exp_index, exp_distance);

            if ((best_match_index === exp_index) && (min_distance === exp_distance)) begin
                passed_tests += 1;
                $display("[PASS] %s: Query=%b, Refs=%b -> Expected: index=%0d, dist=%0d; Got: index=%0d, dist=%0d",
                         testcase_name, test_query, test_references, exp_index, exp_distance, best_match_index, min_distance);
            end else begin
                failed_tests += 1;
                $error("[FAIL] %s: Query=%b, Refs=%b -> Expected: index=%0d, dist=%0d; Got: index=%0d, dist=%0d",
                         testcase_name, test_query, test_references, exp_index, exp_distance, best_match_index, min_distance);
            end
        end
    endtask

    // Task for testing specific edge cases
    task test_edge_cases;
        reg [BIT_WIDTH-1:0] ref_vector;
        reg [REFERENCE_COUNT*BIT_WIDTH-1:0] refs_temp;
        integer i;
        begin
            $display("Starting Edge Case Testing...");

            // Case 1: All references equal to input_query (zero distance)
            ref_vector = 8'b10101010;
            for (i = 0; i < REFERENCE_COUNT; i = i + 1) begin
                refs_temp[i*BIT_WIDTH +: BIT_WIDTH] = ref_vector;
            end
            validate_output(ref_vector, refs_temp, "All references equal to query");

            // Case 2: One reference is an exact match and others are completely different.
            input_query = 8'b11110000;
            // Set reference 0 to be completely different, reference 1 slightly different, reference 2 exact match, reference 3 different.
            refs_temp = {8'b00000000, 8'b11100000, 8'b11110000, 8'b10101010};
            validate_output(input_query, refs_temp, "Exact match among others");

            // Case 3: Test when the first reference is the closest
            input_query = 8'b01010101;
            refs_temp = {8'b01010100, 8'b10101010, 8'b11110000, 8'b00001111};
            validate_output(input_query, refs_temp, "First reference is closest");
        end
    endtask

    // Task for testing random inputs
    task test_random_inputs;
        integer i;
        reg [BIT_WIDTH-1:0] random_query;
        reg [REFERENCE_COUNT*BIT_WIDTH-1:0] random_refs;
        begin
            $display("Starting Randomized Testing...");
            for (i = 0; i < 100; i = i + 1) begin
                random_query = $urandom;
                random_refs  = $urandom;
                validate_output(random_query, random_refs, $sformatf("Random Test %0d", i+1));
            end
        end
    endtask

    // Task to print the summary
    task print_summary;
        begin
            $display("=================================================");
            $display("Test Summary:");
            $display("Total Tests Run: %0d", total_tests);
            $display("Tests Passed   : %0d", passed_tests);
            $display("Tests Failed   : %0d", failed_tests);
            $display("=================================================");
            if (failed_tests > 0)
                $error("Some tests failed. Check the logs for details.");
            else
                $display("All tests passed successfully!");
        end
    endtask

    initial begin
        $display("Starting testbench for Min_Hamming_Distance_Finder...");
        test_edge_cases();
        test_random_inputs();
        print_summary();
        $finish;
    end

endmodule