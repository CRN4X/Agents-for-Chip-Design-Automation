`timescale 1ns/1ns

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
    localparam WORD_INDEX_WIDTH = (OFFSET_WIDTH > 1) ? (OFFSET_WIDTH - 1) : 1;
    localparam WORDS_PER_LINE = (1 << WORD_INDEX_WIDTH);

    reg [TAG_WIDTH-1:0] tags [0:N-1][0:CACHE_SIZE-1];
    reg [DATA_WIDTH-1:0] data_mem [0:N-1][0:CACHE_SIZE-1][0:WORDS_PER_LINE-1];
    reg valid_bits [0:N-1][0:CACHE_SIZE-1];
    reg dirty_bits [0:N-1][0:CACHE_SIZE-1];

    reg victimway;
    wire [WORD_INDEX_WIDTH-1:0] word_index;
    wire hit0;
    wire hit1;

    integer i;
    integer j;

    assign word_index = offset[OFFSET_WIDTH-1:1];
    assign hit0 = valid_bits[0][index] && (tags[0][index] == tag_in);
    assign hit1 = valid_bits[1][index] && (tags[1][index] == tag_in);

    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < N; j = j + 1) begin
                for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                    valid_bits[j][i] <= 1'b0;
                    dirty_bits[j][i] <= 1'b0;
                end
            end
            victimway <= 1'b0;
            hit <= 1'b0;
            dirty <= 1'b0;
            tag_out <= {TAG_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
            valid <= 1'b0;
            error <= 1'b0;
        end else if (!enable) begin
            hit <= 1'b0;
            dirty <= 1'b0;
            tag_out <= {TAG_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
            valid <= 1'b0;
            error <= 1'b0;
        end else if (offset[0]) begin
            error <= 1'b1;
            hit <= 1'b0;
            dirty <= 1'b0;
            tag_out <= {TAG_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
            valid <= 1'b0;
        end else begin
            error <= 1'b0;

            if (comp && write) begin
                if (hit0) begin
                    hit <= 1'b1;
                    data_mem[0][index][word_index] <= data_in;
                    valid_bits[0][index] <= valid_in;
                    dirty_bits[0][index] <= 1'b1;
                    tag_out <= tags[0][index];
                    data_out <= data_in;
                    valid <= valid_in;
                    dirty <= 1'b1;
                end else if (hit1) begin
                    hit <= 1'b1;
                    data_mem[1][index][word_index] <= data_in;
                    valid_bits[1][index] <= valid_in;
                    dirty_bits[1][index] <= 1'b1;
                    tag_out <= tags[1][index];
                    data_out <= data_in;
                    valid <= valid_in;
                    dirty <= 1'b1;
                end else begin
                    hit <= 1'b0;
                    if (!valid_bits[0][index]) begin
                        tags[0][index] <= tag_in;
                        data_mem[0][index][word_index] <= data_in;
                        valid_bits[0][index] <= valid_in;
                        dirty_bits[0][index] <= 1'b0;
                    end else if (!valid_bits[1][index]) begin
                        tags[1][index] <= tag_in;
                        data_mem[1][index][word_index] <= data_in;
                        valid_bits[1][index] <= valid_in;
                        dirty_bits[1][index] <= 1'b0;
                    end else if (victimway == 1'b0) begin
                        tags[0][index] <= tag_in;
                        data_mem[0][index][word_index] <= data_in;
                        valid_bits[0][index] <= valid_in;
                        dirty_bits[0][index] <= 1'b0;
                        victimway <= 1'b1;
                    end else begin
                        tags[1][index] <= tag_in;
                        data_mem[1][index][word_index] <= data_in;
                        valid_bits[1][index] <= valid_in;
                        dirty_bits[1][index] <= 1'b0;
                        victimway <= 1'b0;
                    end
                    tag_out <= tag_in;
                    data_out <= data_in;
                    valid <= valid_in;
                    dirty <= 1'b0;
                end
            end else if (comp && !write) begin
                if (hit0) begin
                    hit <= 1'b1;
                    tag_out <= tags[0][index];
                    data_out <= data_mem[0][index][word_index];
                    valid <= valid_bits[0][index];
                    dirty <= dirty_bits[0][index];
                end else if (hit1) begin
                    hit <= 1'b1;
                    tag_out <= tags[1][index];
                    data_out <= data_mem[1][index][word_index];
                    valid <= valid_bits[1][index];
                    dirty <= dirty_bits[1][index];
                end else begin
                    hit <= 1'b0;
                    tag_out <= tags[0][index];
                    data_out <= data_mem[0][index][word_index];
                    valid <= valid_bits[0][index];
                    dirty <= dirty_bits[0][index];
                end
            end else if (!comp && write) begin
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
                valid <= valid_in;
            end else begin
                if (hit0) begin
                    hit <= 1'b1;
                    tag_out <= tags[0][index];
                    data_out <= data_mem[0][index][word_index];
                    valid <= valid_bits[0][index];
                    dirty <= dirty_bits[0][index];
                end else if (hit1) begin
                    hit <= 1'b1;
                    tag_out <= tags[1][index];
                    data_out <= data_mem[1][index][word_index];
                    valid <= valid_bits[1][index];
                    dirty <= dirty_bits[1][index];
                end else begin
                    hit <= 1'b0;
                    tag_out <= tags[0][index];
                    data_out <= data_mem[0][index][word_index];
                    valid <= valid_bits[0][index];
                    dirty <= dirty_bits[0][index];
                end
            end
        end
    end

endmodule
