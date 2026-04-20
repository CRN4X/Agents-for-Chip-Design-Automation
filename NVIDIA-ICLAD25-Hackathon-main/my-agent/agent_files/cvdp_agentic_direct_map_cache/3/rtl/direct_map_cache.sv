module direct_map_cache #(
    parameter CACHE_SIZE = 256,                 // Number of cache lines
    parameter DATA_WIDTH = 16,                  // Width of data
    parameter TAG_WIDTH = 5,                    // Width of the tag
    parameter OFFSET_WIDTH = 3,                 // Width of the offset
    localparam INDEX_WIDTH = $clog2(CACHE_SIZE) // Width of the index
) (
    input wire enable,                          // Enable signal
    input wire [INDEX_WIDTH-1:0] index,         // Cache index
    input wire [OFFSET_WIDTH-1:0] offset,       // Byte offset within the cache line
    input wire comp,                            // Compare operation signal
    input wire write,                           // Write operation signal
    input wire [TAG_WIDTH-1:0] tag_in,          // Input tag for comparison and writing
    input wire [DATA_WIDTH-1:0] data_in,        // Input data to be written
    input wire valid_in,                        // Valid state for cache line
    input wire clk,                             // Clock signal
    input wire rst,                             // Reset signal (active high)
    output reg hit,                             // Hit indication
    output reg dirty,                           // Dirty state indication
    output reg [TAG_WIDTH-1:0] tag_out,         // Output tag of the cache line
    output reg [DATA_WIDTH-1:0] data_out,       // Output data from the cache line
    output reg valid,                           // Valid state output
    output reg error                            // Error indication for invalid accesses
);

    localparam N = 2;

    // 2-way set-associative storage
    reg [TAG_WIDTH-1:0] tags [N-1:0][CACHE_SIZE-1:0];
    reg [DATA_WIDTH-1:0] data_mem [N-1:0][CACHE_SIZE-1:0][OFFSET_WIDTH:0];
    reg valid_bits [N-1:0][CACHE_SIZE-1:0];
    reg dirty_bits [N-1:0][CACHE_SIZE-1:0];
    reg victimway;

    integer i;
    integer w;
    reg hit0;
    reg hit1;

    // Sequential logic for cache operations
    always @(posedge clk) begin
        hit0 = valid_bits[0][index] && (tags[0][index] == tag_in);
        hit1 = valid_bits[1][index] && (tags[1][index] == tag_in);

        if (rst) begin
            // Initialize cache lines on reset
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                for (w = 0; w < N; w = w + 1) begin
                    valid_bits[w][i] <= 1'b0;
                    dirty_bits[w][i] <= 1'b0;
                end
            end
            victimway <= 1'b0;
            hit      <= 1'b0;
            dirty    <= 1'b0;
            tag_out  <= {TAG_WIDTH{1'b0}};
            valid    <= 1'b0;
            data_out <= {DATA_WIDTH{1'b0}};
            error    <= 1'b0;
        end
        else if (enable) begin
            // Check for LSB alignment error
            if (offset[0] == 1'b1) begin
                error <= 1'b1;                               // Set error if LSB of offset is 1
                hit   <= 1'b0;
                dirty <= 1'b0;
                valid <= 1'b0;
                data_out <= {DATA_WIDTH{1'b0}};
            end
            else begin
                error <= 1'b0;                               // Clear error if LSB of offset is 0

                // Compare operation
                if (comp) begin
                    // Compare Write (comp = 1, write = 1)
                    if (write) begin
                        if (hit0) begin
                            hit <= 1'b1;
                            data_mem[0][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                            dirty_bits[0][index] <= 1'b1;
                            valid_bits[0][index] <= valid_in;
                            valid    <= 1'b0;
                            dirty    <= 1'b0;
                        end
                        else if (hit1) begin
                            hit <= 1'b1;
                            data_mem[1][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                            dirty_bits[1][index] <= 1'b1;
                            valid_bits[1][index] <= valid_in;
                            valid    <= 1'b0;
                            dirty    <= 1'b0;
                        end
                        else begin
                            hit <= 1'b0;

                            // Prefer invalid way first; otherwise use victimway.
                            if (!valid_bits[0][index]) begin
                                dirty_bits[0][index] <= 1'b0;
                                valid_bits[0][index] <= valid_in;
                                tags[0][index]       <= tag_in;
                                data_mem[0][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                            end
                            else if (!valid_bits[1][index]) begin
                                dirty_bits[1][index] <= 1'b0;
                                valid_bits[1][index] <= valid_in;
                                tags[1][index]       <= tag_in;
                                data_mem[1][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                            end
                            else if (victimway == 1'b0) begin
                                dirty_bits[0][index] <= 1'b0;
                                valid_bits[0][index] <= valid_in;
                                tags[0][index]       <= tag_in;
                                data_mem[0][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                                victimway <= 1'b1;
                            end
                            else begin
                                dirty_bits[1][index] <= 1'b0;
                                valid_bits[1][index] <= valid_in;
                                tags[1][index]       <= tag_in;
                                data_mem[1][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                                victimway <= 1'b0;
                            end

                            valid <= 1'b0;
                            dirty <= 1'b0;
                        end
                    end
                    else begin // Write
                        // Compare Read (comp = 1, write = 0)
                        if (hit0) begin
                            hit <= 1'b1;
                            data_out <= data_mem[0][index][offset[OFFSET_WIDTH-1:1]];
                            valid    <= valid_bits[0][index];
                            dirty    <= dirty_bits[0][index];
                            tag_out  <= tags[0][index];
                        end
                        else if (hit1) begin
                            hit <= 1'b1;
                            data_out <= data_mem[1][index][offset[OFFSET_WIDTH-1:1]];
                            valid    <= valid_bits[1][index];
                            dirty    <= dirty_bits[1][index];
                            tag_out  <= tags[1][index];
                        end
                        else begin
                            hit <= 1'b0;
                            tag_out  <= tags[0][index];
                            valid    <= valid_bits[0][index];
                            dirty    <= dirty_bits[0][index];
                            data_out <= data_mem[0][index][offset[OFFSET_WIDTH-1:1]];
                        end
                    end
                end
                else begin //compare
                    if (write) begin
                        // Access Write (comp = 0, write = 1)
                        tags[0][index]       <= tag_in;
                        tags[1][index]       <= tag_in;
                        data_mem[0][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                        data_mem[1][index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                        valid_bits[0][index] <= valid_in;
                        valid_bits[1][index] <= valid_in;
                        dirty_bits[0][index] <= 1'b0;
                        dirty_bits[1][index] <= 1'b0;
                        hit      <= 1'b0;
                        valid    <= 1'b0;
                        dirty    <= 1'b0;

                    end
                    else begin
                        // Access Read (comp = 0, write = 0)
                        if (valid_bits[0][index]) begin
                            tag_out  <= tags[0][index];
                            data_out <= data_mem[0][index][offset[OFFSET_WIDTH-1:1]];
                            valid    <= valid_bits[0][index];
                            dirty    <= dirty_bits[0][index];
                            hit      <= 1'b1;
                        end
                        else if (valid_bits[1][index]) begin
                            tag_out  <= tags[1][index];
                            data_out <= data_mem[1][index][offset[OFFSET_WIDTH-1:1]];
                            valid    <= valid_bits[1][index];
                            dirty    <= dirty_bits[1][index];
                            hit      <= 1'b1;
                        end
                        else begin
                            tag_out  <= tags[0][index];
                            data_out <= data_mem[0][index][offset[OFFSET_WIDTH-1:1]];
                            valid    <= 1'b0;
                            dirty    <= 1'b0;
                            hit      <= 1'b0;
                        end

                    end
                end
            end
        end
        else begin // enable
            // enable is low
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                for (w = 0; w < N; w = w + 1) begin
                    valid_bits[w][i] <= 1'b0;
                    dirty_bits[w][i] <= 1'b0;
                end
            end

            hit      <= 1'b0;
            dirty    <= 1'b0;
            tag_out  <= {TAG_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
            valid    <= 1'b0;
        end
    end

endmodule
