`timescale 1ns/1ps

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

    wire hit0;
    wire hit1;
    reg selected_way;
    reg replace_way;
    wire [WORD_INDEX_WIDTH-1:0] word_index;

    integer i;
    integer j;
    integer k;

    generate
        if (OFFSET_WIDTH > 1) begin : gen_word_index
            assign word_index = offset[OFFSET_WIDTH-1:1];
        end else begin : gen_word_index_default
            assign word_index = {WORD_INDEX_WIDTH{1'b0}};
        end
    endgenerate

    assign hit0 = valid_bits[0][index] && (tags[0][index] == tag_in);
    assign hit1 = valid_bits[1][index] && (tags[1][index] == tag_in);

    always @(*) begin
        selected_way = 1'b0;
        if (!valid_bits[0][index] && valid_bits[1][index]) begin
            selected_way = 1'b1;
        end
        if (hit1 && !hit0) begin
            selected_way = 1'b1;
        end

        replace_way = 1'b0;
        if (!valid_bits[0][index]) begin
            replace_way = 1'b0;
        end else if (!valid_bits[1][index]) begin
            replace_way = 1'b1;
        end else begin
            replace_way = victimway;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < N; j = j + 1) begin
                for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                    tags[j][i] <= {TAG_WIDTH{1'b0}};
                    valid_bits[j][i] <= 1'b0;
                    dirty_bits[j][i] <= 1'b0;
                    for (k = 0; k < WORDS_PER_LINE; k = k + 1) begin
                        data_mem[j][i][k] <= {DATA_WIDTH{1'b0}};
                    end
                end
            end

            victimway <= 1'b0;
            hit = 1'b0;
            dirty = 1'b0;
            tag_out = {TAG_WIDTH{1'b0}};
            data_out = {DATA_WIDTH{1'b0}};
            valid = 1'b0;
            error = 1'b0;
        end else if (enable) begin
            if (offset[0] == 1'b1) begin
                error = 1'b1;
                hit = 1'b0;
                dirty = 1'b0;
                tag_out = {TAG_WIDTH{1'b0}};
                data_out = {DATA_WIDTH{1'b0}};
                valid = 1'b0;
            end else begin
                error = 1'b0;

                if (comp) begin
                    if (write) begin
                        if (hit0 || hit1) begin
                            if (hit1 && !hit0) begin
                                data_mem[1][index][word_index] <= data_in;
                                dirty_bits[1][index] <= 1'b1;
                                valid_bits[1][index] <= valid_in;
                                tag_out = tags[1][index];
                            end else begin
                                data_mem[0][index][word_index] <= data_in;
                                dirty_bits[0][index] <= 1'b1;
                                valid_bits[0][index] <= valid_in;
                                tag_out = tags[0][index];
                            end
                            hit = 1'b1;
                            dirty = 1'b1;
                            data_out = data_in;
                            valid = valid_in;
                        end else begin
                            if (replace_way) begin
                                tags[1][index] <= tag_in;
                                data_mem[1][index][word_index] <= data_in;
                                valid_bits[1][index] <= valid_in;
                                dirty_bits[1][index] <= 1'b0;
                            end else begin
                                tags[0][index] <= tag_in;
                                data_mem[0][index][word_index] <= data_in;
                                valid_bits[0][index] <= valid_in;
                                dirty_bits[0][index] <= 1'b0;
                            end

                            if (valid_bits[0][index] && valid_bits[1][index]) begin
                                victimway <= ~victimway;
                            end

                            hit = 1'b0;
                            dirty = 1'b0;
                            tag_out = tag_in;
                            data_out = data_in;
                            valid = valid_in;
                        end
                    end else begin
                        if (hit0 || hit1) begin
                            if (hit1 && !hit0) begin
                                tag_out = tags[1][index];
                                data_out = data_mem[1][index][word_index];
                                valid = valid_bits[1][index];
                                dirty = dirty_bits[1][index];
                            end else begin
                                tag_out = tags[0][index];
                                data_out = data_mem[0][index][word_index];
                                valid = valid_bits[0][index];
                                dirty = dirty_bits[0][index];
                            end
                            hit = 1'b1;
                        end else begin
                            if (selected_way) begin
                                tag_out = tags[1][index];
                                data_out = data_mem[1][index][word_index];
                                valid = valid_bits[1][index];
                                dirty = dirty_bits[1][index];
                            end else begin
                                tag_out = tags[0][index];
                                data_out = data_mem[0][index][word_index];
                                valid = valid_bits[0][index];
                                dirty = dirty_bits[0][index];
                            end
                            hit = 1'b0;
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

                        hit = 1'b0;
                        dirty = 1'b0;
                        tag_out = tag_in;
                        data_out = data_in;
                        valid = 1'b0;
                    end else begin
                        if (selected_way) begin
                            tag_out = tags[1][index];
                            data_out = data_mem[1][index][word_index];
                            valid = valid_bits[1][index];
                            dirty = dirty_bits[1][index];
                        end else begin
                            tag_out = tags[0][index];
                            data_out = data_mem[0][index][word_index];
                            valid = valid_bits[0][index];
                            dirty = dirty_bits[0][index];
                        end
                        hit = valid_bits[0][index] || valid_bits[1][index];
                    end
                end
            end
        end else begin
            hit = 1'b0;
            dirty = 1'b0;
            tag_out = {TAG_WIDTH{1'b0}};
            data_out = {DATA_WIDTH{1'b0}};
            valid = 1'b0;
            error = 1'b0;
        end
    end

endmodule
