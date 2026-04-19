module direct_map_cache #(
    parameter CACHE_SIZE = 256,
    parameter DATA_WIDTH = 16,
    parameter TAG_WIDTH = 5,
    parameter OFFSET_WIDTH = 3,
    localparam INDEX_WIDTH = $clog2(CACHE_SIZE)
) (
    input wire enable,
    input wire [INDEX_WIDTH-1:0] index,
    input wire [OFFSET_WIDTH-1:0] offset,
    input wire comp,
    input wire write,
    input wire [TAG_WIDTH-1:0] tag_in,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire valid_in,
    input wire clk,
    input wire rst,
    output reg hit,
    output reg dirty,
    output reg [TAG_WIDTH-1:0] tag_out,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg valid,
    output reg error
);

    localparam N = 2;
    localparam WORDS_PER_LINE = (1 << (OFFSET_WIDTH-1));

    reg [TAG_WIDTH-1:0] tags [N-1:0][CACHE_SIZE-1:0];
    reg [DATA_WIDTH-1:0] data_mem [N-1:0][CACHE_SIZE-1:0][WORDS_PER_LINE-1:0];
    reg valid_bits [N-1:0][CACHE_SIZE-1:0];
    reg dirty_bits [N-1:0][CACHE_SIZE-1:0];

    // Required internal replacement selector for 2-way miss handling.
    reg victimway;

    wire [OFFSET_WIDTH-2:0] word_index;
    reg hit0, hit1;
    reg sel_way;

    integer i;

    assign word_index = offset[OFFSET_WIDTH-1:1];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                valid_bits[0][i] <= 1'b0;
                valid_bits[1][i] <= 1'b0;
                dirty_bits[0][i] <= 1'b0;
                dirty_bits[1][i] <= 1'b0;
            end
            victimway <= 1'b0;
            hit <= 1'b0;
            dirty <= 1'b0;
            tag_out <= {TAG_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
            valid <= 1'b0;
            error <= 1'b0;
        end else if (enable) begin
            if (offset[0]) begin
                error <= 1'b1;
                hit <= 1'b0;
                dirty <= 1'b0;
                tag_out <= {TAG_WIDTH{1'b0}};
                data_out <= {DATA_WIDTH{1'b0}};
                valid <= 1'b0;
            end else begin
                error <= 1'b0;

                hit0 = valid_bits[0][index] && (tags[0][index] == tag_in);
                hit1 = valid_bits[1][index] && (tags[1][index] == tag_in);

                // For misses with both ways valid, use round-robin victim.
                if (hit0) begin
                    sel_way = 1'b0;
                end else if (hit1) begin
                    sel_way = 1'b1;
                end else if (!valid_bits[0][index]) begin
                    sel_way = 1'b0;
                end else if (!valid_bits[1][index]) begin
                    sel_way = 1'b1;
                end else begin
                    sel_way = victimway;
                end

                if (comp) begin
                    if (write) begin
                        if (hit0 || hit1) begin
                            hit <= 1'b1;
                            data_mem[sel_way][index][word_index] <= data_in;
                            valid_bits[sel_way][index] <= valid_in;
                            dirty_bits[sel_way][index] <= 1'b1;
                            tag_out <= tags[sel_way][index];
                            data_out <= data_in;
                            valid <= 1'b0;
                            dirty <= 1'b0;
                        end else begin
                            hit <= 1'b0;
                            tags[sel_way][index] <= tag_in;
                            data_mem[sel_way][index][word_index] <= data_in;
                            valid_bits[sel_way][index] <= valid_in;
                            dirty_bits[sel_way][index] <= 1'b0;
                            tag_out <= tag_in;
                            data_out <= data_in;
                            valid <= 1'b0;
                            dirty <= 1'b0;
                            if (valid_bits[0][index] && valid_bits[1][index]) begin
                                victimway <= ~victimway;
                            end
                        end
                    end else begin
                        if (hit0 || hit1) begin
                            hit <= 1'b1;
                            tag_out <= tags[sel_way][index];
                            data_out <= data_mem[sel_way][index][word_index];
                            valid <= valid_bits[sel_way][index];
                            dirty <= dirty_bits[sel_way][index];
                        end else begin
                            hit <= 1'b0;
                            tag_out <= tags[sel_way][index];
                            data_out <= data_mem[sel_way][index][word_index];
                            valid <= valid_bits[sel_way][index];
                            dirty <= dirty_bits[sel_way][index];
                        end
                    end
                end else begin
                    if (write) begin
                        tags[0][index] <= tag_in;
                        tags[1][index] <= tag_in;
                        data_mem[0][index][word_index] <= data_in;
                        data_mem[1][index][word_index] <= data_in;
                        valid_bits[0][index] <= valid_in;
                        valid_bits[1][index] <= valid_in;
                        dirty_bits[0][index] <= 1'b0;
                        dirty_bits[1][index] <= 1'b0;
                        hit <= 1'b0;
                        dirty <= 1'b0;
                        tag_out <= tag_in;
                        data_out <= data_in;
                        valid <= 1'b0;
                    end else begin
                        // Access-read returns selected way data and reports hit on valid entry.
                        tag_out <= tags[sel_way][index];
                        data_out <= data_mem[sel_way][index][word_index];
                        valid <= valid_bits[sel_way][index];
                        dirty <= dirty_bits[sel_way][index];
                        hit <= valid_bits[sel_way][index];
                    end
                end
            end
        end else begin
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                valid_bits[0][i] <= 1'b0;
                valid_bits[1][i] <= 1'b0;
                dirty_bits[0][i] <= 1'b0;
                dirty_bits[1][i] <= 1'b0;
            end
            hit <= 1'b0;
            dirty <= 1'b0;
            tag_out <= {TAG_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
            valid <= 1'b0;
            error <= 1'b0;
        end
    end

endmodule
