`timescale 1ns/1ps

module tb_direct_map_cache;

    parameter CACHE_SIZE   = 256; // Number of cache lines
    parameter DATA_WIDTH   = 16;  // Width of data
    parameter TAG_WIDTH    = 5;   // Width of the tag
    parameter OFFSET_WIDTH = 3;   // Width of the offset
    localparam INDEX_WIDTH = $clog2(CACHE_SIZE); // Width of the index

    reg enable;
    reg [INDEX_WIDTH-1:0] index;
    reg [OFFSET_WIDTH-1:0] offset;
    reg comp;
    reg write;
    reg [TAG_WIDTH-1:0] tag_in;
    reg [DATA_WIDTH-1:0] data_in;
    reg valid_in;
    reg clk;
    reg rst;

    wire hit;
    wire dirty;
    wire [TAG_WIDTH-1:0] tag_out;
    wire [DATA_WIDTH-1:0] data_out;
    wire valid;
    wire error;

    direct_map_cache #(
        .CACHE_SIZE(CACHE_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .OFFSET_WIDTH(OFFSET_WIDTH)
    ) uut (
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

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    reg [INDEX_WIDTH-1:0] stored_index;
    reg [OFFSET_WIDTH-1:0] stored_offset;
    reg [TAG_WIDTH-1:0]    stored_tag;
    reg [DATA_WIDTH-1:0]   stored_data;

    initial begin
        reset();

        // 1) Write operation with comp=0 (Write_Comp0)
        //    We'll do a random write, then read it back with comp=1 expecting a hit
        write_comp0();
        @(negedge clk);

        // 2) Read operation for compare=1 => expect a hit if the same index/tag/offset
        read_comp1();
        @(negedge clk);

        // 3) Write operation for compare=1 => random data, same index/tag to see if dirty is set
        write_comp1();
        @(negedge clk);

        // 4) Read again using compare=1 => should be a hit, check data matches
        read_comp1();
        @(negedge clk);

        // 5) Miss test => choose a new random index to force a miss
        miss_test();
        @(negedge clk);

        // 6) Write again with compare=1 => same index/tag as stored to see if we get a hit
        write_comp1();
        @(negedge clk);

        // 7) Read with compare=0 => different path, check signals
        read_comp0();
        @(negedge clk);

        // 8) Force an error by setting offset’s LSB=1
        //    This should set error=1 and force the design to respond with hit=0, valid=0
        force_offset_error();
        @(negedge clk);

        // Wait a bit and finish
        #50;
        $finish;
    end

    task reset();
        begin
            rst     = 1;
            enable  = 0;
            comp    = 0;
            write   = 0;
            index   = 0;
            offset  = 0;
            tag_in  = 0;
            data_in = 0;
            valid_in= 0;

            @(negedge clk);
            rst = 0;
            @(negedge clk);
            $display("\n[RESET] Completed at time %0t", $time);
        end
    endtask

    // ------------------------------------------------------
    // TASK: WRITE with comp=0
    //       "Access Write (comp=0, write=1)"
    // ------------------------------------------------------
    task write_comp0();
        begin
            enable   = 1;
            comp     = 0;
            write    = 1;
            valid_in = 1'b1;

            stored_index = $random % CACHE_SIZE;
            // Force offset’s LSB=0 so there is no error
            stored_offset = ($random % (1<<OFFSET_WIDTH)) & ~1;
            stored_tag    = $random % (1<<TAG_WIDTH);
            stored_data   = $random % (1<<DATA_WIDTH);

            index   = stored_index;
            offset  = stored_offset;
            tag_in  = stored_tag;
            data_in = stored_data;

            @(negedge clk);
            $display("\n[WRITE_COMP0] @time %0t", $time);
            $display("  -> index=%0d, offset=%0d, tag_in=%b, data_in=%0h", 
                      index, offset, tag_in, data_in);
            $display("  -> comp=%b, write=%b, valid_in=%b", comp, write, valid_in);

            // After a comp=0 write, the design typically sets hit=0.
            // We'll just check that there's no error and that valid is eventually set inside the cache.
            if (error == 1) begin
                $display("  **ERROR** Unexpected error during write_comp0!");
            end
        end
    endtask

    // ------------------------------------------------------
    // TASK: READ with comp=1
    //       "Compare Read (comp=1, write=0)"
    // ------------------------------------------------------
    task read_comp1();
        begin
            comp  = 1;
            write = 0;
            // We re-apply the same stored index/tag to expect a hit
            index   = stored_index;
            offset  = stored_offset;
            tag_in  = stored_tag;

            @(negedge clk);
            $display("\n[READ_COMP1] @time %0t", $time);
            $display("  -> index=%0d, offset=%0d, tag_in=%b, data_out=%0h, valid=%b, hit=%b",
                     index, offset, tag_in, data_out, valid, hit);

            // Check if we got a hit, valid line, and correct data
            if (hit && valid && (data_out == stored_data)) begin
                $display("  PASS: Expected read hit and correct data.");
            end else begin
                $display("  FAIL: Expected a read hit or data mismatch!");
            end

            // Also check that 'error' is 0
            if (error == 1) begin
                $display("  **ERROR** Unexpected error during read_comp1!");
            end
        end
    endtask

    // ------------------------------------------------------
    // TASK: WRITE with comp=1
    //       "Compare Write (comp=1, write=1)"
    //       - If the same tag/index is used, line should go dirty.
    // ------------------------------------------------------
    task write_comp1();
        begin
            comp   = 1;
            write  = 1;
            enable = 1;
            valid_in = 1'b1;

            // Keep the same stored_index, stored_tag to see if we get a "hit"
            // but randomize data again
            index   = stored_index;
            offset  = stored_offset;
            tag_in  = stored_tag;
            stored_data = $random % (1<<DATA_WIDTH);
            data_in = stored_data;

            @(negedge clk);
            $display("\n[WRITE_COMP1] @time %0t", $time);
            $display("  -> index=%0d, offset=%0d, tag_in=%b, data_in=%0h, comp=%b, write=%b",
                     index, offset, tag_in, data_in, comp, write);

            // If the tag matches and valid was set, we should see a hit and the line become dirty.
            if (hit == 1 && valid == 1) begin
                $display("  => Compare write was a hit. Checking dirty bit...");
                if (dirty == 1) begin
                    $display("  PASS: dirty=1 as expected for Compare Write on an existing line.");
                end else begin
                    $display("  FAIL: dirty bit not set, unexpected!");
                end
            end
            else begin
                $display("  => Compare write was a miss or invalid line. The line is newly allocated.");
                // Possibly the line's dirty bit is reset to 0 in a real design, 
                // or it might be set depending on policy. Check your DUT logic.
            end
        end
    endtask

    // ------------------------------------------------------
    // TASK: READ with comp=0
    //       "Access Read (comp=0, write=0)"
    // ------------------------------------------------------
    task read_comp0();
        begin
            comp  = 0;
            write = 0;
            // We'll continue using the same stored index/tag
            index   = stored_index;
            offset  = stored_offset;
            tag_in  = stored_tag;

            @(negedge clk);
            $display("\n[READ_COMP0] @time %0t", $time);
            $display("  -> index=%0d, offset=%0d, tag_in=%b, data_out=%0h, valid=%b, hit=%b", 
                     index, offset, tag_in, data_out, valid, hit);

            // Typically comp=0 read does not check tag => hit=0 in the given code
            // We'll confirm there's no error
            if (error == 1) begin
                $display("  **ERROR** Unexpected error during read_comp0!");
            end
        end
    endtask

    // ------------------------------------------------------
    // TASK: MISS TEST
    //       Force a different index or tag so we get a miss.
    // ------------------------------------------------------
    task miss_test();
        reg [INDEX_WIDTH-1:0] new_index;
        begin
            comp  = 1;
            write = 0;
            enable = 1;

            // Force a new index to differ from stored_index so we get a guaranteed miss
            new_index = (stored_index + 1) % CACHE_SIZE;
            index = new_index;
            // Keep offset’s LSB=0 to avoid error
            offset = ($random % (1<<OFFSET_WIDTH)) & ~1;
            // We can reuse stored_tag or randomize it
            tag_in = $random % (1<<TAG_WIDTH);

            @(negedge clk);
            $display("\n[MISS_TEST] @time %0t", $time);
            $display("  -> new_index=%0d, offset=%0d, tag_in=%b, data_out=%0h, valid=%b, hit=%b",
                     new_index, offset, tag_in, data_out, valid, hit);

            if (!hit) begin
                $display("  PASS: Expected MISS, got hit=0");
            end else begin
                $display("  FAIL: Unexpected hit=1, was supposed to be a miss!");
            end

            // Also check there's no unexpected error
            if (error == 1) begin
                $display("  **ERROR** Unexpected error during miss_test!");
            end
        end
    endtask

    // ------------------------------------------------------
    // TASK: Force offset’s LSB=1 to generate an ERROR
    // ------------------------------------------------------
    task force_offset_error();
        begin
            $display("\n[OFFSET_ERROR_TEST] Forcing offset LSB=1, expecting 'error=1'.");
            offset = 3'b001; // LSB=1
            // Keep any values for comp/write
            comp   = 0; 
            write  = 0;
            index  = 0;
            tag_in = 0;
            data_in= 0;
            @(negedge clk);

            if (error == 1) begin
                $display("  PASS: 'error' asserted as expected when offset LSB=1.");
            end else begin
                $display("  FAIL: 'error' did not assert with offset LSB=1!");
            end
        end
    endtask

    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0, tb_direct_map_cache);
    end

endmodule