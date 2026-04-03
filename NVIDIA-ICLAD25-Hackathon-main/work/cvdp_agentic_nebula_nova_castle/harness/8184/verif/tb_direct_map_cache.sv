`timescale 1ns/1ps

module tb_direct_map_cache;

    // Parameters
    parameter CACHE_SIZE = 256;               // Number of cache lines
    parameter DATA_WIDTH = 16;                // Width of data
    parameter TAG_WIDTH = 5;                  // Width of the tag
    parameter OFFSET_WIDTH = 3;               // Width of the offset

    // Inputs
    reg enable;                               // Enable signal for cache
    reg [7:0] index;                          // 8 bits for indexing into the cache
    reg [OFFSET_WIDTH-1:0] offset;            // 3 bits for offset
    reg comp;                                 // Compare signal
    reg write;                                // Write signal
    reg [TAG_WIDTH-1:0] tag_in;               // Tag input
    reg [DATA_WIDTH-1:0] data_in;             // Data input
    reg valid_in;                             // Valid input for cache line
    reg clk;                                  // Clock signal
    reg rst;                                  // Reset signal
    reg [DATA_WIDTH-1:0] data;                // Data variable for tasks

    // Outputs
    wire hit;                                 // Hit indication
    wire dirty;                               // Dirty state indication
    wire [TAG_WIDTH-1:0] tag_out;             // Output tag of the cache line
    wire [DATA_WIDTH-1:0] data_out;           // Output data from the cache line
    wire valid;                               // Valid state output
    wire error;                               // Error indication

    integer i;                                

    // Instantiate the cache
    direct_map_cache #(
                                    .CACHE_SIZE(CACHE_SIZE),
                                    .DATA_WIDTH(DATA_WIDTH),
                                    .TAG_WIDTH(TAG_WIDTH),
                                    .OFFSET_WIDTH(OFFSET_WIDTH)
                                   )
			                   uut (
                                    .enable(enable),
                                    .index(index),
                                    .offset(offset),
                                    .comp(comp),
                                    .write(write),
                                    .tag_in(tag_in),
                                    .data_in(data_in),
                                    .valid_in(valid_in),
                                    .clk(clk),
                                    .rst(rst),
                                    .hit(hit),
                                    .dirty(dirty),
                                    .tag_out(tag_out),
                                    .data_out(data_out),
                                    .valid(valid),
                                    .error(error)
                                   );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10 ns period
    end

    // Test procedure
    initial begin
        // Initialize inputs
        enable = 0;
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk); 

        // Enable cache
        enable = 1;
        // Pseudo-Random Replacement Condition Checking
        // Fill the cache to trigger replacement
        write_task(8'h02, 3'b000, 5'b00000, 1'b1,1'b1);
        read_task(8'h02, 3'b000, 5'b00000, 1'b1);
        write_task(8'h02, 3'b000, 5'b00001, 1'b1,1'b1);
        read_task(8'h02, 3'b000, 5'b00001, 1'b1);
        write_task(8'h02, 3'b000, 5'b00010, 1'b1,1'b1);
        read_task(8'h02, 3'b000, 5'b00010, 1'b1);
        write_task(8'h02, 3'b000, 5'b00011, 1'b1,1'b1);
        read_task(8'h02, 3'b000, 5'b00011, 1'b1);

        @(posedge clk); 

        // Write to cache without compare
        write_task(8'h00, 3'b000, 5'b00001, 1'b0,1'b1);

	    // Read from cache without compare
        read_task(8'h00, 3'b000, 5'b00001, 1'b0);

        // Write to cache with compare
        write_task(8'h00, 3'b000, 5'b00001, 1'b1,1'b1);

        // Read from cache  with compare
        read_task(8'h00, 3'b000, 5'b00001, 1'b1);

        // Write to cache with out compare 
        write_task(8'h01, 3'b110, 5'b00010, 1'b0,1'b1);

        // Read from cache  with compare
        read_task(8'h01, 3'b110, 5'b00010, 1'b1);

        // Error condition
        write_task(8'h01, 3'b001, 5'b00010, 1'b0,1'b1);      
        @(posedge clk); 
        check_error(3'b001, error);
        // Finalize simulation
        $finish;
    end

    // Task to handle writing to the cache
    task write_task(input [7:0] indx, input [2:0] off, input [4:0] tag, input compr, valid);
        begin
            index = indx;  
            offset = off; 
            tag_in = tag; 
            data_in = $random; 
            valid_in = valid;    
            write = 1'b1;       
            comp = compr; 
            @(posedge clk); 

             // Display after the clock
            $display("\n[WRITE_TASK] @time %0t", $time);
            $display("  -> index=%0d (0x%0h), offset=%0d (0x%0h), tag_in=%b, data_in=%0h",
                      index, index, offset, offset, tag_in, data_in);
            $display("  -> comp=%b, write=%b, valid_in=%b", comp, write, valid_in);
            $display("  -> hit=%b, dirty=%b, tag_out=%b, data_out=%0h, valid=%b, error=%b",
                      hit, dirty, tag_out, data_out, valid, error);
        end
    endtask 

    // Task to handle reading from the cache
    task read_task(input [7:0] indx, input [2:0] off, input [4:0] tag, input compr);
        begin
            index = indx;  
            offset = off; 
            tag_in = tag; 
            comp = compr;
            @(posedge clk);        
            write = 1'b0;
            @(posedge clk);
        
            $display("\n[READ_TASK] @time %0t", $time);
            $display("  -> index=%0d (0x%0h), offset=%0d (0x%0h), tag_in=%b",
                      index, index, offset, offset, tag_in);
            $display("  -> comp=%b, write=%b", comp, write);
            $display("  -> hit=%b, dirty=%b, tag_out=%b, data_out=%0h, valid=%b, error=%b",
                      hit, dirty, tag_out, data_out, valid, error);


            if (data_in !== data_out)
                $display("  -> [Error] Data mismatch! data_in=%0h, data_out=%0h",
                          data_in, data_out);
            else
                $display("  -> [Pass] Data matched.");
            @(posedge clk); 
        end
    endtask

    task check_error(input [2:0] offset_val, input error_signal);
        begin
            if (offset_val[0]) begin
                if (error_signal)
                    $display("  -> [PASS] ERROR correctly asserted for misaligned offset (offset[0]=1)");
                else
                    $display("  -> [FAIL] ERROR was expected for misaligned offset, but not asserted!");
                end else begin
                if (error_signal)
                    $display("  -> [FAIL] ERROR was unexpectedly asserted on aligned offset (offset[0]=0)");
                else
                    $display("  -> [PASS] No error as expected (aligned offset)");
            end
        end
    endtask

    // Waveform dumping for simulation analysis
    initial begin
        $dumpfile("direct_map_cachet.vcd");    // Specify the VCD file for waveform dumping
        $dumpvars(0, tb_direct_map_cache);     // Dump all variables in the testbench
    end
endmodule